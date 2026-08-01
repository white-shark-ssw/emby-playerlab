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

    private var source: ResolvedPlaybackSource
    private let client: EmbyAPIClient
    private let configuration: MediaTransportConfiguration
    private let resolver = RedirectResolver()
    private let httpClient: RangeHTTPClient
    private let diskCache: TransportDiskCache

    private var resource: TransportResolvedResource?
    private var memoryEntries: [Int64: MemoryEntry] = [:]
    private var memoryBytes: Int64 = 0
    private var inFlight: [Int64: InFlightEntry] = [:]
    private var preloadTask: Task<Void, Never>?
    private var preloadAnchor: Int64?
    private var metricsValue = TransportMetricsSnapshot()
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
        let resolved = try await resolver.resolve(source: source)
        guard resolved.supportsByteRanges else {
            throw MediaTransportError.rangeUnsupported(statusCode: 200)
        }
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
        return resolved
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

        var segments: [Int64: Data] = [:]
        try await withThrowingTaskGroup(of: (Int64, Data).self) { group in
            for start in starts {
                group.addTask { [weak self] in
                    guard let self else { throw MediaTransportError.cancelled }
                    return (start, try await self.segment(start: start, preload: false))
                }
            }
            for try await (start, data) in group {
                segments[start] = data
            }
        }

        var output = Data(capacity: Int(upperBound - offset))
        var cursor = offset
        while cursor < upperBound {
            let start = (cursor / segmentSize) * segmentSize
            guard let data = segments[start] else { throw MediaTransportError.invalidResponse }
            let lower = Int(cursor - start)
            let available = min(data.count - lower, Int(upperBound - cursor))
            guard available > 0 else { throw MediaTransportError.invalidResponse }
            output.append(data.subdata(in: lower..<(lower + available)))
            cursor += Int64(available)
        }

        metricsValue.bytesServed += Int64(output.count)
        metricsValue.elapsedSeconds = Date().timeIntervalSince(createdAt)
        if output.count >= 64 * 1024 {
            schedulePreload(after: upperBound)
        }
        return output
    }

    func metrics() async -> TransportMetricsSnapshot {
        var value = metricsValue
        value.elapsedSeconds = Date().timeIntervalSince(createdAt)
        let diskBytes = await diskCache.size()
        value.cacheBytes = memoryBytes + diskBytes
        return value
    }

    func stop() async {
        guard !stopped else { return }
        stopped = true
        preloadTask?.cancel()
        preloadTask = nil
        preloadAnchor = nil
        inFlight.values.forEach { $0.task.cancel() }
        inFlight.removeAll()
        memoryEntries.removeAll()
        memoryBytes = 0
        await diskCache.close()
        let finalMetrics = await metrics()
        DiagnosticsLogger.shared.log("TransportSession", "stopped \(finalMetrics.summary)")
    }

    private func segment(start: Int64, preload: Bool) async throws -> Data {
        if let memory = memoryEntries[start] {
            memoryEntries[start] = MemoryEntry(data: memory.data, lastAccess: Date())
            metricsValue.memoryHitBytes += Int64(memory.data.count)
            return memory.data
        }

        if configuration.usesDiskCache, let diskData = await diskCache.read(start: start) {
            metricsValue.diskHitBytes += Int64(diskData.count)
            insertMemory(diskData, start: start)
            return diskData
        }

        if var entry = inFlight[start] {
            if !preload, entry.preloadOnly {
                entry.preloadOnly = false
                inFlight[start] = entry
            }
            return try await entry.task.value
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
            return data
        } catch {
            inFlight[start] = nil
            metricsValue.rangeFailureCount += 1
            throw error
        }
    }

    private func downloadSegment(start: Int64, allowRefresh: Bool) async throws -> Data {
        let resource = try await resolve()
        let end = min(resource.contentLength, start + configuration.segmentSizeBytes)
        guard end > start else { return Data() }

        metricsValue.activeRequestCount += 1
        metricsValue.networkRequestCount += 1
        defer { metricsValue.activeRequestCount = max(0, metricsValue.activeRequestCount - 1) }

        do {
            let data = try await httpClient.fetch(resource: resource, range: start..<end)
            metricsValue.bytesDownloaded += Int64(data.count)
            metricsValue.elapsedSeconds = Date().timeIntervalSince(createdAt)
            logProgressIfNeeded()
            return data
        } catch MediaTransportError.expiredURL(_) where allowRefresh {
            DiagnosticsLogger.shared.log("TransportRefresh", "temporary URL expired; refreshing PlaybackInfo")
            try await refreshPlaybackResource()
            return try await downloadSegment(start: start, allowRefresh: false)
        }
    }

    private func refreshPlaybackResource() async throws {
        let playback = try await client.playbackInfo(itemId: source.itemId)
        guard let mediaSource = playback.mediaSources.first(where: { $0.id == source.mediaSource.id })
                ?? playback.mediaSources.first else {
            throw MediaTransportError.invalidResponse
        }
        source = try client.resolvePlaybackSource(
            itemId: source.itemId,
            itemName: source.itemName,
            mediaSource: mediaSource,
            playSessionId: playback.playSessionId
        )
        let refreshed = try await resolver.resolve(source: source)
        resource = refreshed
        await diskCache.validate(
            contentLength: refreshed.contentLength,
            etag: refreshed.etag,
            lastModified: refreshed.lastModified
        )
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

    private func schedulePreload(after offset: Int64) {
        guard configuration.cacheMode != .disabled else { return }
        let preloadLimit = NetworkPathMonitor.shared.isCellular
            ? configuration.cellularPreloadBytes
            : configuration.wifiPreloadBytes
        guard preloadLimit > 0 else { return }

        if let preloadAnchor,
           preloadTask != nil,
           abs(preloadAnchor - offset) <= configuration.segmentSizeBytes * 4 {
            return
        }

        preloadTask?.cancel()
        cancelPreloadNetworkTasks()
        preloadAnchor = offset
        preloadTask = Task { [weak self] in
            guard let self else { return }
            await self.preload(from: offset, maximumBytes: preloadLimit)
            await self.finishPreload(anchor: offset)
        }
    }

    private func finishPreload(anchor: Int64) {
        guard preloadAnchor == anchor else { return }
        preloadTask = nil
        preloadAnchor = nil
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

    private func logProgressIfNeeded() {
        let downloadedMB = metricsValue.bytesDownloaded / 1_048_576
        guard downloadedMB >= lastLoggedMegabytes + 16 else { return }
        lastLoggedMegabytes = downloadedMB
        let elapsed = max(Date().timeIntervalSince(createdAt), 0.001)
        let speed = Double(metricsValue.bytesDownloaded) / elapsed
        DiagnosticsLogger.shared.log(
            "TransportSpeed",
            "downloaded=\(metricsValue.bytesDownloaded) elapsed=\(elapsed) averageBps=\(Int(speed)) requests=\(metricsValue.networkRequestCount)"
        )
    }
}
