import Foundation

actor DownloadFirstMediaSession: TransportDataSession {
    private struct RefreshResult {
        let source: ResolvedPlaybackSource
        let resource: TransportResolvedResource
    }

    private struct SpeedSample {
        let date: Date
        let bytes: Int64
    }

    private var source: ResolvedPlaybackSource
    private let client: EmbyAPIClient
    private let configuration: MediaTransportConfiguration
    private let resolver = RedirectResolver()

    private var resource: TransportResolvedResource?
    private var resolveTask: Task<TransportResolvedResource, Error>?
    private var refreshTask: Task<RefreshResult, Error>?
    private var store: DownloadFirstSparseStore?
    private var mainTask: Task<Void, Never>?
    private var urgentTask: Task<Void, Never>?
    private var urgentRange: Range<Int64>?
    private var migrationTask: Task<Void, Never>?
    private var mainGeneration = 0
    private var seekGeneration = 0
    private var mainCursor: Int64 = 0
    private var mainRunning = false
    private var mainAnchor: Int64 = 0
    private var metricsValue = TransportMetricsSnapshot()
    private var speedSamples: [SpeedSample] = []
    private let createdAt = Date()
    private var lastLoggedMegabytes: Int64 = 0
    private var stopped = false

    init(source: ResolvedPlaybackSource, client: EmbyAPIClient, configuration: MediaTransportConfiguration) {
        self.source = source
        self.client = client
        self.configuration = configuration
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
                "ready item=\(source.itemId) bytes=\(resolved.contentLength) mainConnections=1 seekConnections=1 wifiPreload=\(configuration.wifiPreloadBytes) cellularPreload=\(configuration.cellularPreloadBytes) keep=\(configuration.keepLastCache)"
            )
            startMainDownloader(anchor: 0, reason: "initial")
            return resolved
        } catch {
            resolveTask = nil
            throw error
        }
    }

    func read(offset: Int64, length: Int) async throws -> Data {
        guard !stopped else { throw MediaTransportError.cancelled }
        guard length > 0 else { return Data() }
        let resource = try await resolve()
        guard offset < resource.contentLength else { return Data() }
        guard let store else { throw MediaTransportError.invalidResponse }

        let requestedLength = min(length, Int(resource.contentLength - offset))
        let availableBeforeRead = store.availableLength(from: offset, maximumLength: Int64(requestedLength))
        if availableBeforeRead == 0 {
            let mainGap = offset - mainCursor
            let mainShouldArriveSoon = mainRunning && mainGap >= 0 && mainGap <= 8 * 1_048_576
            if !mainShouldArriveSoon { ensureUrgentDownload(offset: offset, resource: resource) }
        }

        let data = try await store.readWhenAvailable(offset: offset, maximumLength: requestedLength, timeout: 30)
        metricsValue.bytesServed += Int64(data.count)
        if availableBeforeRead > 0 { metricsValue.cacheHitBytes += Int64(data.count) }
        metricsValue.elapsedSeconds = Date().timeIntervalSince(createdAt)
        return data
    }

    func prioritizeSeek(position: Double, duration: Double) async {
        guard !stopped, position.isFinite, duration.isFinite, duration > 0 else { return }
        guard let resource = try? await resolve() else { return }
        let ratio = min(max(position / duration, 0), 1)
        let approximateOffset = alignedOffset(Int64(Double(resource.contentLength) * ratio), contentLength: resource.contentLength)
        seekGeneration += 1
        DiagnosticsLogger.shared.log(
            "DownloadFirstPriority",
            "seek position=\(position) duration=\(duration) approximateOffset=\(approximateOffset) generation=\(seekGeneration)"
        )
        ensureUrgentDownload(offset: approximateOffset, resource: resource)
        scheduleMainMigration(to: approximateOffset, resource: resource)
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
        mainTask?.cancel()
        mainTask = nil
        mainRunning = false
        urgentTask?.cancel()
        urgentTask = nil
        urgentRange = nil
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
        mainRunning = true
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

        if generation == mainGeneration {
            DiagnosticsLogger.shared.log("DownloadFirstMain", "finished anchor=\(anchor) cursor=\(cursor) end=\(upperBound)")
        }
    }

    private func ensureUrgentDownload(offset: Int64, resource: TransportResolvedResource) {
        guard !stopped, let store else { return }
        let start = alignedOffset(offset, contentLength: resource.contentLength)
        let windowBytes = max(Int64(8 * 1_048_576), configuration.upstreamBlockSizeBytes)
        let end = min(resource.contentLength, start + windowBytes)
        guard end > start else { return }
        let range = start..<end
        if store.contains(range) { return }
        if let urgentRange, urgentRange.contains(offset), urgentTask != nil { return }

        urgentTask?.cancel()
        urgentRange = range
        let generation = seekGeneration
        urgentTask = Task { [weak self] in
            guard let self else { return }
            await self.runUrgentDownload(range: range, generation: generation)
        }
    }

    private func runUrgentDownload(range: Range<Int64>, generation: Int) async {
        guard let store else { return }
        var cursor = store.firstMissingOffset(from: range.lowerBound, upperBound: range.upperBound) ?? range.upperBound
        DiagnosticsLogger.shared.log("DownloadFirstSeek", "start range=\(range.lowerBound)..<\(range.upperBound) cursor=\(cursor) generation=\(generation)")

        while !Task.isCancelled, !stopped, cursor < range.upperBound {
            let failedResource: TransportResolvedResource
            do {
                failedResource = try await resolve()
            } catch {
                DiagnosticsLogger.shared.log("DownloadFirstSeek", "resolve failed: \(error.localizedDescription)")
                return
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
                return
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
                    return
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
                logProgressIfNeeded()
                if enforceGeneration { mainCursor = cursor }
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

    private func scheduleMainMigration(to offset: Int64, resource: TransportResolvedResource) {
        let target = alignedOffset(offset, contentLength: resource.contentLength)
        guard abs(target - mainCursor) > 32 * 1_048_576 else { return }
        seekGeneration += 1
        let generation = seekGeneration
        migrationTask?.cancel()
        migrationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard let self, !Task.isCancelled else { return }
            await self.commitMainMigration(target: target, generation: generation)
        }
    }

    private func commitMainMigration(target: Int64, generation: Int) {
        guard !stopped, generation == seekGeneration, let resource else { return }
        let previousAnchor = mainAnchor
        startMainDownloader(anchor: target, reason: "settled-seek")
        DiagnosticsLogger.shared.log("DownloadFirstMain", "migrated from=\(previousAnchor) to=\(target) generation=\(generation) bytes=\(resource.contentLength)")
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
        DiagnosticsLogger.shared.log(
            "DownloadFirstSpeed",
            "downloaded=\(metricsValue.bytesDownloaded) currentBps=\(Int(metricsValue.currentDownloadBytesPerSecond)) averageBps=\(Int(metricsValue.averageDownloadBytesPerSecond)) active=\(metricsValue.activeRequestCount) unique=\(store?.uniqueBytes ?? 0) mainCursor=\(mainCursor)"
        )
    }
}
