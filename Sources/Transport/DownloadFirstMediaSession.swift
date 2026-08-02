import Foundation

enum DownloadFirstDemandMode {
    case localHTTP
    case directAVIO
}

actor DownloadFirstMediaSession: TransportDataSession {
    private struct RefreshResult {
        let source: ResolvedPlaybackSource
        let resource: TransportResolvedResource
    }

    private struct SpeedSample {
        let date: Date
        let bytes: Int64
    }

    private struct DemandSample {
        let date: Date
        let offset: Int64
        let length: Int64
        let blocked: Bool
    }

    private var source: ResolvedPlaybackSource
    private let client: EmbyAPIClient
    private let configuration: MediaTransportConfiguration
    private let demandMode: DownloadFirstDemandMode
    private let resolver = RedirectResolver()

    private var resource: TransportResolvedResource?
    private var resolveTask: Task<TransportResolvedResource, Error>?
    private var refreshTask: Task<RefreshResult, Error>?
    private var store: DownloadFirstSparseStore?

    private var mainTask: Task<Void, Never>?
    private var urgentTask: Task<Void, Never>?
    private var urgentRange: Range<Int64>?
    private var pendingUrgentOffsets: [Int64] = []
    private var migrationTask: Task<Void, Never>?
    private var seekMigrationTask: Task<Void, Never>?
    private var laneProbeTask: Task<Void, Never>?

    private var mainGeneration = 0
    private var seekGeneration = 0
    private var demandGeneration = 0
    private var mainCursor: Int64 = 0
    private var mainRunning = false
    private var mainAnchor: Int64 = 0
    private var mainUpperBound: Int64 = 0
    private var mainStartedAt = Date.distantPast

    private var demandSamples: [DemandSample] = []
    private var lastDemandOffset: Int64?
    private var lastBlockedDemandOffset: Int64?
    private var lastDemandAt = Date.distantPast
    private var lastSeekHintOffset: Int64?
    private var lastSeekHintAt = Date.distantPast
    private var lastMainMigrationAt = Date.distantPast

    private var metricsValue = TransportMetricsSnapshot()
    private var speedSamples: [SpeedSample] = []
    private var mainSpeedSamples: [SpeedSample] = []
    private var currentMainBytesPerSecond: Double = 0
    private var laneProbeCooldownUntil = Date.distantPast

    private let createdAt = Date()
    private var lastLoggedMegabytes: Int64 = 0
    private var stopped = false

    init(source: ResolvedPlaybackSource, client: EmbyAPIClient, configuration: MediaTransportConfiguration, demandMode: DownloadFirstDemandMode = .localHTTP) {
        self.source = source
        self.client = client
        self.configuration = configuration
        self.demandMode = demandMode
    }

    func resolve() async throws -> TransportResolvedResource {
        if let resource { return resource }
        if let resolveTask { return try await resolveTask.value }

        let sourceSnapshot = source
        let resolver = resolver
        let task = Task<TransportResolvedResource, Error> { try await resolver.resolve(source: sourceSnapshot) }
        resolveTask = task

        do {
            let resolved = try await task.value
            resolveTask = nil
            guard resolved.supportsByteRanges else { throw MediaTransportError.rangeUnsupported(statusCode: 200) }
            resource = resolved
            if store == nil {
                store = try DownloadFirstSparseStore(
                    cacheKey: "\(source.itemId)-\(source.mediaSource.id)",
                    contentLength: resolved.contentLength,
                    etag: resolved.etag,
                    lastModified: resolved.lastModified,
                    keepFiles: configuration.keepLastCache
                )
            }
            DiagnosticsLogger.shared.log(
                "DownloadFirst",
                "ready item=\(source.itemId) bytes=\(resolved.contentLength) mainConnections=1 seekConnections=1 adaptiveLaneProbe=\(!resolved.looksLike115CDN) demandMode=\(demandMode) wifiPreload=\(configuration.wifiPreloadBytes) cellularPreload=\(configuration.cellularPreloadBytes) keep=\(configuration.keepLastCache)"
            )
            startMainDownloader(anchor: 0, reason: "initial")
            return resolved
        } catch {
            resolveTask = nil
            throw error
        }
    }

    func noteDemand(range: Range<Int64>) async {
        guard !stopped, !range.isEmpty, let resource = try? await resolve(), let store else { return }
        let lower = min(max(0, range.lowerBound), max(0, resource.contentLength - 1))
        let upper = min(max(lower + 1, range.upperBound), resource.contentLength)
        let length = upper - lower

        // Tiny tail/metadata probes must never become the primary demand anchor.
        guard length >= 4 * 1_048_576 else { return }
        let available = store.availableLength(from: lower, maximumLength: min(length, 1_048_576))
        recordDemand(offset: lower, length: length, blocked: available == 0)
        guard available == 0 else { return }

        let mainGap = lower - mainCursor
        let mainShouldArriveSoon = mainRunning && mainGap >= 0 && mainGap <= 8 * 1_048_576
        guard !mainShouldArriveSoon else { return }
        ensureUrgentDownload(offset: lower, resource: resource, replaceExisting: false, reason: "http-range")
        scheduleMainMigrationFromActualDemand(to: lower, resource: resource, reason: "http-range")
    }

    func read(offset: Int64, length: Int) async throws -> Data {
        guard !stopped else { throw MediaTransportError.cancelled }
        guard length > 0 else { return Data() }
        let resource = try await resolve()
        guard offset < resource.contentLength else { return Data() }
        guard let store else { throw MediaTransportError.invalidResponse }

        let requestedLength = min(length, Int(resource.contentLength - offset))
        let availableBeforeRead = store.availableLength(from: offset, maximumLength: Int64(requestedLength))
        let metadataProbe = isMetadataProbe(offset: offset, length: requestedLength, contentLength: resource.contentLength)
        if !metadataProbe {
            recordDemand(offset: offset, length: Int64(requestedLength), blocked: availableBeforeRead == 0)
        }

        if availableBeforeRead == 0 {
            if !metadataProbe { lastBlockedDemandOffset = offset }
            let mainGap = offset - mainCursor
            let mainShouldArriveSoon = mainRunning && mainGap >= 0 && mainGap <= 8 * 1_048_576
            if !mainShouldArriveSoon {
                ensureUrgentDownload(offset: offset, resource: resource, replaceExisting: false, reason: "blocked-read")
                if demandMode == .localHTTP, !metadataProbe {
                    scheduleMainMigrationFromActualDemand(to: offset, resource: resource, reason: "blocked-read")
                }
            }
        }

        let data: Data
        do {
            data = try await store.readWhenAvailable(offset: offset, maximumLength: requestedLength, timeout: 5)
        } catch let error as DownloadFirstSparseStore.StoreError {
            guard case .timeout = error else { throw error }
            if demandMode == .localHTTP, isFarFromRecentSeek(offset: offset, resource: resource) {
                DiagnosticsLogger.shared.log(
                    "DownloadFirstGap",
                    "cancel stale local HTTP demand offset=\(offset) seekHint=\(lastSeekHintOffset ?? -1)"
                )
                throw CancellationError()
            }
            DiagnosticsLogger.shared.log(
                "DownloadFirstGap",
                "read timeout offset=\(offset) length=\(requestedLength) mainCursor=\(mainCursor) mainRunning=\(mainRunning); forcing real-demand recovery"
            )
            forceDemandRecovery(offset: offset, resource: resource, reason: "read-timeout")
            data = try await store.readWhenAvailable(offset: offset, maximumLength: requestedLength, timeout: 25)
        }

        metricsValue.bytesServed += Int64(data.count)
        if availableBeforeRead > 0 { metricsValue.cacheHitBytes += Int64(data.count) }
        if lastBlockedDemandOffset == offset, !data.isEmpty { lastBlockedDemandOffset = nil }
        metricsValue.elapsedSeconds = Date().timeIntervalSince(createdAt)
        return data
    }

    func prioritizeSeek(position: Double, duration: Double) async {
        guard !stopped, position.isFinite, duration.isFinite, duration > 0 else { return }
        guard let resource = try? await resolve() else { return }
        let ratio = min(max(position / duration, 0), 1)
        let approximateOffset = alignedOffset(Int64(Double(resource.contentLength) * ratio), contentLength: resource.contentLength)
        seekGeneration += 1
        lastSeekHintOffset = approximateOffset
        lastSeekHintAt = Date()
        migrationTask?.cancel()
        migrationTask = nil
        DiagnosticsLogger.shared.log(
            "DownloadFirstPriority",
            "seek position=\(position) duration=\(duration) approximateOffset=\(approximateOffset) generation=\(seekGeneration) migration=stable-seek"
        )

        // The ratio hint fills the urgent window immediately. Only the final stable seek moves the sequential lane.
        ensureUrgentDownload(offset: approximateOffset, resource: resource, replaceExisting: true, reason: "seek-hint")
        scheduleMainMigrationAfterStableSeek(hintOffset: approximateOffset, resource: resource, generation: seekGeneration)
    }

    func recoverStall(position: Double, duration: Double) async {
        guard !stopped, let resource = try? await resolve(), let store else { return }
        let fallbackRatio = duration > 0 ? min(max(position / duration, 0), 1) : 0
        let fallback = alignedOffset(Int64(Double(resource.contentLength) * fallbackRatio), contentLength: resource.contentLength)
        let actual = lastBlockedDemandOffset ?? lastDemandOffset ?? fallback
        let contiguous = store.availableLength(from: actual, maximumLength: 32 * 1_048_576)

        DiagnosticsLogger.shared.log(
            "DownloadFirstRecovery",
            "stall position=\(position) actualDemand=\(actual) fallback=\(fallback) contiguous=\(contiguous) mainCursor=\(mainCursor) mainRunning=\(mainRunning)"
        )

        guard contiguous < 4 * 1_048_576 else { return }
        forceDemandRecovery(offset: actual, resource: resource, reason: "stall-watchdog")
    }

    func migrateMainToAVIOOffset(_ offset: Int64, reason: String) async {
        guard !stopped, let resource = try? await resolve(), let store else { return }
        let target = alignedOffset(offset, contentLength: resource.contentLength)
        let available = store.availableLength(from: target, maximumLength: 4 * 1_048_576)
        ensureUrgentDownload(offset: target, resource: resource, replaceExisting: true, reason: "avio-\(reason)")
        guard available < 4 * 1_048_576 else { return }
        let previous = mainAnchor
        startMainDownloader(anchor: target, reason: "avio-\(reason)")
        DiagnosticsLogger.shared.log("DownloadFirstMain", "migrated-exact-avio from=\(previous) to=\(target) reason=\(reason)")
    }

    func metrics() async -> TransportMetricsSnapshot {
        var value = metricsValue
        let now = Date()
        value.elapsedSeconds = now.timeIntervalSince(createdAt)
        updateCurrentSpeed(now: now)
        value.currentDownloadBytesPerSecond = metricsValue.currentDownloadBytesPerSecond
        let uniqueBytes = store?.uniqueBytes ?? 0
        value.cacheBytes = uniqueBytes
        value.diskCacheBytes = uniqueBytes
        value.memoryCacheBytes = 0
        if let store, let demandOffset = lastDemandOffset ?? lastBlockedDemandOffset {
            value.contiguousCacheBytes = store.availableLength(from: demandOffset, maximumLength: resource?.contentLength ?? Int64.max)
        } else {
            value.contiguousCacheBytes = store?.availableLength(from: 0, maximumLength: resource?.contentLength ?? Int64.max) ?? 0
        }
        return value
    }

    func stop() async {
        guard !stopped else { return }
        stopped = true
        resolveTask?.cancel()
        resolveTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        migrationTask?.cancel()
        migrationTask = nil
        seekMigrationTask?.cancel()
        seekMigrationTask = nil
        laneProbeTask?.cancel()
        laneProbeTask = nil
        mainTask?.cancel()
        mainTask = nil
        mainRunning = false
        urgentTask?.cancel()
        urgentTask = nil
        urgentRange = nil
        pendingUrgentOffsets.removeAll()
        let finalMetrics = await metrics()
        store?.close(removeFiles: !configuration.keepLastCache)
        store = nil
        DiagnosticsLogger.shared.log("DownloadFirst", "stopped \(finalMetrics.summary)")
    }

    private func startMainDownloader(anchor: Int64, reason: String) {
        guard !stopped, let resource, store != nil else { return }
        let alignedAnchor = alignedOffset(anchor, contentLength: resource.contentLength)
        let networkLimit = NetworkPathMonitor.shared.isCellular ? configuration.cellularPreloadBytes : configuration.wifiPreloadBytes
        var effectiveLimit = networkLimit > 0 ? networkLimit : resource.contentLength
        if configuration.diskLimitBytes > 0 { effectiveLimit = min(effectiveLimit, configuration.diskLimitBytes) }
        let upperBound = min(resource.contentLength, alignedAnchor + effectiveLimit)
        guard upperBound > alignedAnchor else { return }

        mainGeneration += 1
        let generation = mainGeneration
        mainAnchor = alignedAnchor
        mainUpperBound = upperBound
        mainRunning = true
        mainStartedAt = Date()
        mainSpeedSamples.removeAll(keepingCapacity: true)
        currentMainBytesPerSecond = 0
        laneProbeTask?.cancel()
        laneProbeTask = nil
        mainTask?.cancel()
        mainTask = Task { [weak self] in
            guard let self else { return }
            await self.runMainDownloader(anchor: alignedAnchor, upperBound: upperBound, generation: generation, reason: reason)
        }
    }

    private func runMainDownloader(anchor: Int64, upperBound: Int64, generation: Int, reason: String) async {
        guard let store else { return }
        defer { if generation == mainGeneration { mainRunning = false } }
        var cursor = store.firstMissingOffset(from: anchor, upperBound: upperBound) ?? upperBound
        mainCursor = cursor
        DiagnosticsLogger.shared.log(
            "DownloadFirstMain",
            "start anchor=\(anchor) cursor=\(cursor) end=\(upperBound) generation=\(generation) reason=\(reason)"
        )

        while !Task.isCancelled, !stopped, generation == mainGeneration, cursor < upperBound {
            let failedResource: TransportResolvedResource
            do {
                failedResource = try await resolve()
            } catch {
                DiagnosticsLogger.shared.log("DownloadFirstMain", "resolve failed: \(error.localizedDescription)")
                return
            }

            do {
                cursor = try await consumeStream(
                    resource: failedResource,
                    start: cursor,
                    end: upperBound,
                    label: "main",
                    generation: generation,
                    enforceGeneration: true
                )
            } catch is CancellationError {
                return
            } catch MediaTransportError.expiredURL(_) {
                metricsValue.rangeFailureCount += 1
                DiagnosticsLogger.shared.log("DownloadFirstRetry", "main 403/410 cursor=\(cursor) retrying current URL")
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled, generation == mainGeneration else { return }

                do {
                    cursor = try await consumeStream(
                        resource: failedResource,
                        start: cursor,
                        end: upperBound,
                        label: "main-retry",
                        generation: generation,
                        enforceGeneration: true
                    )
                } catch MediaTransportError.expiredURL(_) {
                    do {
                        let refreshed = try await refreshPlaybackResource(failedResource: failedResource)
                        cursor = try await consumeStream(
                            resource: refreshed,
                            start: cursor,
                            end: upperBound,
                            label: "main-refreshed",
                            generation: generation,
                            enforceGeneration: true
                        )
                    } catch {
                        DiagnosticsLogger.shared.log("DownloadFirstMain", "refresh/retry failed cursor=\(cursor): \(error.localizedDescription)")
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                } catch {
                    DiagnosticsLogger.shared.log("DownloadFirstMain", "retry failed cursor=\(cursor): \(error.localizedDescription)")
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            } catch {
                metricsValue.rangeFailureCount += 1
                DiagnosticsLogger.shared.log("DownloadFirstMain", "stream failed cursor=\(cursor): \(error.localizedDescription)")
                cursor = store.firstMissingOffset(from: cursor, upperBound: upperBound) ?? upperBound
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            mainCursor = cursor
        }

        guard generation == mainGeneration else { return }
        if restartMainForPendingDemand(reason: "post-main-finish") { return }
        DiagnosticsLogger.shared.log("DownloadFirstMain", "finished anchor=\(anchor) cursor=\(cursor) end=\(upperBound)")
    }

    private func ensureUrgentDownload(offset: Int64, resource: TransportResolvedResource, replaceExisting: Bool, reason: String) {
        guard !stopped, let store else { return }
        let start = alignedOffset(offset, contentLength: resource.contentLength)
        if !replaceExisting, isFarFromRecentSeek(offset: start, resource: resource) { return }
        let windowBytes = max(Int64(8 * 1_048_576), configuration.upstreamBlockSizeBytes)
        let end = min(resource.contentLength, start + windowBytes)
        guard end > start else { return }
        let range = start..<end
        if store.contains(range) { return }

        if let urgentRange, urgentTask != nil {
            if urgentRange.contains(offset) { return }
            if replaceExisting {
                urgentTask?.cancel()
                urgentTask = nil
                self.urgentRange = nil
                pendingUrgentOffsets.removeAll()
            } else {
                let aligned = alignedOffset(offset, contentLength: resource.contentLength)
                if !pendingUrgentOffsets.contains(where: { abs($0 - aligned) < 1_048_576 }) {
                    pendingUrgentOffsets.append(aligned)
                    DiagnosticsLogger.shared.log("DownloadFirstSeek", "queued offset=\(aligned) activeRange=\(urgentRange.lowerBound)..<\(urgentRange.upperBound) reason=\(reason)")
                }
                return
            }
        }

        urgentRange = range
        let generation = seekGeneration
        urgentTask = Task { [weak self] in
            guard let self else { return }
            await self.runUrgentDownload(range: range, generation: generation, reason: reason)
        }
    }

    private func runUrgentDownload(range: Range<Int64>, generation: Int, reason: String) async {
        guard let store else { return }
        var cursor = store.firstMissingOffset(from: range.lowerBound, upperBound: range.upperBound) ?? range.upperBound
        DiagnosticsLogger.shared.log("DownloadFirstSeek", "start range=\(range.lowerBound)..<\(range.upperBound) cursor=\(cursor) generation=\(generation) reason=\(reason)")

        while !Task.isCancelled, !stopped, cursor < range.upperBound {
            let failedResource: TransportResolvedResource
            do {
                failedResource = try await resolve()
            } catch {
                DiagnosticsLogger.shared.log("DownloadFirstSeek", "resolve failed: \(error.localizedDescription)")
                break
            }

            do {
                cursor = try await consumeStream(
                    resource: failedResource,
                    start: cursor,
                    end: range.upperBound,
                    label: "seek",
                    generation: generation,
                    enforceGeneration: false
                )
            } catch is CancellationError {
                break
            } catch MediaTransportError.expiredURL(_) {
                metricsValue.rangeFailureCount += 1
                do {
                    let refreshed = try await refreshPlaybackResource(failedResource: failedResource)
                    cursor = try await consumeStream(
                        resource: refreshed,
                        start: cursor,
                        end: range.upperBound,
                        label: "seek-refreshed",
                        generation: generation,
                        enforceGeneration: false
                    )
                } catch {
                    DiagnosticsLogger.shared.log("DownloadFirstSeek", "refresh failed cursor=\(cursor): \(error.localizedDescription)")
                    break
                }
            } catch {
                metricsValue.rangeFailureCount += 1
                DiagnosticsLogger.shared.log("DownloadFirstSeek", "failed cursor=\(cursor): \(error.localizedDescription)")
                cursor = store.firstMissingOffset(from: cursor, upperBound: range.upperBound) ?? range.upperBound
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }

        if urgentRange == range {
            urgentRange = nil
            urgentTask = nil
        }
        DiagnosticsLogger.shared.log("DownloadFirstSeek", "finished range=\(range.lowerBound)..<\(range.upperBound) cursor=\(cursor)")
        startNextQueuedUrgentIfNeeded()
    }

    private func startNextQueuedUrgentIfNeeded() {
        guard urgentTask == nil, !pendingUrgentOffsets.isEmpty, let resource else { return }
        let next = pendingUrgentOffsets.removeFirst()
        ensureUrgentDownload(offset: next, resource: resource, replaceExisting: false, reason: "queued-real-demand")
    }

    private func consumeStream(
        resource: TransportResolvedResource,
        start: Int64,
        end: Int64,
        label: String,
        generation: Int,
        enforceGeneration: Bool
    ) async throws -> Int64 {
        guard let store, end > start else { return start }
        let rangeHeader = "bytes=\(start)-\(end - 1)"
        let loader = DownloadFirstStreamLoader(
            resource: resource,
            rangeHeader: rangeHeader,
            expectedLength: end - start,
            label: label
        )
        let stream = loader.makeStream()
        var cursor = start
        metricsValue.activeRequestCount += 1
        metricsValue.networkRequestCount += 1
        defer { metricsValue.activeRequestCount = max(0, metricsValue.activeRequestCount - 1) }

        do {
            for try await chunk in stream {
                try Task.checkCancellation()
                guard !stopped else { throw CancellationError() }
                if enforceGeneration, generation != mainGeneration { throw CancellationError() }
                try store.write(chunk, at: cursor)
                cursor += Int64(chunk.count)
                metricsValue.bytesDownloaded += Int64(chunk.count)
                metricsValue.elapsedSeconds = Date().timeIntervalSince(createdAt)
                recordDownload(bytes: Int64(chunk.count))
                if enforceGeneration {
                    mainCursor = cursor
                    recordMainDownload(bytes: Int64(chunk.count))
                    evaluateMainConnectionHealth(resource: resource, upperBound: end, generation: generation)
                }
                logProgressIfNeeded()
            }
            return cursor
        } catch {
            return try handlePartialStreamError(error, cursor: cursor, expectedEnd: end)
        }
    }

    private func handlePartialStreamError(_ error: Error, cursor: Int64, expectedEnd: Int64) throws -> Int64 {
        if error is CancellationError { throw CancellationError() }
        if let transportError = error as? MediaTransportError, case .shortRead = transportError, cursor < expectedEnd {
            DiagnosticsLogger.shared.log("DownloadFirstNet", "short read accepted cursor=\(cursor) expectedEnd=\(expectedEnd); continuing from received offset")
            return cursor
        }
        throw error
    }

    private func recordDemand(offset: Int64, length: Int64, blocked: Bool) {
        let now = Date()
        lastDemandOffset = offset
        lastDemandAt = now
        if blocked { lastBlockedDemandOffset = offset }
        demandSamples.append(DemandSample(date: now, offset: offset, length: length, blocked: blocked))
        demandSamples.removeAll { now.timeIntervalSince($0.date) > 1.5 }
    }

    private func scheduleMainMigrationFromActualDemand(to offset: Int64, resource: TransportResolvedResource, reason: String) {
        let target = alignedOffset(offset, contentLength: resource.contentLength)
        let distance = abs(target - mainCursor)
        guard !mainRunning || distance > 32 * 1_048_576 else { return }
        let now = Date()
        let seekAge = now.timeIntervalSince(lastSeekHintAt)
        guard seekAge >= 4 else { return }
        if seekAge < 10, let lastSeekHintOffset {
            guard abs(target - lastSeekHintOffset) <= 96 * 1_048_576 else { return }
        }
        guard !mainRunning || now.timeIntervalSince(lastMainMigrationAt) >= 2 else { return }

        demandGeneration += 1
        let generation = demandGeneration
        migrationTask?.cancel()
        migrationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard let self, !Task.isCancelled else { return }
            await self.commitActualDemandMigration(fallbackTarget: target, generation: generation, reason: reason)
        }
    }

    private func commitActualDemandMigration(fallbackTarget: Int64, generation: Int, reason: String) {
        guard !stopped, generation == demandGeneration, let resource, let store else { return }
        let now = Date()
        let recentBlocked = demandSamples.filter { $0.blocked && now.timeIntervalSince($0.date) <= 0.75 }
        let primaryRanges = recentBlocked.filter { $0.length >= 4 * 1_048_576 }
        let selected = primaryRanges.last?.offset ?? recentBlocked.last?.offset ?? fallbackTarget
        let target = alignedOffset(selected, contentLength: resource.contentLength)
        if now.timeIntervalSince(lastSeekHintAt) < 10, let lastSeekHintOffset {
            guard abs(target - lastSeekHintOffset) <= 96 * 1_048_576 else { return }
        }
        let available = store.availableLength(from: target, maximumLength: 2 * 1_048_576)
        guard available < 2 * 1_048_576 else { return }
        guard !mainRunning || now.timeIntervalSince(lastMainMigrationAt) >= 2 else { return }

        let previousAnchor = mainAnchor
        startMainDownloader(anchor: target, reason: "real-demand-\(reason)")
        lastMainMigrationAt = now
        DiagnosticsLogger.shared.log(
            "DownloadFirstMain",
            "migrated-real-range from=\(previousAnchor) to=\(target) selected=\(selected) generation=\(generation)"
        )
    }

    private func forceDemandRecovery(offset: Int64, resource: TransportResolvedResource, reason: String) {
        let target = alignedOffset(offset, contentLength: resource.contentLength)
        guard !isFarFromRecentSeek(offset: target, resource: resource) else { return }
        ensureUrgentDownload(offset: target, resource: resource, replaceExisting: false, reason: reason)

        let farFromMain = abs(target - mainCursor) > 32 * 1_048_576
        let mainAtEnd = mainCursor >= mainUpperBound || mainCursor >= resource.contentLength
        if !mainRunning || farFromMain || mainAtEnd {
            let previous = mainAnchor
            startMainDownloader(anchor: target, reason: reason)
            DiagnosticsLogger.shared.log("DownloadFirstMain", "forced-demand-migration from=\(previous) to=\(target) reason=\(reason)")
        }
    }

    private func restartMainForPendingDemand(reason: String) -> Bool {
        guard let store, let resource else { return false }
        let now = Date()
        let candidates = demandSamples
            .filter { $0.blocked && now.timeIntervalSince($0.date) <= 10 }
            .map(\.offset)
        let recentFallback: Int64? = now.timeIntervalSince(lastDemandAt) <= 10 ? (lastDemandOffset ?? lastBlockedDemandOffset) : nil
        let preferred = candidates.last ?? recentFallback
        guard let preferred else { return false }

        let lower = alignedOffset(preferred, contentLength: resource.contentLength)
        let upper = min(resource.contentLength, lower + 64 * 1_048_576)
        guard let missing = store.firstMissingOffset(from: lower, upperBound: upper) else { return false }

        DiagnosticsLogger.shared.log(
            "DownloadFirstGap",
            "main reached end but demand gap remains demand=\(preferred) missing=\(missing) upper=\(upper); restarting"
        )
        startMainDownloader(anchor: missing, reason: reason)
        return true
    }

    private func recordMainDownload(bytes: Int64) {
        let now = Date()
        mainSpeedSamples.append(SpeedSample(date: now, bytes: bytes))
        mainSpeedSamples.removeAll { now.timeIntervalSince($0.date) > 4 }
        guard let first = mainSpeedSamples.first else {
            currentMainBytesPerSecond = 0
            return
        }
        let total = mainSpeedSamples.reduce(Int64(0)) { $0 + $1.bytes }
        currentMainBytesPerSecond = Double(total) / max(now.timeIntervalSince(first.date), 0.5)
    }

    private func evaluateMainConnectionHealth(resource: TransportResolvedResource, upperBound: Int64, generation: Int) {
        guard generation == mainGeneration, mainRunning, laneProbeTask == nil else { return }
        guard !resource.looksLike115CDN, urgentTask == nil, metricsValue.activeRequestCount <= 1 else { return }
        let now = Date()
        guard now >= laneProbeCooldownUntil, now.timeIntervalSince(mainStartedAt) >= 5 else { return }
        guard currentMainBytesPerSecond > 0, currentMainBytesPerSecond < 6 * 1_048_576 else { return }
        guard let store else { return }

        let probeStart = store.firstMissingOffset(from: mainCursor, upperBound: upperBound) ?? mainCursor
        let probeEnd = min(upperBound, probeStart + 4 * 1_048_576)
        guard probeEnd > probeStart else { return }
        let baseline = currentMainBytesPerSecond
        laneProbeCooldownUntil = now.addingTimeInterval(15)
        laneProbeTask = Task { [weak self] in
            guard let self else { return }
            await self.runLaneProbe(resource: resource, range: probeStart..<probeEnd, baseline: baseline, mainGeneration: generation)
        }
    }

    private func runLaneProbe(resource: TransportResolvedResource, range: Range<Int64>, baseline: Double, mainGeneration: Int) async {
        guard let store else { return }
        let started = Date()
        let loader = DownloadFirstStreamLoader(
            resource: resource,
            rangeHeader: "bytes=\(range.lowerBound)-\(range.upperBound - 1)",
            expectedLength: range.upperBound - range.lowerBound,
            label: "lane-probe"
        )
        let stream = loader.makeStream()
        var cursor = range.lowerBound
        var received: Int64 = 0
        metricsValue.activeRequestCount += 1
        metricsValue.networkRequestCount += 1

        do {
            for try await chunk in stream {
                try Task.checkCancellation()
                try store.write(chunk, at: cursor)
                cursor += Int64(chunk.count)
                received += Int64(chunk.count)
                metricsValue.bytesDownloaded += Int64(chunk.count)
                recordDownload(bytes: Int64(chunk.count))
            }
        } catch {
            DiagnosticsLogger.shared.log("DownloadFirstLane", "probe failed range=\(range.lowerBound)..<\(range.upperBound): \(error.localizedDescription)")
        }

        metricsValue.activeRequestCount = max(0, metricsValue.activeRequestCount - 1)
        laneProbeTask = nil
        let elapsed = max(Date().timeIntervalSince(started), 0.001)
        let candidate = Double(received) / elapsed
        guard !stopped, mainGeneration == self.mainGeneration, received >= 2 * 1_048_576 else { return }

        let winningThreshold = max(6 * 1_048_576, baseline * 1.35)
        if candidate >= winningThreshold {
            DiagnosticsLogger.shared.log(
                "DownloadFirstLane",
                "switch slow lane baselineBps=\(Int(baseline)) candidateBps=\(Int(candidate)) probeBytes=\(received) range=\(range.lowerBound)..<\(range.upperBound)"
            )
            startMainDownloader(anchor: range.lowerBound, reason: "slow-lane-switch")
        } else {
            DiagnosticsLogger.shared.log(
                "DownloadFirstLane",
                "keep lane baselineBps=\(Int(baseline)) candidateBps=\(Int(candidate)) probeBytes=\(received)"
            )
        }
    }

    private func refreshPlaybackResource(failedResource: TransportResolvedResource) async throws -> TransportResolvedResource {
        if let current = resource, current.finalURL != failedResource.finalURL { return current }
        if let refreshTask {
            DiagnosticsLogger.shared.log("DownloadFirstRefresh", "joining in-flight PlaybackInfo refresh")
            return (try await refreshTask.value).resource
        }

        let sourceSnapshot = source
        let client = client
        let resolver = resolver
        let task = Task<RefreshResult, Error> {
            let playback = try await client.playbackInfo(itemId: sourceSnapshot.itemId)
            guard let mediaSource = playback.mediaSources.first(where: { $0.id == sourceSnapshot.mediaSource.id }) ?? playback.mediaSources.first else {
                throw MediaTransportError.invalidResponse
            }
            let refreshedSource = try client.resolvePlaybackSource(
                itemId: sourceSnapshot.itemId,
                itemName: sourceSnapshot.itemName,
                mediaSource: mediaSource,
                playSessionId: playback.playSessionId
            )
            let refreshedResource = try await resolver.resolve(source: refreshedSource)
            guard refreshedResource.supportsByteRanges else { throw MediaTransportError.rangeUnsupported(statusCode: 200) }
            return RefreshResult(source: refreshedSource, resource: refreshedResource)
        }
        refreshTask = task
        DiagnosticsLogger.shared.log("DownloadFirstRefresh", "single-flight PlaybackInfo refresh started")

        do {
            let result = try await task.value
            refreshTask = nil
            if resource == nil || resource?.finalURL == failedResource.finalURL {
                source = result.source
                resource = result.resource
            }
            DiagnosticsLogger.shared.log("DownloadFirstRefresh", "single-flight PlaybackInfo refresh completed")
            return resource ?? result.resource
        } catch {
            refreshTask = nil
            throw error
        }
    }

    private func alignedOffset(_ offset: Int64, contentLength: Int64) -> Int64 {
        let alignment = max(Int64(1_048_576), configuration.segmentSizeBytes)
        return min(max(0, (offset / alignment) * alignment), max(0, contentLength - 1))
    }

    private func scheduleMainMigrationAfterStableSeek(hintOffset: Int64, resource: TransportResolvedResource, generation: Int) {
        seekMigrationTask?.cancel()
        seekMigrationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard let self, !Task.isCancelled else { return }
            await self.commitStableSeekMigration(hintOffset: hintOffset, resource: resource, generation: generation)
        }
    }

    private func commitStableSeekMigration(hintOffset: Int64, resource: TransportResolvedResource, generation: Int) {
        seekMigrationTask = nil
        guard !stopped, generation == seekGeneration, let store else { return }
        let urgentWindow = max(Int64(8 * 1_048_576), configuration.upstreamBlockSizeBytes)
        let continuationOffset = min(resource.contentLength - 1, hintOffset + urgentWindow)
        let target = alignedOffset(continuationOffset, contentLength: resource.contentLength)
        let available = store.availableLength(from: target, maximumLength: 4 * 1_048_576)
        guard available < 4 * 1_048_576 else { return }
        guard !mainRunning || abs(target - mainCursor) > 32 * 1_048_576 else { return }

        let previous = mainAnchor
        startMainDownloader(anchor: target, reason: "stable-seek")
        lastMainMigrationAt = Date()
        DiagnosticsLogger.shared.log(
            "DownloadFirstMain",
            "migrated-stable-seek from=\(previous) hint=\(hintOffset) to=\(target) generation=\(generation)"
        )
    }

    private func isMetadataProbe(offset: Int64, length: Int, contentLength: Int64) -> Bool {
        if length <= 128 * 1024 { return true }
        guard length < 1_048_576 else { return false }
        return offset < 4 * 1_048_576 || offset >= max(0, contentLength - 4 * 1_048_576)
    }

    private func isFarFromRecentSeek(offset: Int64, resource: TransportResolvedResource) -> Bool {
        guard Date().timeIntervalSince(lastSeekHintAt) < 10, let lastSeekHintOffset else { return false }
        let tolerance = min(Int64(256 * 1_048_576), max(Int64(96 * 1_048_576), resource.contentLength / 10))
        return abs(offset - lastSeekHintOffset) > tolerance
    }

    private func recordDownload(bytes: Int64) {
        let now = Date()
        speedSamples.append(SpeedSample(date: now, bytes: bytes))
        updateCurrentSpeed(now: now)
    }

    private func updateCurrentSpeed(now: Date) {
        speedSamples.removeAll { now.timeIntervalSince($0.date) > 5 }
        guard let first = speedSamples.first else {
            metricsValue.currentDownloadBytesPerSecond = 0
            return
        }
        let bytes = speedSamples.reduce(Int64(0)) { $0 + $1.bytes }
        let elapsed = max(now.timeIntervalSince(first.date), 0.5)
        metricsValue.currentDownloadBytesPerSecond = Double(bytes) / elapsed
    }

    private func logProgressIfNeeded() {
        let megabytes = metricsValue.bytesDownloaded / 1_048_576
        guard megabytes >= lastLoggedMegabytes + 64 else { return }
        lastLoggedMegabytes = megabytes
        let demand = lastDemandOffset ?? lastBlockedDemandOffset ?? 0
        let contiguous = store?.availableLength(from: demand, maximumLength: resource?.contentLength ?? Int64.max) ?? 0
        DiagnosticsLogger.shared.log(
            "DownloadFirstSpeed",
            "downloaded=\(metricsValue.bytesDownloaded) currentBps=\(Int(metricsValue.currentDownloadBytesPerSecond)) mainBps=\(Int(currentMainBytesPerSecond)) averageBps=\(Int(metricsValue.averageDownloadBytesPerSecond)) active=\(metricsValue.activeRequestCount) unique=\(store?.uniqueBytes ?? 0) contiguous=\(contiguous) demand=\(demand) mainCursor=\(mainCursor)"
        )
    }
}
