import Foundation

/// One byte-source for every playback engine. AVPlayer consumes it through the local
/// Range server/resource loader; libmpv consumes it through mpv_stream_cb.
///
/// Invariants:
/// - Exactly two upstream slots are used for normal 115/CDN traffic.
/// - Slot 0 may be repurposed for a real playback hole; slot 1 is never cancelled only
///   because playback asks for a new range.
/// - Sequential prefetch is anchored by real byte demand, never by time/file-size math.
/// - Internal demux metadata probes are served urgently but do not move playbackAnchor.
actor UnifiedMediaTransportSession: TransportDataSession {
    private enum ClaimRole: String {
        case sequential
        case urgentPlayback
        case metadata
    }

    private struct SlotClaim {
        let range: Range<Int64>
        let role: ClaimRole
    }

    private struct SpeedSample {
        let date: Date
        let bytes: Int64
    }

    private var source: ResolvedPlaybackSource
    private let configuration: MediaTransportConfiguration
    private let resolver = RedirectResolver()
    private let client = RangeHTTPClient(maximumConnections: 2)
    private let blockBytes: Int64
    private let urgentBlockBytes: Int64 = 2 * 1_048_576
    private let lookaheadSegments = 4
    private let createdAt = Date()

    private var resource: TransportResolvedResource?
    private var resolveTask: Task<TransportResolvedResource, Error>?
    private var store: DownloadFirstSparseStore?
    private var rangeMap = PlaybackRangeMap()
    private var playbackAnchor: Int64 = 0
    private var pendingUserSeekUntil = Date.distantPast
    private var pendingUrgentRange: Range<Int64>?
    private var pendingUrgentIsMetadata = false
    private var stopped = false

    private var slotTasks: [Int: Task<Void, Never>] = [:]
    private var slotClaims: [Int: SlotClaim] = [:]
    private var slotGenerations: [Int: Int] = [0: 0, 1: 0]
    private var secondaryEnabled = false
    private var secondaryFailureCount = 0
    private var secondaryCooldownUntil = Date.distantPast
    private var successfulPrimaryBlocks = 0

    private var metricsValue = TransportMetricsSnapshot()
    private var speedSamples: [SpeedSample] = []
    private var lastMetricsLogAt = Date.distantPast

    init(source: ResolvedPlaybackSource, configuration: MediaTransportConfiguration) {
        self.source = source
        self.configuration = configuration
        self.blockBytes = min(max(configuration.upstreamBlockSizeBytes, 4 * 1_048_576), 16 * 1_048_576)
    }

    func resolve() async throws -> TransportResolvedResource {
        if let resource { return resource }
        if let resolveTask { return try await resolveTask.value }
        guard !stopped else { throw MediaTransportError.cancelled }

        let snapshot = source
        let resolver = resolver
        let task = Task<TransportResolvedResource, Error> { try await resolver.resolve(source: snapshot) }
        resolveTask = task
        do {
            let resolved = try await task.value
            resolveTask = nil
            guard resolved.supportsByteRanges else { throw MediaTransportError.rangeUnsupported(statusCode: 200) }
            resource = resolved
            if store == nil {
                let cache = try DownloadFirstSparseStore(
                    cacheKey: "unified-v1-\(source.itemId)-\(source.mediaSource.id)",
                    contentLength: resolved.contentLength,
                    etag: resolved.etag,
                    lastModified: resolved.lastModified,
                    keepFiles: configuration.keepLastCache
                )
                store = cache
                for range in cache.cachedRanges { rangeMap.insertPlayback(range) }
            }
            DiagnosticsLogger.shared.log(
                "UnifiedTransport",
                "ready item=\(source.itemId) bytes=\(resolved.contentLength) slots=2 block=\(blockBytes) preloadWindow=\(preloadWindowBytes()) anchor=\(playbackAnchor) \(NetworkPathMonitor.shared.diagnosticSummary)"
            )
            scheduleSlots(reason: "resolved")
            return resolved
        } catch {
            resolveTask = nil
            throw error
        }
    }

    func noteDemand(range: Range<Int64>) async {
        guard !stopped, !range.isEmpty, let resolved = try? await resolve(), let store else { return }
        let normalized = clamp(range: range, contentLength: resolved.contentLength)
        guard !normalized.isEmpty else { return }
        if store.contains(normalized) { return }
        acceptRealDemand(normalized, resource: resolved, reason: "range-demand")
    }

    func prioritizeOffset(_ offset: Int64) async {
        guard !stopped, let resolved = try? await resolve() else { return }
        let clamped = min(max(0, offset), max(0, resolved.contentLength - 1))
        let demand = clamped..<min(resolved.contentLength, clamped + urgentBlockBytes)
        acceptRealDemand(demand, resource: resolved, reason: "byte-offset")
    }

    func read(offset: Int64, length: Int) async throws -> Data {
        guard !stopped else { throw MediaTransportError.cancelled }
        guard length > 0 else { return Data() }
        let resolved = try await resolve()
        guard offset >= 0, offset < resolved.contentLength, let store else { return Data() }

        let requested = min(length, Int(resolved.contentLength - offset))
        let available = store.availableLength(from: offset, maximumLength: Int64(requested))
        metricsValue.bytesServed += Int64(requested)
        if available >= Int64(requested) { metricsValue.cacheHitBytes += Int64(requested) }

        if available == 0 {
            let demandEnd = min(resolved.contentLength, offset + max(Int64(requested), urgentBlockBytes))
            acceptRealDemand(offset..<demandEnd, resource: resolved, reason: "blocked-read")
        }

        do {
            let data = try await store.readWhenAvailable(offset: offset, maximumLength: requested, timeout: 20)
            refreshMetrics(resource: resolved)
            return data
        } catch let error as DownloadFirstSparseStore.StoreError {
            guard case .timeout = error else { throw error }
            let demandEnd = min(resolved.contentLength, offset + max(Int64(requested), urgentBlockBytes))
            DiagnosticsLogger.shared.log("UnifiedDemand", "timeout offset=\(offset) length=\(requested); force slot0")
            installUrgent(range: offset..<demandEnd, metadata: isMetadataProbe(offset..<demandEnd, resource: resolved), reason: "read-timeout")
            scheduleSlots(reason: "read-timeout")
            return try await store.readWhenAvailable(offset: offset, maximumLength: requested, timeout: 25)
        }
    }

    func prioritizeSeek(position: Double, duration: Double) async {
        guard !stopped else { return }
        pendingUserSeekUntil = Date().addingTimeInterval(4)
        DiagnosticsLogger.shared.log(
            "UnifiedAnchor",
            "user-seek position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) byteGuess=disabled awaitingRealDemand=true anchor=\(playbackAnchor)"
        )
    }

    func recoverStall(position: Double, duration: Double) async {
        guard !stopped else { return }
        DiagnosticsLogger.shared.log(
            "UnifiedDemand",
            "stall position=\(String(format: "%.3f", position)) anchor=\(playbackAnchor) action=keep-slot1-and-prioritize-real-range"
        )
        scheduleSlots(reason: "stall")
    }

    func metrics() async -> TransportMetricsSnapshot {
        if let resolved = try? await resolve() { refreshMetrics(resource: resolved) }
        return metricsValue
    }

    func quiesceConsumers() async {
        // The shared byte store is intentionally kept alive across engine switches.
        // Give in-flight local reads a tiny handoff window without cancelling upstream slots.
        try? await Task.sleep(nanoseconds: 80_000_000)
    }

    func stop() async {
        guard !stopped else { return }
        stopped = true
        resolveTask?.cancel()
        resolveTask = nil
        for task in slotTasks.values { task.cancel() }
        slotTasks.removeAll()
        slotClaims.removeAll()
        rangeMap.clearDownloading(lane: "slot0")
        rangeMap.clearDownloading(lane: "slot1")
        store?.close(removeFiles: !configuration.keepLastCache)
        store = nil
        DiagnosticsLogger.shared.log("UnifiedTransport", "stopped item=\(source.itemId)")
    }

    private func acceptRealDemand(_ range: Range<Int64>, resource: TransportResolvedResource, reason: String) {
        guard !range.isEmpty, let store else { return }
        let metadata = isMetadataProbe(range, resource: resource)
        let pendingUserSeek = Date() <= pendingUserSeekUntil

        if pendingUserSeek, !metadata {
            pendingUserSeekUntil = .distantPast
            let previous = playbackAnchor
            playbackAnchor = range.lowerBound
            DiagnosticsLogger.shared.log(
                "UnifiedAnchor",
                "real-demand reanchor previous=\(previous) new=\(playbackAnchor) request=\(range.lowerBound)-\(range.upperBound) reason=\(reason)"
            )
            if let active = slotClaims[0], !active.range.contains(range.lowerBound) {
                cancelSlot(0, reason: "real-seek-demand")
            }
        }

        if store.availableLength(from: range.lowerBound, maximumLength: min(Int64(range.count), urgentBlockBytes)) > 0 { return }
        // If slot 0 already owns this demand, let it finish. If only slot 1 owns a much
        // larger background block, duplicate at most urgentBlockBytes on slot 0 instead
        // of forcing the player to wait for the entire background block.
        if let slot0 = slotClaims[0], slot0.range.contains(range.lowerBound) { return }
        installUrgent(range: range, metadata: metadata, reason: reason)
        scheduleSlots(reason: reason)
    }

    private func installUrgent(range: Range<Int64>, metadata: Bool, reason: String) {
        guard let resource else { return }
        let lower = max(0, range.lowerBound)
        let upper = min(resource.contentLength, max(lower + 1, min(range.upperBound, lower + urgentBlockBytes)))
        let candidate = lower..<upper
        if let existing = pendingUrgentRange, existing.contains(lower), existing.upperBound >= upper { return }
        pendingUrgentRange = candidate
        pendingUrgentIsMetadata = metadata
        DiagnosticsLogger.shared.log(
            "UnifiedDemand",
            "urgent range=\(candidate.lowerBound)-\(candidate.upperBound) metadata=\(metadata) reason=\(reason) slot0Only=true"
        )
        if let active = slotClaims[0], !active.range.contains(lower), active.role == .sequential {
            cancelSlot(0, reason: "urgent-demand")
        }
    }

    private func scheduleSlots(reason: String) {
        guard !stopped, let resource, let store else { return }
        if slotTasks[0] == nil {
            if let urgent = pendingUrgentRange, !store.contains(urgent) {
                let role: ClaimRole = pendingUrgentIsMetadata ? .metadata : .urgentPlayback
                pendingUrgentRange = nil
                pendingUrgentIsMetadata = false
                startSlot(0, claim: SlotClaim(range: urgent, role: role), reason: reason)
            } else {
                pendingUrgentRange = nil
                pendingUrgentIsMetadata = false
                if let range = nextSequentialClaim(resource: resource) {
                    startSlot(0, claim: SlotClaim(range: range, role: .sequential), reason: reason)
                }
            }
        }

        guard secondaryEnabled, Date() >= secondaryCooldownUntil, slotTasks[1] == nil else {
            refreshMetrics(resource: resource)
            return
        }
        if let range = nextSequentialClaim(resource: resource) {
            startSlot(1, claim: SlotClaim(range: range, role: .sequential), reason: "secondary-\(reason)")
        }
        refreshMetrics(resource: resource)
    }

    private func nextSequentialClaim(resource: TransportResolvedResource) -> Range<Int64>? {
        let window = preloadWindowBytes()
        guard window > 0 else { return nil }
        if configuration.usesDiskCache, configuration.diskLimitBytes > 0, store?.uniqueBytes ?? 0 >= configuration.diskLimitBytes { return nil }
        let upper = min(resource.contentLength, safeAdd(playbackAnchor, window))
        guard upper > playbackAnchor else { return nil }
        return rangeMap.nextClaim(
            from: playbackAnchor,
            resourceLength: upper,
            segmentBytes: blockBytes,
            workerLimit: 2,
            lookaheadSegments: lookaheadSegments
        )
    }

    private func startSlot(_ slot: Int, claim: SlotClaim, reason: String) {
        guard slotTasks[slot] == nil, !claim.range.isEmpty else { return }
        let generation = (slotGenerations[slot] ?? 0) + 1
        slotGenerations[slot] = generation
        slotClaims[slot] = claim
        rangeMap.setDownloading(claim.range, lane: "slot\(slot)")
        metricsValue.activeRequestCount = slotTasks.count + 1
        metricsValue.networkRequestCount += 1
        DiagnosticsLogger.shared.log(
            "UnifiedSlot",
            "slot=\(slot) start role=\(claim.role.rawValue) range=\(claim.range.lowerBound)-\(claim.range.upperBound) reason=\(reason) anchor=\(playbackAnchor)"
        )

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performFetch(slot: slot, generation: generation, claim: claim)
        }
        slotTasks[slot] = task
    }

    private func performFetch(slot: Int, generation: Int, claim: SlotClaim) async {
        guard !stopped, var resolved = resource, let store else {
            finishSlot(slot: slot, generation: generation, claim: claim, data: nil, error: MediaTransportError.cancelled)
            return
        }
        do {
            let started = Date()
            let data: Data
            do {
                data = try await client.fetch(resource: resolved, range: claim.range, lane: .preload(worker: slot))
            } catch MediaTransportError.expiredURL {
                DiagnosticsLogger.shared.log("UnifiedTransport", "slot=\(slot) refreshing expired 115 URL")
                resource = nil
                resolved = try await resolve()
                data = try await client.fetch(resource: resolved, range: claim.range, lane: .preload(worker: slot))
            }
            try Task.checkCancellation()
            try store.write(data, at: claim.range.lowerBound)
            let elapsed = max(Date().timeIntervalSince(started), 0.001)
            let bps = Double(data.count) / elapsed
            DiagnosticsLogger.shared.log(
                "UnifiedSlot",
                "slot=\(slot) finish role=\(claim.role.rawValue) range=\(claim.range.lowerBound)-\(claim.range.upperBound) bytes=\(data.count) speedBps=\(Int(bps))"
            )
            finishSlot(slot: slot, generation: generation, claim: claim, data: data, error: nil)
        } catch is CancellationError {
            finishSlot(slot: slot, generation: generation, claim: claim, data: nil, error: MediaTransportError.cancelled)
        } catch {
            finishSlot(slot: slot, generation: generation, claim: claim, data: nil, error: error)
        }
    }

    private func finishSlot(slot: Int, generation: Int, claim: SlotClaim, data: Data?, error: Error?) {
        guard slotGenerations[slot] == generation else { return }
        slotTasks[slot] = nil
        slotClaims[slot] = nil
        rangeMap.clearDownloading(lane: "slot\(slot)")

        if let data, !data.isEmpty {
            let written = claim.range.lowerBound..<min(claim.range.upperBound, claim.range.lowerBound + Int64(data.count))
            if claim.role == .metadata { rangeMap.insertMetadata(written) }
            else { rangeMap.insertPlayback(written) }
            metricsValue.bytesDownloaded += Int64(data.count)
            speedSamples.append(SpeedSample(date: Date(), bytes: Int64(data.count)))
            pruneSpeedSamples()

            if slot == 0, claim.role == .sequential {
                successfulPrimaryBlocks += 1
                if !secondaryEnabled, successfulPrimaryBlocks >= 1 {
                    secondaryEnabled = true
                    DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled after primary stable block")
                }
            }
            if slot == 1 { secondaryFailureCount = 0 }
        }

        if let error, !isCancellation(error) {
            metricsValue.rangeFailureCount += 1
            DiagnosticsLogger.shared.log(
                "UnifiedSlot",
                "slot=\(slot) failed role=\(claim.role.rawValue) range=\(claim.range.lowerBound)-\(claim.range.upperBound) error=\(error.localizedDescription)"
            )
            if slot == 1 {
                secondaryFailureCount += 1
                let delay = min(30.0, 4.0 * Double(max(1, secondaryFailureCount)))
                secondaryCooldownUntil = Date().addingTimeInterval(delay)
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    await self?.resumeAfterSecondaryCooldown()
                }
            }
        }

        if let resource { refreshMetrics(resource: resource) }
        scheduleSlots(reason: "slot-finished")
    }

    private func resumeAfterSecondaryCooldown() {
        guard !stopped else { return }
        scheduleSlots(reason: "secondary-cooldown-ended")
    }

    private func cancelSlot(_ slot: Int, reason: String) {
        guard let task = slotTasks[slot] else { return }
        DiagnosticsLogger.shared.log("UnifiedSlot", "slot=\(slot) cancel reason=\(reason) claim=\(slotClaims[slot]?.range.description ?? "none")")
        task.cancel()
    }

    private func refreshMetrics(resource: TransportResolvedResource) {
        guard let store else { return }
        let map = rangeMap.snapshot(anchor: playbackAnchor, resourceLength: resource.contentLength)
        metricsValue.cacheBytes = store.uniqueBytes
        metricsValue.diskCacheBytes = store.uniqueBytes
        metricsValue.contiguousCacheBytes = map.frontierByte > playbackAnchor ? map.frontierByte - playbackAnchor : 0
        metricsValue.metadataCacheBytes = map.metadataBytes
        metricsValue.sparsePlaybackCacheBytes = map.playbackBytes
        metricsValue.cacheHoleCount = map.holeCount
        metricsValue.schedulerAnchorByte = playbackAnchor
        metricsValue.schedulerFrontierByte = map.frontierByte
        metricsValue.activeRequestCount = slotTasks.count
        metricsValue.elapsedSeconds = Date().timeIntervalSince(createdAt)
        pruneSpeedSamples()
        let speedWindow = max(1, Date().timeIntervalSince(speedSamples.first?.date ?? Date()))
        metricsValue.currentDownloadBytesPerSecond = speedSamples.isEmpty ? 0 : Double(speedSamples.reduce(Int64(0)) { $0 + $1.bytes }) / speedWindow

        if Date().timeIntervalSince(lastMetricsLogAt) >= 2 {
            lastMetricsLogAt = Date()
            let slot0 = slotClaims[0]?.range.description ?? "idle"
            let slot1 = slotClaims[1]?.range.description ?? "idle"
            DiagnosticsLogger.shared.log(
                "UnifiedMap",
                "anchor=\(map.anchorByte) frontier=\(map.frontierByte) contiguous=\(metricsValue.contiguousCacheBytes) cached=\(metricsValue.cacheBytes) metadata=\(map.metadataBytes) holes=\(map.holeCount) slot0=\(slot0) slot1=\(slot1) networkBps=\(Int(metricsValue.currentDownloadBytesPerSecond))"
            )
        }
    }

    private func pruneSpeedSamples() {
        let cutoff = Date().addingTimeInterval(-6)
        speedSamples.removeAll { $0.date < cutoff }
    }


    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let transportError = error as? MediaTransportError, case .cancelled = transportError { return true }
        return false
    }

    private func preloadWindowBytes() -> Int64 {
        if NetworkPathMonitor.shared.isCellular {
            // Cellular remains explicitly opt-in for background prefetch.
            return configuration.ktvPreloadOnCellular ? max(0, configuration.cellularPreloadBytes) : 0
        }
        // On Wi-Fi the session disk budget is the real prefetch ceiling. The old 128 MiB
        // setting was only a forward-window hint and made a fast 115 connection stop by
        // design after a few seconds. Keep downloading while there is session-cache budget.
        if configuration.ktvContinuousPreloadEnabled, configuration.usesDiskCache, configuration.diskLimitBytes > 0 {
            return max(configuration.wifiPreloadBytes, configuration.diskLimitBytes)
        }
        return max(0, configuration.wifiPreloadBytes)
    }

    private func isMetadataProbe(_ range: Range<Int64>, resource: TransportResolvedResource) -> Bool {
        guard !range.isEmpty else { return false }
        let nearTail = resource.contentLength > 64 * 1_048_576 && range.lowerBound >= resource.contentLength - 64 * 1_048_576
        let tinyProbe = range.count <= 64 * 1024 && range.lowerBound > max(8 * 1_048_576, playbackAnchor + 2 * blockBytes)
        return nearTail || tinyProbe
    }

    private func clamp(range: Range<Int64>, contentLength: Int64) -> Range<Int64> {
        let lower = min(max(0, range.lowerBound), contentLength)
        let upper = min(max(lower, range.upperBound), contentLength)
        return lower..<upper
    }

    private func alignDown(_ value: Int64, alignment: Int64) -> Int64 {
        guard alignment > 0 else { return value }
        return max(0, (value / alignment) * alignment)
    }

    private func safeAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        if rhs > 0, lhs > Int64.max - rhs { return Int64.max }
        return lhs + rhs
    }
}
