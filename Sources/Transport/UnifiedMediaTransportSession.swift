import Foundation

/// One byte-source for every playback engine. AVPlayer consumes it through the local
/// Range server/resource loader; libmpv consumes it through mpv_stream_cb.
///
/// Invariants:
/// - Exactly two upstream slots are used for normal 115/CDN traffic.
/// - Warm sequential prefetch should survive ordinary seeks; foreground byte demand borrows the
///   other slot first so cancelling a seek does not repeatedly reset the warmed CDN connection.
/// - Sequential prefetch is anchored by real byte demand, never by time/file-size math.
/// - Internal demux metadata probes are served urgently but do not move playbackAnchor.
actor UnifiedMediaTransportSession: TransportDataSession {
    private enum ClaimRole: String {
        case sequential
        case urgentPlayback
        case metadata
        case startupMetadata
    }

    private struct SlotClaim {
        let range: Range<Int64>
        let role: ClaimRole
    }

    private struct SpeedSample {
        let date: Date
        let bytes: Int64
    }

    private struct LaneHealthState {
        var averageBps: Double = 0
        var samples = 0
        var slowStreak = 0
        var lastSampleAt = Date.distantPast
        var resetCooldownUntil = Date.distantPast
    }

    private struct LiveLaneState {
        var generation = 0
        var startedAt = Date.distantPast
        var lastChunkAt = Date.distantPast
        var sampleWindowStartedAt = Date.distantPast
        var sampleWindowStartedBytes: Int64 = 0
        var lastSampleAt = Date.distantPast
        var receivedBytes: Int64 = 0
        var recentBps: Double = 0
        var slowStreak = 0
        var resetCooldownUntil = Date.distantPast
    }

    private var source: ResolvedPlaybackSource
    private let configuration: MediaTransportConfiguration
    private let resolver = RedirectResolver()
    private let client = RangeHTTPClient(maximumConnections: 2)
    private let blockBytes: Int64
    private let urgentBlockBytes: Int64 = 16 * 1_048_576
    private let progressiveUrgentGapBytes: Int64 = 2 * 1_048_576
    private let metadataUrgentBlockBytes: Int64 = 16 * 1_048_576
    private let startupMetadataSegmentBytes: Int64 = 1 * 1_048_576
    private let secondaryMetadataMaxBytes: Int64 = 2 * 1_048_576
    private let initialSequentialBlockBytes: Int64 = 4 * 1_048_576
    private let largeFileInitialSequentialBlockBytes: Int64 = 1 * 1_048_576
    private let startupMetadataSlowFirstChunkSeconds: TimeInterval = 1.5
    private let startupMetadataSlowFirstChunkBps: Double = 1 * 1_048_576
    private let laneHealthMinSampleBytes: Int64 = 8 * 1_048_576
    private let laneHealthPeerFloorBps: Double = 4 * 1_048_576
    private let laneHealthRelativeFloor: Double = 0.50
    private let laneHealthPeerFreshSeconds: TimeInterval = 20
    private let laneHealthResetCooldownSeconds: TimeInterval = 25
    private let liveLanePeerFloorBps: Double = 4 * 1_048_576
    private let liveLaneAbsoluteFloorBps: Double = 1.25 * 1_048_576
    private let liveLaneRelativeFloor: Double = 0.45
    private let liveLaneFirstBytePeerTimeoutSeconds: TimeInterval = 1.5
    private let liveLaneFirstByteHardTimeoutSeconds: TimeInterval = 3.0
    private let liveLaneSampleWindowSeconds: TimeInterval = 1.0
    private let liveLaneSampleMinimumBytes: Int64 = 1 * 1_048_576
    private let liveLaneResetCooldownSeconds: TimeInterval = 8
    private let startupTailDemandGraceSeconds: TimeInterval = 0.25
    private let lookaheadSegments = 4
    private let createdAt = Date()

    private var resource: TransportResolvedResource?
    private var resolveTask: Task<TransportResolvedResource, Error>?
    private var store: DownloadFirstSparseStore?
    private var rangeMap = PlaybackRangeMap()
    private var playbackAnchor: Int64 = 0
    private var pendingUserSeekUntil = Date.distantPast
    private var pendingPlaybackUrgentRange: Range<Int64>?
    private var pendingMetadataRange: Range<Int64>?
    private var lastConcretePlaybackDemand: Range<Int64>?
    private var startupMetadataPlanRange: Range<Int64>?
    private var startupMetadataQueue: [Range<Int64>] = []
    private var startupMetadataPlanCompleted = false
    private var startupTailDemandGraceUntil = Date.distantPast
    private var startupTailGraceResumeScheduled = false
    private var preferredBulkSlot = 0
    private var stopped = false

    private var slotTasks: [Int: Task<Void, Never>] = [:]
    private var slotClaims: [Int: SlotClaim] = [:]
    private var slotGenerations: [Int: Int] = [0: 0, 1: 0]
    private var secondaryEnabled = false
    private var secondaryFailureCount = 0
    private var secondaryCooldownUntil = Date.distantPast
    private var successfulPrimaryBlocks = 0
    private var laneHealth: [Int: LaneHealthState] = [0: LaneHealthState(), 1: LaneHealthState()]
    private var liveLaneState: [Int: LiveLaneState] = [0: LiveLaneState(), 1: LiveLaneState()]
    private var liveLaneRotationRequested: Set<Int> = []
    private var liveLaneResetPending: Set<Int> = []
    private var startupMetadataReceivedBytes: [Int: Int64] = [0: 0, 1: 0]
    private var startupMetadataStartedAt: [Int: Date] = [0: .distantPast, 1: .distantPast]
    private var startupMetadataLastProgressAt: [Int: Date] = [0: .distantPast, 1: .distantPast]
    private var startupMetadataRetryRequested: Set<Int> = []

    private var metricsValue = TransportMetricsSnapshot()
    private var speedSamples: [SpeedSample] = []
    private var lastMetricsLogAt = Date.distantPast

    init(source: ResolvedPlaybackSource, configuration: MediaTransportConfiguration) {
        self.source = source
        self.configuration = configuration
        self.blockBytes = min(max(configuration.upstreamBlockSizeBytes, 4 * 1_048_576), 64 * 1_048_576)
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
        // Range requests are scheduler hints only. During a pending seek, the actual read() callback
        // is authoritative because AVFoundation may still issue cached/stale requests from the old timeline.
        if store.contains(normalized) {
            acceptRealDemand(normalized, resource: resolved, reason: "range-demand-cached")
            return
        }
        acceptRealDemand(normalized, resource: resolved, reason: "range-demand")
    }

    func prioritizeOffset(_ offset: Int64) async {
        guard !stopped, let resolved = try? await resolve() else { return }
        let clamped = min(max(0, offset), max(0, resolved.contentLength - 1))
        let probe = clamped..<min(resolved.contentLength, clamped + urgentBlockBytes)
        let preferredLength = isMetadataProbe(probe, resource: resolved) ? metadataUrgentBlockBytes : urgentBlockBytes
        let demand = clamped..<min(resolved.contentLength, clamped + preferredLength)
        acceptRealDemand(demand, resource: resolved, reason: "byte-offset")
    }

    func read(offset: Int64, length: Int) async throws -> Data {
        guard !stopped else { throw MediaTransportError.cancelled }
        guard length > 0 else { return Data() }
        let resolved = try await resolve()
        guard offset >= 0, offset < resolved.contentLength, let store else { return Data() }

        let requested = min(length, Int(resolved.contentLength - offset))
        let concreteRange = offset..<min(resolved.contentLength, offset + Int64(requested))
        acceptRealDemand(concreteRange, resource: resolved, reason: "concrete-read")
        let available = store.availableLength(from: offset, maximumLength: Int64(requested))
        metricsValue.bytesServed += Int64(requested)
        if available >= Int64(requested) { metricsValue.cacheHitBytes += Int64(requested) }

        if available == 0 {
            let probe = offset..<min(resolved.contentLength, offset + max(Int64(requested), urgentBlockBytes))
            let preferredLength = isMetadataProbe(probe, resource: resolved) ? metadataUrgentBlockBytes : urgentBlockBytes
            let demandEnd = min(resolved.contentLength, offset + max(Int64(requested), preferredLength))
            acceptRealDemand(offset..<demandEnd, resource: resolved, reason: "blocked-read")
        }

        do {
            let data = try await store.readWhenAvailable(offset: offset, maximumLength: requested, timeout: 20)
            refreshMetrics(resource: resolved)
            return data
        } catch let error as DownloadFirstSparseStore.StoreError {
            guard case .timeout = error else { throw error }
            let probe = offset..<min(resolved.contentLength, offset + max(Int64(requested), urgentBlockBytes))
            let metadata = isMetadataProbe(probe, resource: resolved)
            let preferredLength = metadata ? metadataUrgentBlockBytes : urgentBlockBytes
            let demandEnd = min(resolved.contentLength, offset + max(Int64(requested), preferredLength))
            DiagnosticsLogger.shared.log("UnifiedDemand", "timeout offset=\(offset) length=\(requested); force slot0")
            installUrgent(range: offset..<demandEnd, metadata: metadata, reason: "read-timeout")
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
        if let demand = lastConcretePlaybackDemand, let resource {
            let previous = playbackAnchor
            playbackAnchor = demand.lowerBound
            let urgent = demand.lowerBound..<min(resource.contentLength, safeAdd(demand.lowerBound, urgentBlockBytes))
            installUrgent(range: urgent, metadata: false, reason: "stall-last-concrete-demand")
            for slot in [0, 1] {
                if let active = slotClaims[slot], active.role == .urgentPlayback, !active.range.contains(demand.lowerBound) { cancelSlot(slot, reason: "replace-stale-urgent") }
            }
            DiagnosticsLogger.shared.log(
                "UnifiedDemand",
                "stall position=\(String(format: "%.3f", position)) previousAnchor=\(previous) anchor=\(playbackAnchor) concrete=\(demand.lowerBound)-\(demand.upperBound) action=prioritize-current-demand"
            )
        } else {
            DiagnosticsLogger.shared.log(
                "UnifiedDemand",
                "stall position=\(String(format: "%.3f", position)) anchor=\(playbackAnchor) action=await-concrete-demand"
            )
        }
        scheduleSlots(reason: "stall")
    }

    func metrics() async -> TransportMetricsSnapshot {
        if let resolved = try? await resolve() { refreshMetrics(resource: resolved) }
        return metricsValue
    }

    func cachedByteRanges() -> [Range<Int64>] {
        let resourceLength = resource?.contentLength ?? 0
        return rangeMap.snapshot(anchor: 0, resourceLength: resourceLength).playbackRanges
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
        client.invalidate()
        DiagnosticsLogger.shared.log("UnifiedTransport", "stopped item=\(source.itemId)")
    }

    private func acceptRealDemand(_ range: Range<Int64>, resource: TransportResolvedResource, reason: String) {
        guard !range.isEmpty, let store else { return }
        let concreteReason = reason == "concrete-read" || reason == "blocked-read" || reason == "byte-offset"
        // Distant concrete reads are normally real playback dependencies (poorly interleaved A/V),
        // but a large MP4's first near-EOF seek is container metadata. Treating that moov/sample-table
        // read as playback made 152901 cache 100+ MiB from the head while file-loaded waited on a slow
        // ~10 MiB tail request. Limit this override to the startup window so a later user seek near EOF
        // remains ordinary playback demand.
        let startupTailMetadata = isStartupTailMetadata(range, resource: resource)
        let metadata = startupTailMetadata || (!concreteReason && isMetadataProbe(range, resource: resource))
        let pendingUserSeek = Date() <= pendingUserSeekUntil
        let concretePlaybackDemand = concreteReason && !metadata
        let authoritativeSeekDemand = reason == "blocked-read" || reason == "byte-offset"
        var reanchored = false
        if startupTailMetadata { DiagnosticsLogger.shared.log("UnifiedStartup", "critical-tail-metadata range=\(range.lowerBound)-\(range.upperBound) reason=\(reason) action=actual-demand") }

        // AVFoundation may emit stale/cached range requests from the pre-seek timeline while a seek is
        // still settling. Only the byte offset actually consumed by read(), or MPV's explicit byte seek,
        // may consume the pending seek token. This mirrors a logical-position reader: requested ranges
        // are hints, actual reads are authoritative.
        if pendingUserSeek, !metadata, !concretePlaybackDemand {
            DiagnosticsLogger.shared.log(
                "UnifiedAnchor",
                "seek-candidate deferred request=\(range.lowerBound)-\(range.upperBound) reason=\(reason) awaitingConcreteRead=true anchor=\(playbackAnchor)"
            )
            return
        }
        if pendingUserSeek, concretePlaybackDemand, !authoritativeSeekDemand {
            DiagnosticsLogger.shared.log(
                "UnifiedAnchor",
                "seek concrete-read deferred request=\(range.lowerBound)-\(range.upperBound) reason=\(reason) awaitingBlockedRead=true anchor=\(playbackAnchor)"
            )
            return
        }
        if concretePlaybackDemand { lastConcretePlaybackDemand = range }

        // AVPlayer range announcements are speculative. They must never preempt a healthy bulk
        // connection merely because the demuxer considered a region. Concrete read()/byte-offset
        // demand remains authoritative; metadata hints are retained because tail indexes are startup-critical.
        if !concreteReason, !metadata {
            DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "hint-only request=\(range.lowerBound)-\(range.upperBound) reason=\(reason) action=keep-bulk")
            scheduleSlots(reason: "hint-only")
            return
        }

        if pendingUserSeek, !metadata, concretePlaybackDemand, authoritativeSeekDemand {
            pendingUserSeekUntil = .distantPast
            let previous = playbackAnchor
            playbackAnchor = range.lowerBound
            reanchored = true
            DiagnosticsLogger.shared.log(
                "UnifiedAnchor",
                "real-demand reanchor previous=\(previous) new=\(playbackAnchor) request=\(range.lowerBound)-\(range.upperBound) reason=\(reason) authority=cache-miss"
            )
            for slot in [0, 1] {
                guard let active = slotClaims[slot], !active.range.contains(range.lowerBound) else { continue }
                if active.role == .urgentPlayback { cancelSlot(slot, reason: "replace-stale-urgent") }
                if active.role == .sequential { cancelSlot(slot, reason: "seek-reanchor-sequential") }
            }
        } else if concretePlaybackDemand {
            let distance = range.lowerBound >= playbackAnchor ? range.lowerBound - playbackAnchor : playbackAnchor - range.lowerBound
            if distance > blockBytes * 4 {
                // Poorly interleaved MP4 files may legitimately alternate between distant audio/video
                // byte regions. Do not reinterpret that second read head as another timeline seek and
                // cancel the first head. The scheduler can use Slot 1 for the parallel urgent demand.
                DiagnosticsLogger.shared.log("UnifiedAnchor", "parallel-read-head primary=\(playbackAnchor) request=\(range.lowerBound)-\(range.upperBound) reason=\(reason) action=keep-primary-anchor")
            }
        }

        if store.availableLength(from: range.lowerBound, maximumLength: min(Int64(range.count), urgentBlockBytes)) > 0 {
            if reanchored { scheduleSlots(reason: "reanchor-cache-hit") }
            return
        }

        // Being inside an active foreground claim still does not prove that the requested byte has
        // arrived. A far seek can land deep inside an older 16 MiB urgent claim; waiting for that lane
        // to walk linearly to the new read head caused multi-second stalls while the second lane sat idle.
        if let activeEntry = slotClaims.first(where: { $0.value.role != .sequential && $0.value.range.contains(range.lowerBound) }) {
            let activeSlot = activeEntry.key
            let active = activeEntry.value
            if concretePlaybackDemand, active.role == .urgentPlayback {
                let ready = store.availableLength(from: active.range.lowerBound, maximumLength: Int64(active.range.count))
                let streamHead = min(active.range.upperBound, active.range.lowerBound + ready)
                let gap = max(0, range.lowerBound - streamHead)
                if gap > progressiveUrgentGapBytes {
                    DiagnosticsLogger.shared.log("UnifiedDemand", "foreground active-gap slot=\(activeSlot) request=\(range.lowerBound)-\(range.upperBound) claim=\(active.range.lowerBound)-\(active.range.upperBound) head=\(streamHead) gap=\(gap) action=parallel-urgent")
                    installUrgent(range: range, metadata: false, reason: "foreground-active-gap-\(reason)")
                    scheduleSlots(reason: "foreground-active-gap-\(reason)")
                    return
                }
            }
            DiagnosticsLogger.shared.log("UnifiedDemand", "reuse active foreground request=\(range.lowerBound)-\(range.upperBound) claim=\(active.range.lowerBound)-\(active.range.upperBound) role=\(active.role.rawValue) reason=\(reason)")
            return
        }

        // Being inside a 32 MiB sequential claim does not mean the requested byte has arrived. This
        // was the 63360/194s regression: the read was ~10 MiB ahead of Slot 0's actual download head.
        // Wait only when the progressive stream is genuinely close; otherwise preserve the warmed
        // sequential request and borrow Slot 1 for an exact urgent Range.
        if concretePlaybackDemand, let activeSequential = slotClaims.first(where: { $0.value.role == .sequential && $0.value.range.contains(range.lowerBound) }) {
            let slot = activeSequential.key
            let claim = activeSequential.value
            let ready = store.availableLength(from: claim.range.lowerBound, maximumLength: Int64(claim.range.count))
            let streamHead = min(claim.range.upperBound, claim.range.lowerBound + ready)
            let gap = max(0, range.lowerBound - streamHead)
            if gap <= progressiveUrgentGapBytes {
                DiagnosticsLogger.shared.log("UnifiedDemand", "reuse active sequential stream slot=\(slot) request=\(range.lowerBound)-\(range.upperBound) claim=\(claim.range.lowerBound)-\(claim.range.upperBound) head=\(streamHead) gap=\(gap) reason=\(reason) action=wait-progressive-chunk")
                return
            }
            DiagnosticsLogger.shared.log("UnifiedDemand", "foreground gap slot=\(slot) request=\(range.lowerBound)-\(range.upperBound) claim=\(claim.range.lowerBound)-\(claim.range.upperBound) head=\(streamHead) gap=\(gap) action=parallel-urgent")
            installUrgent(range: range, metadata: false, reason: "foreground-gap-\(reason)")
            scheduleSlots(reason: "foreground-gap-\(reason)")
            return
        }

        installUrgent(range: range, metadata: metadata, reason: reason)
        scheduleSlots(reason: reason)
    }

    private func installUrgent(range: Range<Int64>, metadata: Bool, reason: String) {
        guard let resource else { return }
        let lower = max(0, range.lowerBound)
        let startupCriticalMetadata = metadata && isStartupTailMetadata(range, resource: resource)
        if startupCriticalMetadata {
            installStartupMetadataPlan(range: lower..<resource.contentLength, reason: reason)
            return
        }

        let blockLimit = metadata ? metadataUrgentBlockBytes : urgentBlockBytes
        let requestedUpper = metadata ? max(range.upperBound, safeAdd(lower, blockLimit)) : min(range.upperBound, safeAdd(lower, blockLimit))
        let upper = min(resource.contentLength, max(lower + 1, requestedUpper))
        let candidate = lower..<upper
        if metadata {
            if let existing = pendingMetadataRange, existing.contains(lower), existing.upperBound >= upper { return }
            pendingMetadataRange = candidate
        } else {
            if let existing = pendingPlaybackUrgentRange, existing.contains(lower), existing.upperBound >= upper { return }
            pendingPlaybackUrgentRange = candidate
        }
        DiagnosticsLogger.shared.log("UnifiedDemand", "urgent range=\(candidate.lowerBound)-\(candidate.upperBound) metadata=\(metadata) reason=\(reason) protectedBulk=\(preferredBulkSlot)")

        if firstIdleForegroundSlot() != nil { return }
        let sequentialSlots = [0, 1].filter { slotClaims[$0]?.role == .sequential }
        if sequentialSlots.count == 2 {
            let serviceSlot = preferredBulkSlot == 0 ? 1 : 0
            DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "foreground borrow slot=\(serviceSlot) preserveBulk=\(preferredBulkSlot) range=\(candidate.lowerBound)-\(candidate.upperBound)")
            cancelSlot(serviceSlot, reason: metadata ? "metadata-borrow-service-lane" : "foreground-borrow-service-lane")
        } else if sequentialSlots.count == 1 {
            let onlySequential = sequentialSlots[0]
            DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "second foreground head borrows bulk slot=\(onlySequential) range=\(candidate.lowerBound)-\(candidate.upperBound)")
            cancelSlot(onlySequential, reason: "second-foreground-head")
        }
    }

    private func installStartupMetadataPlan(range: Range<Int64>, reason: String) {
        guard let resource, let store, !range.isEmpty else { return }
        let lower = min(startupMetadataPlanRange?.lowerBound ?? range.lowerBound, range.lowerBound)
        let plan = max(0, lower)..<resource.contentLength
        startupMetadataPlanRange = plan
        startupMetadataPlanCompleted = false
        startupTailDemandGraceUntil = .distantPast

        let activeRanges = slotClaims.values.filter { $0.role == .startupMetadata }.map(\.range)
        var chunks: [Range<Int64>] = []
        var cursor = plan.lowerBound
        while cursor < plan.upperBound {
            let chunk = cursor..<min(plan.upperBound, safeAdd(cursor, startupMetadataSegmentBytes))
            if !store.contains(chunk), !activeRanges.contains(where: { $0.lowerBound == chunk.lowerBound && $0.upperBound == chunk.upperBound }) { chunks.append(chunk) }
            cursor = chunk.upperBound
        }
        startupMetadataQueue = chunks
        for slot in [0, 1] where slotClaims[slot]?.role == .sequential { cancelSlot(slot, reason: "startup-metadata-preempt") }
        DiagnosticsLogger.shared.log("UnifiedStartup", "actual-tail plan range=\(plan.lowerBound)-\(plan.upperBound) bytes=\(plan.count) segment=\(startupMetadataSegmentBytes) queued=\(startupMetadataQueue.count) reason=\(reason)")
    }

    private func scheduleSlots(reason: String) {
        guard !stopped, let resource, let store else { return }

        if !startupMetadataQueue.isEmpty || slotClaims.values.contains(where: { $0.role == .startupMetadata }) {
            for slot in [0, 1] where slotTasks[slot] == nil && !liveLaneResetPending.contains(slot) {
                if slot == 1, Date() < secondaryCooldownUntil { continue }
                while !startupMetadataQueue.isEmpty {
                    let chunk = startupMetadataQueue.removeFirst()
                    if store.contains(chunk) { continue }
                    startSlot(slot, claim: SlotClaim(range: chunk, role: .startupMetadata), reason: "startup-metadata-\(reason)")
                    break
                }
            }
            refreshMetrics(resource: resource)
            return
        }

        if let urgent = pendingPlaybackUrgentRange, !store.contains(urgent), let slot = firstIdleForegroundSlot() {
            pendingPlaybackUrgentRange = nil
            startSlot(slot, claim: SlotClaim(range: urgent, role: .urgentPlayback), reason: "foreground-\(reason)")
        }

        if let metadata = pendingMetadataRange, !store.contains(metadata), let slot = firstIdleForegroundSlot() {
            pendingMetadataRange = nil
            startSlot(slot, claim: SlotClaim(range: metadata, role: .metadata), reason: "metadata-\(reason)")
        }

        if pendingPlaybackUrgentRange != nil || pendingMetadataRange != nil {
            refreshMetrics(resource: resource)
            return
        }

        if startupMetadataPlanRange == nil, Date() < startupTailDemandGraceUntil {
            refreshMetrics(resource: resource)
            return
        }

        if !secondaryEnabled {
            if slotTasks[0] == nil, !liveLaneResetPending.contains(0), let range = nextSequentialClaim(resource: resource) { startSlot(0, claim: SlotClaim(range: range, role: .sequential), reason: reason) }
            refreshMetrics(resource: resource)
            return
        }

        let order = preferredBulkSlot == 0 ? [0, 1] : [1, 0]
        for slot in order where slotTasks[slot] == nil {
            if liveLaneResetPending.contains(slot) { continue }
            if slot == 1, Date() < secondaryCooldownUntil { continue }
            if let range = nextSequentialClaim(resource: resource) { startSlot(slot, claim: SlotClaim(range: range, role: .sequential), reason: slot == preferredBulkSlot ? "bulk-\(reason)" : "service-preload-\(reason)") }
        }
        refreshMetrics(resource: resource)
    }

    private func firstIdleForegroundSlot() -> Int? {
        let serviceSlot = preferredBulkSlot == 0 ? 1 : 0
        let order = [serviceSlot, preferredBulkSlot]
        for slot in order {
            guard slotTasks[slot] == nil, !liveLaneResetPending.contains(slot) else { continue }
            if slot == 1, Date() < secondaryCooldownUntil { continue }
            return slot
        }
        return nil
    }

    private func nextSequentialClaim(resource: TransportResolvedResource) -> Range<Int64>? {
        let window = preloadWindowBytes()
        guard window > 0 else { return nil }
        if configuration.usesDiskCache, configuration.diskLimitBytes > 0, store?.uniqueBytes ?? 0 >= configuration.diskLimitBytes { return nil }
        let upper = min(resource.contentLength, safeAdd(playbackAnchor, window))
        guard upper > playbackAnchor else { return nil }
        let firstPlaybackBlock = rangeMap.snapshot(anchor: playbackAnchor, resourceLength: resource.contentLength).playbackBytes == 0
        let largeIndexedMP4Startup = source.mediaSource.normalizedContainer == "mp4" && resource.contentLength >= 4 * 1_073_741_824
        let initialBytes = largeIndexedMP4Startup ? largeFileInitialSequentialBlockBytes : initialSequentialBlockBytes
        let segmentBytes = firstPlaybackBlock ? min(blockBytes, initialBytes) : blockBytes
        return rangeMap.nextClaim(
            from: playbackAnchor,
            resourceLength: upper,
            segmentBytes: segmentBytes,
            workerLimit: 2,
            lookaheadSegments: lookaheadSegments
        )
    }

    private func startSlot(_ slot: Int, claim: SlotClaim, reason: String) {
        guard slotTasks[slot] == nil, !claim.range.isEmpty else { return }
        let generation = (slotGenerations[slot] ?? 0) + 1
        slotGenerations[slot] = generation
        slotClaims[slot] = claim
        if claim.role == .sequential {
            var live = liveLaneState[slot] ?? LiveLaneState()
            let now = Date()
            live.generation = generation
            live.startedAt = now
            live.lastChunkAt = now
            live.sampleWindowStartedAt = now
            live.sampleWindowStartedBytes = 0
            live.lastSampleAt = .distantPast
            live.receivedBytes = 0
            live.recentBps = 0
            live.slowStreak = 0
            liveLaneState[slot] = live
            armFirstByteWatchdog(slot: slot, generation: generation)
        } else if claim.role == .startupMetadata {
            startupMetadataReceivedBytes[slot] = 0
            startupMetadataStartedAt[slot] = Date()
            armStartupMetadataStragglerWatchdog(slot: slot, generation: generation)
        }
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
            finishSlot(slot: slot, generation: generation, claim: claim, downloadedBytes: nil, error: MediaTransportError.cancelled)
            return
        }
        var receivedForClaim: Int64 = 0
        do {
            let started = Date()
            if claim.role == .sequential {
                // Keep one long Range request alive for throughput while every received chunk is
                // committed to ByteStore immediately. This preserves progressive visibility without
                // paying a fresh HTTP Range request every 4 MiB.
                while receivedForClaim < Int64(claim.range.count) {
                    try Task.checkCancellation()
                    let remaining = (claim.range.lowerBound + receivedForClaim)..<claim.range.upperBound
                    let attemptStarted = Date()
                    var attemptReceived: Int64 = 0
                    do {
                        for try await chunk in client.stream(resource: resolved, range: remaining, worker: slot) {
                            try Task.checkCancellation()
                            let writeOffset = claim.range.lowerBound + receivedForClaim
                            try store.write(chunk, at: writeOffset)
                            receivedForClaim += Int64(chunk.count)
                            attemptReceived += Int64(chunk.count)
                            recordNetworkBytes(Int64(chunk.count))
                            rangeMap.insertPlayback(writeOffset..<min(claim.range.upperBound, writeOffset + Int64(chunk.count)))
                            if attemptReceived == Int64(chunk.count) {
                                let firstChunkSeconds = max(Date().timeIntervalSince(attemptStarted), 0.001)
                                DiagnosticsLogger.shared.log("UnifiedSlot", "slot=\(slot) first-chunk role=sequential range=\(remaining.lowerBound)-\(remaining.upperBound) bytes=\(chunk.count) ms=\(Int(firstChunkSeconds * 1000)) speedBps=\(Int(Double(chunk.count) / firstChunkSeconds))")
                            }
                            observeSequentialChunk(slot: slot, generation: generation, bytes: Int64(chunk.count))
                            try Task.checkCancellation()
                            refreshMetrics(resource: resolved)
                        }
                    } catch MediaTransportError.expiredURL {
                        DiagnosticsLogger.shared.log("UnifiedTransport", "slot=\(slot) refreshing expired 115 URL")
                        resource = nil
                        resolved = try await resolve()
                        continue
                    }
                    break
                }
                let elapsed = max(Date().timeIntervalSince(started), 0.001)
                let bps = Double(receivedForClaim) / elapsed
                DiagnosticsLogger.shared.log("UnifiedSlot", "slot=\(slot) finish role=\(claim.role.rawValue) range=\(claim.range.lowerBound)-\(claim.range.upperBound) bytes=\(receivedForClaim) speedBps=\(Int(bps)) progressive=true longRange=true")
                finishSlot(slot: slot, generation: generation, claim: claim, downloadedBytes: receivedForClaim > 0 ? receivedForClaim : nil, error: nil, completedSequentialBps: bps)
            } else {
                var slowStartupRefreshUsed = false
                while receivedForClaim < Int64(claim.range.count) {
                    let remaining = (claim.range.lowerBound + receivedForClaim)..<claim.range.upperBound
                    let attemptStarted = Date()
                    var attemptReceived: Int64 = 0
                    var restartAfterSlowStartup = false
                    do {
                        for try await chunk in client.stream(resource: resolved, range: remaining, worker: slot) {
                            try Task.checkCancellation()
                            try store.write(chunk, at: claim.range.lowerBound + receivedForClaim)
                            receivedForClaim += Int64(chunk.count)
                            attemptReceived += Int64(chunk.count)
                            if claim.role == .startupMetadata {
                                startupMetadataReceivedBytes[slot] = receivedForClaim
                                startupMetadataLastProgressAt[slot] = Date()
                            }
                            recordNetworkBytes(Int64(chunk.count))
                            let writtenLower = claim.range.lowerBound + receivedForClaim - Int64(chunk.count)
                            let written = writtenLower..<min(claim.range.upperBound, writtenLower + Int64(chunk.count))
                            if claim.role == .metadata || claim.role == .startupMetadata { rangeMap.insertMetadata(written) } else { rangeMap.insertPlayback(written) }
                            if attemptReceived == Int64(chunk.count) {
                                let firstChunkSeconds = max(Date().timeIntervalSince(attemptStarted), 0.001)
                                let firstChunkBps = Double(chunk.count) / firstChunkSeconds
                                DiagnosticsLogger.shared.log("UnifiedSlot", "slot=\(slot) first-chunk role=\(claim.role.rawValue) range=\(remaining.lowerBound)-\(remaining.upperBound) bytes=\(chunk.count) ms=\(Int(firstChunkSeconds * 1000)) speedBps=\(Int(firstChunkBps))")
                                if claim.role == .metadata, !slowStartupRefreshUsed, Date().timeIntervalSince(createdAt) < 35, firstChunkSeconds >= startupMetadataSlowFirstChunkSeconds, firstChunkBps < startupMetadataSlowFirstChunkBps {
                                    slowStartupRefreshUsed = true
                                    restartAfterSlowStartup = true
                                    DiagnosticsLogger.shared.log("UnifiedRecovery", "slow-start metadata firstChunkMs=\(Int(firstChunkSeconds * 1000)) speedBps=\(Int(firstChunkBps)) received=\(receivedForClaim) action=refresh-115-source-and-resume")
                                    break
                                }
                            }
                            refreshMetrics(resource: resolved)
                        }
                    } catch MediaTransportError.expiredURL {
                        DiagnosticsLogger.shared.log("UnifiedTransport", "slot=\(slot) refreshing expired 115 URL")
                        resource = nil
                        resolved = try await resolve()
                        continue
                    }
                    if restartAfterSlowStartup {
                        resource = nil
                        resolved = try await resolve()
                        continue
                    }
                    break
                }
                let elapsed = max(Date().timeIntervalSince(started), 0.001)
                let bps = Double(receivedForClaim) / elapsed
                DiagnosticsLogger.shared.log("UnifiedSlot", "slot=\(slot) finish role=\(claim.role.rawValue) range=\(claim.range.lowerBound)-\(claim.range.upperBound) bytes=\(receivedForClaim) speedBps=\(Int(bps)) streamed=true")
                finishSlot(slot: slot, generation: generation, claim: claim, downloadedBytes: receivedForClaim > 0 ? receivedForClaim : nil, error: nil)
            }
        } catch is CancellationError {
            finishSlot(slot: slot, generation: generation, claim: claim, downloadedBytes: receivedForClaim > 0 ? receivedForClaim : nil, error: MediaTransportError.cancelled)
        } catch {
            finishSlot(slot: slot, generation: generation, claim: claim, downloadedBytes: receivedForClaim > 0 ? receivedForClaim : nil, error: error)
        }
    }

    private func finishSlot(slot: Int, generation: Int, claim: SlotClaim, downloadedBytes: Int64?, error: Error?, completedSequentialBps: Double? = nil) {
        guard slotGenerations[slot] == generation else { return }
        slotTasks[slot] = nil
        slotClaims[slot] = nil
        rangeMap.clearDownloading(lane: "slot\(slot)")

        let startupRetry = startupMetadataRetryRequested.remove(slot) != nil
        let liveRotation = liveLaneRotationRequested.remove(slot) != nil
        if startupRetry {
            startupMetadataQueue.insert(claim.range, at: 0)
            let reset = client.resetStreamLane(worker: slot, reason: "startup-metadata-straggler")
            if !reset {
                liveLaneResetPending.insert(slot)
                armLiveLaneResetRetry(slot: slot, attempt: 1)
            }
            DiagnosticsLogger.shared.log("UnifiedStartup", "slot=\(slot) action=straggler-reset range=\(claim.range.lowerBound)-\(claim.range.upperBound) success=\(reset)")
        } else if liveRotation {
            let reset = client.resetStreamLane(worker: slot, reason: "live-lane-rotation")
            if !reset {
                liveLaneResetPending.insert(slot)
                armLiveLaneResetRetry(slot: slot, attempt: 1)
            }
            DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\(slot) action=reset-after-cancel success=\(reset) pending=\(!reset)")
            laneHealth[slot] = LaneHealthState()
        } else if claim.role == .sequential, error == nil, let completedSequentialBps, let downloadedBytes {
            considerSequentialLaneHealth(slot: slot, bytes: downloadedBytes, bps: completedSequentialBps)
        }

        if claim.role == .startupMetadata, error == nil, let plan = startupMetadataPlanRange, startupMetadataQueue.isEmpty, !slotClaims.values.contains(where: { $0.role == .startupMetadata }), store?.contains(plan) == true {
            startupMetadataPlanCompleted = true
            DiagnosticsLogger.shared.log("UnifiedStartup", "actual-tail plan complete range=\(plan.lowerBound)-\(plan.upperBound) bytes=\(plan.count)")
        }

        if let downloadedBytes, downloadedBytes > 0 {
            let written = claim.range.lowerBound..<min(claim.range.upperBound, claim.range.lowerBound + downloadedBytes)
            if claim.role == .metadata || claim.role == .startupMetadata { rangeMap.insertMetadata(written) }
            else { rangeMap.insertPlayback(written) }
            // Network bytes/speed are recorded per received chunk so long 32 MiB requests do not
            // display as zero throughput until the entire Range finishes.

            if slot == 0, claim.role == .sequential, downloadedBytes >= Int64(claim.range.count) {
                successfulPrimaryBlocks += 1
                if !secondaryEnabled, successfulPrimaryBlocks >= 1 {
                    secondaryEnabled = true
                    DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled after primary stable block")
                }
                if claim.range.lowerBound == 0, Int64(claim.range.count) <= largeFileInitialSequentialBlockBytes, source.mediaSource.normalizedContainer == "mp4", (resource?.contentLength ?? 0) >= 4 * 1_073_741_824 {
                    startupTailDemandGraceUntil = Date().addingTimeInterval(startupTailDemandGraceSeconds)
                    DiagnosticsLogger.shared.log("UnifiedStartup", "head warmup complete range=\(claim.range.lowerBound)-\(claim.range.upperBound) action=await-actual-tail-demand graceMs=\(Int(startupTailDemandGraceSeconds * 1000))")
                    armStartupTailGraceResume()
                }
            }
            if (claim.role == .metadata || claim.role == .startupMetadata), downloadedBytes >= Int64(claim.range.count), !secondaryEnabled {
                secondaryEnabled = true
                DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled after critical metadata")
            }
            if slot == 0, claim.role == .urgentPlayback, downloadedBytes >= Int64(claim.range.count), pendingPlaybackUrgentRange == nil, pendingMetadataRange == nil, slotClaims[1]?.role != .metadata, !secondaryEnabled {
                secondaryEnabled = true
                DiagnosticsLogger.shared.log("UnifiedSlot", "secondary enabled after urgent playback settled")
            }
            if slot == 1 { secondaryFailureCount = 0 }
        }

        if let error, !isCancellation(error) {
            if claim.role == .startupMetadata { startupMetadataQueue.insert(claim.range, at: 0) }
            else if claim.role == .metadata, pendingMetadataRange == nil { pendingMetadataRange = claim.range }
            if claim.role == .urgentPlayback, pendingPlaybackUrgentRange == nil { pendingPlaybackUrgentRange = claim.range }
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

    private func armStartupMetadataStragglerWatchdog(slot: Int, generation: Int) {
        let delay = liveLaneFirstBytePeerTimeoutSeconds
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await self?.checkStartupMetadataStraggler(slot: slot, generation: generation)
        }
    }

    private func checkStartupMetadataStraggler(slot: Int, generation: Int) {
        guard slotGenerations[slot] == generation, slotClaims[slot]?.role == .startupMetadata, startupMetadataReceivedBytes[slot, default: 0] == 0, !startupMetadataRetryRequested.contains(slot) else { return }
        let peerSlot = slot == 0 ? 1 : 0
        let startedAt = startupMetadataStartedAt[slot, default: .distantPast]
        let peerProgressAt = startupMetadataLastProgressAt[peerSlot, default: .distantPast]
        guard peerProgressAt > startedAt else { return }
        startupMetadataRetryRequested.insert(slot)
        DiagnosticsLogger.shared.log("UnifiedStartup", "slot=\(slot) action=straggler-cancel peer=\(peerSlot) peerProgressMsAgo=\(Int(Date().timeIntervalSince(peerProgressAt) * 1000)) range=\(slotClaims[slot]?.range.description ?? "none")")
        cancelSlot(slot, reason: "startup-metadata-straggler")
    }

    private func armStartupTailGraceResume() {
        guard !startupTailGraceResumeScheduled else { return }
        startupTailGraceResumeScheduled = true
        let delay = startupTailDemandGraceSeconds
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await self?.resumeAfterStartupTailGrace()
        }
    }

    private func resumeAfterStartupTailGrace() {
        startupTailGraceResumeScheduled = false
        guard !stopped, startupMetadataPlanRange == nil, Date() >= startupTailDemandGraceUntil else { return }
        scheduleSlots(reason: "startup-tail-grace-ended")
    }

    private func armLiveLaneResetRetry(slot: Int, attempt: Int) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            await self?.retryLiveLaneReset(slot: slot, attempt: attempt)
        }
    }

    private func retryLiveLaneReset(slot: Int, attempt: Int) {
        guard liveLaneResetPending.contains(slot), !stopped else { return }
        if client.resetStreamLane(worker: slot, reason: "live-lane-retry-\(attempt)") {
            liveLaneResetPending.remove(slot)
            DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\(slot) action=reset-retry success=true attempt=\(attempt)")
            scheduleSlots(reason: "live-lane-reset-ready")
            return
        }
        if attempt < 10 {
            armLiveLaneResetRetry(slot: slot, attempt: attempt + 1)
        } else {
            liveLaneResetPending.remove(slot)
            DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\(slot) action=reset-retry give-up attempt=\(attempt)")
            scheduleSlots(reason: "live-lane-reset-give-up")
        }
    }

    private func armFirstByteWatchdog(slot: Int, generation: Int) {
        let peerDelay = liveLaneFirstBytePeerTimeoutSeconds
        let hardDelay = liveLaneFirstByteHardTimeoutSeconds - liveLaneFirstBytePeerTimeoutSeconds
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(peerDelay * 1_000_000_000))
            await self?.checkFirstByteWatchdog(slot: slot, generation: generation, hard: false)
            try? await Task.sleep(nanoseconds: UInt64(hardDelay * 1_000_000_000))
            await self?.checkFirstByteWatchdog(slot: slot, generation: generation, hard: true)
        }
    }

    private func checkFirstByteWatchdog(slot: Int, generation: Int, hard: Bool) {
        guard slotGenerations[slot] == generation, slotClaims[slot]?.role == .sequential, let live = liveLaneState[slot], live.generation == generation, live.receivedBytes == 0 else { return }
        let peerSlot = slot == 0 ? 1 : 0
        let peerLive = liveLaneState[peerSlot]
        let peerCompleted = laneHealth[peerSlot]
        let now = Date()
        let peerLiveFresh = peerLive.map { $0.receivedBytes > 0 && now.timeIntervalSince($0.lastChunkAt) <= 4 } ?? false
        let peerBps: Double
        if let peerLive, peerLiveFresh {
            let elapsed = max(now.timeIntervalSince(peerLive.startedAt), 0.001)
            peerBps = peerLive.recentBps > 0 ? peerLive.recentBps : Double(peerLive.receivedBytes) / elapsed
        } else {
            peerBps = peerCompleted?.averageBps ?? 0
        }
        guard hard || peerBps >= 2 * 1_048_576 else { return }
        requestLiveLaneRotation(slot: slot, generation: generation, reason: hard ? "first-byte-hard-timeout" : "first-byte-peer-fast", observedBps: 0, peerBps: peerBps)
    }

    private func observeSequentialChunk(slot: Int, generation: Int, bytes: Int64) {
        guard bytes > 0, slotGenerations[slot] == generation, slotClaims[slot]?.role == .sequential else { return }
        let now = Date()
        var live = liveLaneState[slot] ?? LiveLaneState()
        guard live.generation == generation else { return }
        live.lastChunkAt = now
        live.receivedBytes += bytes

        // URLSession may deliver several already-buffered chunks back-to-back. Measuring one chunk
        // against the previous callback timestamp produced impossible 100-500 MB/s samples and false
        // lane rotations. Only a real time window is allowed to influence connection health.
        let sampleSeconds = now.timeIntervalSince(live.sampleWindowStartedAt)
        let sampleBytes = live.receivedBytes - live.sampleWindowStartedBytes
        guard sampleSeconds >= liveLaneSampleWindowSeconds, sampleBytes >= liveLaneSampleMinimumBytes else {
            liveLaneState[slot] = live
            return
        }
        let windowBps = Double(sampleBytes) / max(sampleSeconds, 0.001)
        live.sampleWindowStartedAt = now
        live.sampleWindowStartedBytes = live.receivedBytes
        live.lastSampleAt = now
        live.recentBps = live.recentBps == 0 ? windowBps : live.recentBps * 0.60 + windowBps * 0.40

        let peerSlot = slot == 0 ? 1 : 0
        let peerLive = liveLaneState[peerSlot]
        let peerLiveFresh = peerLive.map { $0.recentBps > 0 && now.timeIntervalSince($0.lastSampleAt) <= 2.5 } ?? false
        let peerBps = peerLiveFresh ? (peerLive?.recentBps ?? 0) : 0
        let relativeSlow = peerLiveFresh && peerBps >= liveLanePeerFloorBps && live.recentBps < peerBps * liveLaneRelativeFloor
        let absoluteSlow = now.timeIntervalSince(live.startedAt) >= 3.0 && live.receivedBytes >= 4 * 1_048_576 && live.recentBps < liveLaneAbsoluteFloorBps
        if relativeSlow || absoluteSlow { live.slowStreak += 1 }
        else if live.recentBps >= max(liveLaneAbsoluteFloorBps * 1.25, peerBps * 0.65) { live.slowStreak = 0 }
        liveLaneState[slot] = live
        DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\(slot) windowMs=\(Int(sampleSeconds * 1000)) windowBytes=\(sampleBytes) sampleBps=\(Int(windowBps)) avgBps=\(Int(live.recentBps)) peerBps=\(Int(peerBps)) slowStreak=\(live.slowStreak)")

        if live.slowStreak >= 2 {
            requestLiveLaneRotation(slot: slot, generation: generation, reason: relativeSlow ? "rolling-relative-slow" : "rolling-absolute-slow", observedBps: live.recentBps, peerBps: peerBps)
        }
    }

    private func requestLiveLaneRotation(slot: Int, generation: Int, reason: String, observedBps: Double, peerBps: Double) {
        guard slotGenerations[slot] == generation, slotClaims[slot]?.role == .sequential, !liveLaneRotationRequested.contains(slot) else { return }
        var live = liveLaneState[slot] ?? LiveLaneState()
        let now = Date()
        guard now >= live.resetCooldownUntil else { return }
        live.resetCooldownUntil = now.addingTimeInterval(liveLaneResetCooldownSeconds)
        liveLaneState[slot] = live
        liveLaneRotationRequested.insert(slot)
        if preferredBulkSlot == slot { preferredBulkSlot = slot == 0 ? 1 : 0 }
        DiagnosticsLogger.shared.log("UnifiedLiveLane", "slot=\(slot) action=rotate-live-lane reason=\(reason) observedBps=\(Int(observedBps)) peerBps=\(Int(peerBps)) received=\(live.receivedBytes)")
        cancelSlot(slot, reason: "live-lane-rotation")
    }

    private func considerSequentialLaneHealth(slot: Int, bytes: Int64, bps: Double) {
        guard bytes >= laneHealthMinSampleBytes, bps > 0 else { return }
        let now = Date()
        let peerSlot = slot == 0 ? 1 : 0
        var current = laneHealth[slot] ?? LaneHealthState()
        let peer = laneHealth[peerSlot] ?? LaneHealthState()
        let peerIsFresh = peer.samples > 0 && now.timeIntervalSince(peer.lastSampleAt) <= laneHealthPeerFreshSeconds

        current.averageBps = current.samples == 0 ? bps : current.averageBps * 0.65 + bps * 0.35
        current.samples += 1
        current.lastSampleAt = now
        current.slowStreak = 0
        laneHealth[slot] = current

        if peerIsFresh {
            if current.averageBps >= peer.averageBps * 1.20, preferredBulkSlot != slot {
                preferredBulkSlot = slot
                DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "protected bulk changed slot=\(slot) avgBps=\(Int(current.averageBps)) peerAvgBps=\(Int(peer.averageBps))")
            } else if peer.averageBps >= current.averageBps * 1.20, preferredBulkSlot == slot {
                preferredBulkSlot = peerSlot
                DiagnosticsLogger.shared.log("UnifiedSchedulerV2", "protected bulk changed slot=\(peerSlot) avgBps=\(Int(peer.averageBps)) peerAvgBps=\(Int(current.averageBps))")
            }
        }

        DiagnosticsLogger.shared.log("UnifiedLaneHealth", "slot=\(slot) sampleBps=\(Int(bps)) avgBps=\(Int(current.averageBps)) peer=\(peerSlot) peerAvgBps=\(Int(peer.averageBps)) peerFresh=\(peerIsFresh) action=advisory-only protectedBulk=\(preferredBulkSlot)")
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

    private func recordNetworkBytes(_ bytes: Int64) {
        guard bytes > 0 else { return }
        metricsValue.bytesDownloaded += bytes
        speedSamples.append(SpeedSample(date: Date(), bytes: bytes))
        pruneSpeedSamples()
    }

    private func refreshMetrics(resource: TransportResolvedResource) {
        guard let store else { return }
        let map = rangeMap.snapshot(anchor: playbackAnchor, resourceLength: resource.contentLength)
        metricsValue.resourceBytes = resource.contentLength
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
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }

    private func preloadWindowBytes() -> Int64 {
        if NetworkPathMonitor.shared.isCellular {
            // Unified Transport v3 uses its own configured cellular byte window. A non-zero cellular
            // budget means prefetch is enabled; zero remains the explicit opt-out. Do not inherit the
            // legacy KTV proxy switch, otherwise v3 becomes urgent-only and can go idle after a seek.
            return max(0, configuration.cellularPreloadBytes)
        }
        // On Wi-Fi the session disk budget is the real prefetch ceiling. The old 128 MiB
        // setting was only a forward-window hint and made a fast 115 connection stop by
        // design after a few seconds. Keep downloading while there is session-cache budget.
        if configuration.ktvContinuousPreloadEnabled, configuration.usesDiskCache, configuration.diskLimitBytes > 0 {
            return max(configuration.wifiPreloadBytes, configuration.diskLimitBytes)
        }
        return max(0, configuration.wifiPreloadBytes)
    }

    private func isStartupTailMetadata(_ range: Range<Int64>, resource: TransportResolvedResource) -> Bool {
        guard !range.isEmpty, playbackAnchor == 0, Date() > pendingUserSeekUntil else { return false }
        guard source.mediaSource.normalizedContainer == "mp4", resource.contentLength >= 4 * 1_073_741_824 else { return false }
        if let plan = startupMetadataPlanRange, range.upperBound > plan.lowerBound, range.lowerBound < plan.upperBound { return true }
        guard Date().timeIntervalSince(createdAt) < 35 else { return false }
        return range.lowerBound >= resource.contentLength - 64 * 1_048_576
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
