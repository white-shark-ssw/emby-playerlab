import Foundation

actor MediaTransportSession {
    private struct MemoryEntry {
        let data: Data
        var lastAccess: Date
    }

    private struct InFlightEntry {
        let task: Task<Data, Error>
        var preloadOnly: Bool
    }

    private struct SegmentValue {
        let data: Data
        let cacheHit: Bool
    }

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
    private let httpClient: RangeHTTPClient
    private let diskCache: TransportDiskCache

    private var resource: TransportResolvedResource?
    private var resolveTask: Task<TransportResolvedResource, Error>?
    private var refreshTask: Task<RefreshResult, Error>?
    private var memoryEntries: [Int64: MemoryEntry] = [:]
    private var memoryBytes: Int64 = 0
    private var inFlight: [Int64: InFlightEntry] = [:]
    private var preloadTask: Task<Void, Never>?
    private var initialPreloadTask: Task<Void, Never>?
    private var initialPreloadScheduled = false
    private var preloadAnchor: Int64?
    private var preloadWindow: Range<Int64>?
    private var metricsValue = TransportMetricsSnapshot()
    private var speedSamples: [SpeedSample] = []
    private let createdAt = Date()
    private var lastLoggedMegabytes: Int64 = 0
    private var stopped = false

    init(source: ResolvedPlaybackSource, client: EmbyAPIClient, configuration: MediaTransportConfiguration) {
        self.source = source
        self.client = client
        self.configuration = configuration
        self.httpClient = RangeHTTPClient(maximumConnections: min(configuration.maximumConcurrentRequests + 1, 8))
        self.diskCache = TransportDiskCache(
            cacheKey: "\(source.itemId)-\(source.mediaSource.id)",
            limitBytes: configuration.usesDiskCache ? configuration.diskLimitBytes : 0,
            keepFiles: configuration.keepLastCache
        )
    }

    func resolve() async throws -> TransportResolvedResource {
        if let resource { return resource }
        if let resolveTask { return try await resolveTask.value }

        let sourceSnapshot = source
        let resolver = resolver
        let task = Task<TransportResolvedResource, Error> {
            try await resolver.resolve(source: sourceSnapshot)
        }
        resolveTask = task

        do {
            let resolved = try await task.value
            resolveTask = nil
            guard resolved.supportsByteRanges else {
                throw MediaTransportError.rangeUnsupported(statusCode: 200)
            }
            if resource == nil {
                resource = resolved
                await diskCache.validate(
                    contentLength: resolved.contentLength,
                    etag: resolved.etag,
                    lastModified: resolved.lastModified
                )
                DiagnosticsLogger.shared.log(
                    "TransportSession",
                    "ready item=\(source.itemId) bytes=\(resolved.contentLength) segment=\(configuration.segmentSizeBytes) concurrent=\(configuration.maximumConcurrentRequests) mode=\(configuration.cacheMode.rawValue)"
                )
            }
            return resource ?? resolved
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

        let upperBound = min(resource.contentLength, offset + Int64(length))
        let segmentSize = max(1, configuration.segmentSizeBytes)
        let firstStart = (offset / segmentSize) * segmentSize
        let lastStart = ((upperBound - 1) / segmentSize) * segmentSize
        var starts: [Int64] = []
        var current = firstStart
        while current <= lastStart {
            starts.append(current)
            current += segmentSize
        }

        var segments: [Int64: SegmentValue] = [:]
        try await withThrowingTaskGroup(of: (Int64, SegmentValue).self) { group in
            for start in starts {
                group.addTask { [weak self] in
                    guard let self else { throw MediaTransportError.cancelled }
                    return (start, try await self.segment(start: start, preload: false))
                }
            }
            for try await (start, value) in group {
                segments[start] = value
            }
        }

        var output = Data(capacity: Int(upperBound - offset))
        var cacheHitBytes: Int64 = 0
        var cursor = offset
        while cursor < upperBound {
            let start = (cursor / segmentSize) * segmentSize
            guard let segment = segments[start] else { throw MediaTransportError.invalidResponse }
            let lower = Int(cursor - start)
            let available = min(segment.data.count - lower, Int(upperBound - cursor))
            guard available > 0 else { throw MediaTransportError.invalidResponse }
            output.append(segment.data.subdata(in: lower..<(lower + available)))
            if segment.cacheHit { cacheHitBytes += Int64(available) }
            cursor += Int64(available)
        }

        metricsValue.bytesServed += Int64(output.count)
        metricsValue.cacheHitBytes += cacheHitBytes
        metricsValue.elapsedSeconds = Date().timeIntervalSince(createdAt)

        if output.count >= 64 * 1024 {
            scheduleInitialPreload(resource: resource)
            schedulePreload(after: upperBound, resource: resource)
        }
        return output
    }

    func prioritizeSeek(position: Double, duration: Double) async {
        guard !stopped, position.isFinite, duration.isFinite, duration > 0 else { return }
        guard let resource = try? await resolve() else { return }

        let ratio = min(max(position / duration, 0), 1)
        let approximateOffset = Int64(Double(resource.contentLength) * ratio)
        let segmentSize = max(1, configuration.segmentSizeBytes)
        let alignedOffset = min(
            max(0, (approximateOffset / segmentSize) * segmentSize),
            max(0, resource.contentLength - segmentSize)
        )

        preloadTask?.cancel()
        preloadTask = nil
        initialPreloadTask?.cancel()
        initialPreloadTask = nil
        cancelPreloadNetworkTasks()
        preloadAnchor = nil
        preloadWindow = nil

        DiagnosticsLogger.shared.log(
            "TransportPriority",
            "seek position=\(position) duration=\(duration) approximateOffset=\(alignedOffset)"
        )
        schedulePreload(after: alignedOffset, resource: resource)
    }

    func metrics() async -> TransportMetricsSnapshot {
        var value = metricsValue
        let now = Date()
        value.elapsedSeconds = now.timeIntervalSince(createdAt)
        updateCurrentSpeed(now: now)
        value.currentDownloadBytesPerSecond = metricsValue.currentDownloadBytesPerSecond

        let diskBytes = await diskCache.size()
        value.memoryCacheBytes = memoryBytes
        value.diskCacheBytes = diskBytes
        if configuration.usesDiskCache {
            value.cacheBytes = max(memoryBytes, diskBytes)
        } else {
            value.cacheBytes = memoryBytes
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
        preloadTask?.cancel()
        preloadTask = nil
        initialPreloadTask?.cancel()
        initialPreloadTask = nil
        preloadAnchor = nil
        preloadWindow = nil
        inFlight.values.forEach { $0.task.cancel() }
        inFlight.removeAll()
        let finalMetrics = await metrics()
        DiagnosticsLogger.shared.log("TransportSession", "stopped \(finalMetrics.summary)")
        memoryEntries.removeAll()
        memoryBytes = 0
        await diskCache.close()
    }

    private func segment(start: Int64, preload: Bool) async throws -> SegmentValue {
        if let memory = memoryEntries[start] {
            memoryEntries[start] = MemoryEntry(data: memory.data, lastAccess: Date())
            return SegmentValue(data: memory.data, cacheHit: true)
        }

        if configuration.usesDiskCache, let diskData = await diskCache.read(start: start) {
            insertMemory(diskData, start: start)
            return SegmentValue(data: diskData, cacheHit: true)
        }

        if var entry = inFlight[start] {
            if !preload, entry.preloadOnly {
                entry.preloadOnly = false
                inFlight[start] = entry
            }
            return SegmentValue(data: try await entry.task.value, cacheHit: false)
        }

        let task = Task<Data, Error> { [weak self] in
            guard let self else { throw MediaTransportError.cancelled }
            return try await self.downloadSegment(start: start, allowRefresh: true)
        }
        inFlight[start] = InFlightEntry(task: task, preloadOnly: preload)

        do {
            let data = try await task.value
            inFlight[start] = nil
            insertMemory(data, start: start)
            if configuration.usesDiskCache {
                await diskCache.write(data, start: start)
            }
            return SegmentValue(data: data, cacheHit: false)
        } catch {
            inFlight[start] = nil
            metricsValue.rangeFailureCount += 1
            throw error
        }
    }

    private func downloadSegment(start: Int64, allowRefresh: Bool) async throws -> Data {
        let failedResource = try await resolve()
        let end = min(failedResource.contentLength, start + configuration.segmentSizeBytes)
        guard end > start else { return Data() }

        do {
            return try await fetch(resource: failedResource, range: start..<end)
        } catch MediaTransportError.expiredURL(_) where allowRefresh {
            DiagnosticsLogger.shared.log(
                "TransportRetry",
                "status=403/410 start=\(start) retrying current 115 URL before refresh"
            )
            try? await Task.sleep(nanoseconds: 250_000_000)

            if let current = resource, current.finalURL != failedResource.finalURL {
                return try await fetch(resource: current, range: start..<end)
            }

            do {
                return try await fetch(resource: failedResource, range: start..<end)
            } catch MediaTransportError.expiredURL(_) {
                let refreshed = try await refreshPlaybackResource(failedResource: failedResource)
                return try await fetch(resource: refreshed, range: start..<end)
            }
        }
    }

    private func fetch(resource: TransportResolvedResource, range: Range<Int64>) async throws -> Data {
        metricsValue.activeRequestCount += 1
        metricsValue.networkRequestCount += 1
        defer { metricsValue.activeRequestCount = max(0, metricsValue.activeRequestCount - 1) }

        let data = try await httpClient.fetch(resource: resource, range: range)
        metricsValue.bytesDownloaded += Int64(data.count)
        metricsValue.elapsedSeconds = Date().timeIntervalSince(createdAt)
        recordDownload(bytes: Int64(data.count))
        logProgressIfNeeded()
        return data
    }

    private func refreshPlaybackResource(failedResource: TransportResolvedResource) async throws -> TransportResolvedResource {
        if let current = resource, current.finalURL != failedResource.finalURL {
            DiagnosticsLogger.shared.log("TransportRefresh", "using newer resolved URL; duplicate refresh skipped")
            return current
        }

        if let refreshTask {
            DiagnosticsLogger.shared.log("TransportRefresh", "joining in-flight PlaybackInfo refresh")
            return (try await refreshTask.value).resource
        }

        let sourceSnapshot = source
        let client = client
        let resolver = resolver
        let task = Task<RefreshResult, Error> {
            let playback = try await client.playbackInfo(itemId: sourceSnapshot.itemId)
            guard let mediaSource = playback.mediaSources.first(where: { $0.id == sourceSnapshot.mediaSource.id })
                    ?? playback.mediaSources.first else {
                throw MediaTransportError.invalidResponse
            }
            let refreshedSource = try client.resolvePlaybackSource(
                itemId: sourceSnapshot.itemId,
                itemName: sourceSnapshot.itemName,
                mediaSource: mediaSource,
                playSessionId: playback.playSessionId
            )
            let refreshedResource = try await resolver.resolve(source: refreshedSource)
            guard refreshedResource.supportsByteRanges else {
                throw MediaTransportError.rangeUnsupported(statusCode: 200)
            }
            return RefreshResult(source: refreshedSource, resource: refreshedResource)
        }
        refreshTask = task
        DiagnosticsLogger.shared.log("TransportRefresh", "single-flight PlaybackInfo refresh started")

        do {
            let result = try await task.value
            refreshTask = nil
            if resource == nil || resource?.finalURL == failedResource.finalURL {
                source = result.source
                resource = result.resource
                await diskCache.validate(
                    contentLength: result.resource.contentLength,
                    etag: result.resource.etag,
                    lastModified: result.resource.lastModified
                )
            }
            DiagnosticsLogger.shared.log("TransportRefresh", "single-flight PlaybackInfo refresh completed")
            return resource ?? result.resource
        } catch {
            refreshTask = nil
            throw error
        }
    }

    private func insertMemory(_ data: Data, start: Int64) {
        guard configuration.usesMemoryCache, configuration.memoryLimitBytes > 0 else { return }
        if let existing = memoryEntries[start] {
            memoryBytes = max(0, memoryBytes - Int64(existing.data.count))
        }
        memoryEntries[start] = MemoryEntry(data: data, lastAccess: Date())
        memoryBytes += Int64(data.count)
        evictMemoryIfNeeded()
    }

    private func evictMemoryIfNeeded() {
        guard memoryBytes > configuration.memoryLimitBytes else { return }
        let sorted = memoryEntries.sorted { $0.value.lastAccess < $1.value.lastAccess }
        for (start, entry) in sorted where memoryBytes > configuration.memoryLimitBytes {
            memoryEntries[start] = nil
            memoryBytes = max(0, memoryBytes - Int64(entry.data.count))
        }
    }

    private func scheduleInitialPreload(resource: TransportResolvedResource) {
        guard !initialPreloadScheduled, configuration.cacheMode != .disabled else { return }
        initialPreloadScheduled = true

        let segmentSize = max(1, configuration.segmentSizeBytes)
        let tailStart = ((max(0, resource.contentLength - 1)) / segmentSize) * segmentSize
        guard tailStart > 0 else { return }

        DiagnosticsLogger.shared.log("TransportPrime", "tail metadata preload start=\(tailStart)")
        initialPreloadTask = Task { [weak self] in
            guard let self else { return }
            _ = try? await self.segment(start: tailStart, preload: true)
            await self.finishInitialPreload()
        }
    }

    private func finishInitialPreload() {
        initialPreloadTask = nil
        DiagnosticsLogger.shared.log("TransportPrime", "tail metadata preload finished")
    }

    private func schedulePreload(after offset: Int64, resource: TransportResolvedResource) {
        guard configuration.cacheMode != .disabled else { return }
        let preloadLimit = NetworkPathMonitor.shared.isCellular
            ? configuration.cellularPreloadBytes
            : configuration.wifiPreloadBytes
        guard preloadLimit > 0 else { return }

        if let preloadWindow, preloadWindow.contains(offset) {
            return
        }

        preloadTask?.cancel()
        cancelPreloadNetworkTasks()

        let start = min(max(0, offset), resource.contentLength)
        let end = min(resource.contentLength, start + preloadLimit)
        guard end > start else { return }

        preloadAnchor = start
        preloadWindow = start..<end
        DiagnosticsLogger.shared.log(
            "TransportPreload",
            "window start=\(start) end=\(end) backgroundConcurrent=\(max(1, configuration.maximumConcurrentRequests - 1))"
        )
        preloadTask = Task { [weak self] in
            guard let self else { return }
            await self.preload(from: start, maximumBytes: end - start)
            await self.finishPreload(anchor: start)
        }
    }

    private func finishPreload(anchor: Int64) {
        guard preloadAnchor == anchor else { return }
        preloadTask = nil
    }

    private func preload(from offset: Int64, maximumBytes: Int64) async {
        guard !Task.isCancelled, !stopped else { return }
        guard let resource = try? await resolve() else { return }
        let segmentSize = configuration.segmentSizeBytes
        var next = (offset / segmentSize) * segmentSize
        if next < offset { next += segmentSize }
        let finalOffset = min(resource.contentLength, next + maximumBytes)
        let concurrency = max(1, configuration.maximumConcurrentRequests - 1)

        while next < finalOffset, !Task.isCancelled, !stopped {
            var batch: [Int64] = []
            for _ in 0..<concurrency where next < finalOffset {
                batch.append(next)
                next += segmentSize
            }
            await withTaskGroup(of: Void.self) { group in
                for start in batch {
                    group.addTask { [weak self] in
                        guard let self else { return }
                        _ = try? await self.segment(start: start, preload: true)
                    }
                }
            }
        }
    }

    private func cancelPreloadNetworkTasks() {
        let starts = inFlight.compactMap { start, entry in
            entry.preloadOnly ? start : nil
        }
        for start in starts {
            inFlight[start]?.task.cancel()
            inFlight[start] = nil
        }
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
        let total = speedSamples.reduce(Int64(0)) { $0 + $1.bytes }
        let elapsed = max(now.timeIntervalSince(first.date), 0.5)
        metricsValue.currentDownloadBytesPerSecond = Double(total) / elapsed
    }

    private func logProgressIfNeeded() {
        let downloadedMB = metricsValue.bytesDownloaded / 1_048_576
        guard downloadedMB >= lastLoggedMegabytes + 16 else { return }
        lastLoggedMegabytes = downloadedMB
        let elapsed = max(Date().timeIntervalSince(createdAt), 0.001)
        let average = Double(metricsValue.bytesDownloaded) / elapsed
        DiagnosticsLogger.shared.log(
            "TransportSpeed",
            "downloaded=\(metricsValue.bytesDownloaded) elapsed=\(elapsed) currentBps=\(Int(metricsValue.currentDownloadBytesPerSecond)) averageBps=\(Int(average)) requests=\(metricsValue.networkRequestCount)"
        )
    }
}
