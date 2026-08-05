import Foundation

actor MediaTransportSession {
    private struct MemoryEntry {
        let data: Data
        var lastAccess: Date
    }

    private struct InFlightEntry {
        let token: UUID
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

    private struct PreloadBlockEntry {
        let token: UUID
        let range: Range<Int64>
        let task: Task<Void, Error>
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
    private var preloadBlocks: [Int64: PreloadBlockEntry] = [:]
    private var segmentWaiters: [Int64: [CheckedContinuation<Void, Never>]] = [:]
    private var preloadTask: Task<Void, Never>?
    private var initialPreloadTask: Task<Void, Never>?
    private var initialPreloadScheduled = false
    private var preloadAnchor: Int64?
    private var preloadWindow: Range<Int64>?
    private var metricsValue = TransportMetricsSnapshot()
    private var speedSamples: [SpeedSample] = []
    private let createdAt = Date()
    private var lastLoggedMegabytes: Int64 = 0
    private var cachedRanges = SparseByteRangeSet()
    private var demandOffset: Int64 = 0
    private var demandGeneration: UInt64 = 0
    private var priorityDemandUntil = Date.distantPast
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
                    "ready item=\(source.itemId) bytes=\(resolved.contentLength) segment=\(configuration.segmentSizeBytes) upstreamBlock=\(configuration.upstreamBlockSizeBytes) concurrent=\(configuration.maximumConcurrentRequests) mode=\(configuration.cacheMode.rawValue)"
                )
            }
            return resource ?? resolved
        } catch {
            resolveTask = nil
            throw error
        }
    }

    func noteDemand(range: Range<Int64>) async {
        guard !stopped, !range.isEmpty else { return }
        guard let resource = try? await resolve() else { return }
        let candidate = max(0, range.lowerBound)
        let isTailMetadataProbe = candidate >= max(0, resource.contentLength - 4 * 1_048_576)
            && range.count <= 1_048_576
        guard !isTailMetadataProbe, acceptsReadDemand(candidate) else { return }
        demandOffset = max(demandOffset, candidate)
    }

    func read(offset: Int64, length: Int) async throws -> Data {
        guard !stopped else { throw MediaTransportError.cancelled }
        guard length > 0 else { return Data() }
        let resource = try await resolve()
        guard offset < resource.contentLength else { return Data() }
        let readGeneration = demandGeneration
        let isTailMetadataProbe = offset >= max(0, resource.contentLength - 4 * 1_048_576) && length <= 1_048_576
        let drivesPlaybackWindow = !isTailMetadataProbe && acceptsReadDemand(offset)
        if drivesPlaybackWindow { demandOffset = max(demandOffset, offset) }

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
                    return (start, try await self.segment(start: start, preload: isTailMetadataProbe))
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
            let stillOwnsDemand = readGeneration == demandGeneration && acceptsReadDemand(offset)
            if drivesPlaybackWindow, stillOwnsDemand { schedulePreload(after: upperBound, resource: resource) }
        }
        return output
    }

    func prioritizeSeek(position: Double, duration: Double) async {
        guard !stopped, position.isFinite, duration.isFinite, duration > 0 else { return }
        guard let resource = try? await resolve() else { return }
        let ratio = min(max(position / duration, 0), 1)
        await prioritizeOffset(Int64(Double(resource.contentLength) * ratio))
        DiagnosticsLogger.shared.log(
            "TransportPriority",
            "seek position=\(position) duration=\(duration) approximateOffset=\(demandOffset)"
        )
    }

    func prioritizeOffset(_ offset: Int64) async {
        guard !stopped, let resource = try? await resolve() else { return }
        let segmentSize = max(1, configuration.segmentSizeBytes)
        let alignedOffset = min(
            max(0, (offset / segmentSize) * segmentSize),
            max(0, resource.contentLength - segmentSize)
        )
        demandGeneration &+= 1
        demandOffset = alignedOffset
        priorityDemandUntil = Date().addingTimeInterval(6)
        preloadTask?.cancel()
        preloadTask = nil
        initialPreloadTask?.cancel()
        initialPreloadTask = nil
        cancelPreloadNetworkTasks()
        preloadAnchor = nil
        preloadWindow = nil
        schedulePreload(after: alignedOffset, resource: resource)
        DiagnosticsLogger.shared.log("TransportPriority", "offset=\(alignedOffset) window-reset=true")
    }

    func recoverStall(position: Double, duration: Double) async {
        guard !stopped else { return }
        if duration > 0, position.isFinite {
            await prioritizeSeek(position: position, duration: duration)
        } else {
            await prioritizeOffset(demandOffset)
        }
        DiagnosticsLogger.shared.log("TransportRecovery", "position=\(position) demandOffset=\(demandOffset)")
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
            value.cacheBytes = max(cachedRanges.totalBytes, max(memoryBytes, diskBytes))
        } else {
            value.cacheBytes = max(cachedRanges.totalBytes, memoryBytes)
        }
        value.contiguousCacheBytes = cachedRanges.contiguousLength(from: demandOffset, maximumLength: Int64.max)
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
        preloadBlocks.values.forEach { $0.task.cancel() }
        preloadBlocks.removeAll()
        resumeAllSegmentWaiters()
        let finalMetrics = await metrics()
        DiagnosticsLogger.shared.log("TransportSession", "stopped \(finalMetrics.summary)")
        memoryEntries.removeAll()
        memoryBytes = 0
        cachedRanges = SparseByteRangeSet()
        await diskCache.close()
    }

    private func segment(start: Int64, preload: Bool) async throws -> SegmentValue {
        if let cached = await cachedSegment(start: start) {
            return SegmentValue(data: cached, cacheHit: true)
        }

        if !preload, preloadBlocks.values.contains(where: { $0.range.contains(start) }) {
            await waitForPreloadSegment(start: start)
            if let cached = await cachedSegment(start: start) {
                return SegmentValue(data: cached, cacheHit: true)
            }
        }

        if var entry = inFlight[start] {
            if !preload, entry.preloadOnly {
                entry.preloadOnly = false
                inFlight[start] = entry
            }
            return SegmentValue(data: try await entry.task.value, cacheHit: false)
        }

        let lane: RangeRequestLane = preload ? .preload(worker: 0) : .playback
        let token = UUID()
        let task = Task<Data, Error> { [weak self] in
            guard let self else { throw MediaTransportError.cancelled }
            return try await self.downloadSegment(start: start, allowRefresh: true, lane: lane)
        }
        inFlight[start] = InFlightEntry(token: token, task: task, preloadOnly: preload)

        do {
            let data = try await task.value
            if inFlight[start]?.token == token { inFlight[start] = nil }
            await storeSegment(data, start: start)
            return SegmentValue(data: data, cacheHit: false)
        } catch {
            if inFlight[start]?.token == token { inFlight[start] = nil }
            if !(error is CancellationError) { metricsValue.rangeFailureCount += 1 }
            throw error
        }
    }

    private func cachedSegment(start: Int64) async -> Data? {
        if let memory = memoryEntries[start] {
            memoryEntries[start] = MemoryEntry(data: memory.data, lastAccess: Date())
            cachedRanges.insert(start..<(start + Int64(memory.data.count)))
            return memory.data
        }

        if configuration.usesDiskCache, let diskData = await diskCache.read(start: start) {
            cachedRanges.insert(start..<(start + Int64(diskData.count)))
            insertMemory(diskData, start: start)
            return diskData
        }
        return nil
    }

    private func storeSegment(_ data: Data, start: Int64) async {
        guard !data.isEmpty else { return }
        cachedRanges.insert(start..<(start + Int64(data.count)))
        insertMemory(data, start: start)
        if configuration.usesDiskCache {
            await diskCache.write(data, start: start)
        }
        resumeSegmentWaiters(start: start)
    }

    private func waitForPreloadSegment(start: Int64) async {
        guard preloadBlocks.values.contains(where: { $0.range.contains(start) }) else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            if memoryEntries[start] != nil {
                continuation.resume()
            } else {
                segmentWaiters[start, default: []].append(continuation)
            }
        }
    }

    private func resumeSegmentWaiters(start: Int64) {
        let waiters = segmentWaiters.removeValue(forKey: start) ?? []
        waiters.forEach { $0.resume() }
    }

    private func resumeSegmentWaiters(in range: Range<Int64>) {
        let starts = segmentWaiters.keys.filter { range.contains($0) }
        starts.forEach { resumeSegmentWaiters(start: $0) }
    }

    private func resumeAllSegmentWaiters() {
        let waiters = segmentWaiters.values.flatMap { $0 }
        segmentWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    private func downloadSegment(start: Int64, allowRefresh: Bool, lane: RangeRequestLane) async throws -> Data {
        let failedResource = try await resolve()
        let end = min(failedResource.contentLength, start + configuration.segmentSizeBytes)
        guard end > start else { return Data() }

        do {
            return try await fetch(resource: failedResource, range: start..<end, lane: lane)
        } catch MediaTransportError.expiredURL(_) where allowRefresh {
            DiagnosticsLogger.shared.log(
                "TransportRetry",
                "status=403/410 start=\(start) retrying current 115 URL before refresh"
            )
            try? await Task.sleep(nanoseconds: 250_000_000)

            if let current = resource, current.finalURL != failedResource.finalURL {
                return try await fetch(resource: current, range: start..<end, lane: lane)
            }

            do {
                return try await fetch(resource: failedResource, range: start..<end, lane: lane)
            } catch MediaTransportError.expiredURL(_) {
                let refreshed = try await refreshPlaybackResource(failedResource: failedResource)
                return try await fetch(resource: refreshed, range: start..<end, lane: lane)
            }
        }
    }

    private func fetch(resource: TransportResolvedResource, range: Range<Int64>, lane: RangeRequestLane) async throws -> Data {
        metricsValue.activeRequestCount += 1
        metricsValue.networkRequestCount += 1
        defer { metricsValue.activeRequestCount = max(0, metricsValue.activeRequestCount - 1) }

        let data = try await httpClient.fetch(resource: resource, range: range, lane: lane)
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
        let configuredLimit = NetworkPathMonitor.shared.isCellular
            ? configuration.cellularPreloadBytes
            : configuration.wifiPreloadBytes
        let isCellular = NetworkPathMonitor.shared.isCellular
        let minimumWindow = isCellular ? Int64(16 * 1_048_576) : Int64(32 * 1_048_576)
        let maximumWindow = isCellular ? Int64(64 * 1_048_576) : Int64(128 * 1_048_576)
        let preloadLimit = min(max(configuredLimit, minimumWindow), maximumWindow)
        guard preloadLimit > 0 else { return }

        if preloadTask != nil {
            return
        }
        if let preloadWindow, preloadWindow.contains(offset) {
            return
        }

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

        let segmentSize = max(1, configuration.segmentSizeBytes)
        let blockSize = max(segmentSize, configuration.upstreamBlockSizeBytes)
        var firstStart = (offset / segmentSize) * segmentSize
        if firstStart < offset { firstStart += segmentSize }
        let finalOffset = min(resource.contentLength, firstStart + maximumBytes)
        let concurrency = resource.looksLike115CDN ? 1 : max(1, min(2, configuration.maximumConcurrentRequests - 1))
        guard firstStart < finalOffset else { return }

        DiagnosticsLogger.shared.log(
            "TransportBulk",
            "pipeline start=\(firstStart) end=\(finalOffset) block=\(blockSize) workers=\(concurrency)"
        )

        var cursor = firstStart
        var round = 0
        let warmupSize = max(segmentSize, min(blockSize, 4 * 1_048_576))

        while cursor < finalOffset, !Task.isCancelled, !stopped {
            let workerBlockSize = round < 4 ? warmupSize : blockSize
            await withTaskGroup(of: Void.self) { group in
                for worker in 0..<concurrency {
                    let blockStart = cursor + Int64(worker) * workerBlockSize
                    guard blockStart < finalOffset else { continue }
                    let blockEnd = min(finalOffset, blockStart + workerBlockSize)
                    group.addTask { [weak self] in
                        guard let self else { return }
                        await self.preloadBlock(range: blockStart..<blockEnd, worker: worker)
                    }
                }
            }
            cursor += Int64(concurrency) * workerBlockSize
            round += 1
        }
    }

    private func preloadBlock(range: Range<Int64>, worker: Int) async {
        guard !range.isEmpty, !Task.isCancelled, !stopped else { return }
        if let existing = preloadBlocks[range.lowerBound] {
            _ = try? await existing.task.value
            return
        }

        let token = UUID()
        let task = Task<Void, Error> { [weak self] in
            guard let self else { throw MediaTransportError.cancelled }
            try await self.downloadPreloadBlock(range: range, worker: worker)
        }
        preloadBlocks[range.lowerBound] = PreloadBlockEntry(token: token, range: range, task: task)

        do {
            try await task.value
        } catch is CancellationError {
        } catch {
            metricsValue.rangeFailureCount += 1
            DiagnosticsLogger.shared.log(
                "TransportBulk",
                "worker=\(worker) start=\(range.lowerBound) length=\(range.count) failed=\(error.localizedDescription)"
            )
        }

        if preloadBlocks[range.lowerBound]?.token == token { preloadBlocks[range.lowerBound] = nil }
        resumeSegmentWaiters(in: range)
    }

    private func downloadPreloadBlock(range: Range<Int64>, worker: Int) async throws {
        let missing = await missingRanges(in: range)
        for missingRange in missing where !Task.isCancelled {
            try await streamPreloadRange(range: missingRange, worker: worker, allowRefresh: true)
        }
    }

    private func missingRanges(in range: Range<Int64>) async -> [Range<Int64>] {
        let segmentSize = max(1, configuration.segmentSizeBytes)
        var ranges: [Range<Int64>] = []
        var currentRangeStart: Int64?
        var cursor = range.lowerBound

        while cursor < range.upperBound {
            let segmentEnd = min(range.upperBound, cursor + segmentSize)
            let cachedInMemory = memoryEntries[cursor] != nil
            let cachedOnDisk: Bool
            if configuration.usesDiskCache {
                cachedOnDisk = await diskCache.contains(start: cursor)
            } else {
                cachedOnDisk = false
            }
            let isCached = cachedInMemory || cachedOnDisk

            if isCached {
                if let rangeStart = currentRangeStart {
                    ranges.append(rangeStart..<cursor)
                    currentRangeStart = nil
                }
            } else if currentRangeStart == nil {
                currentRangeStart = cursor
            }
            cursor = segmentEnd
        }

        if let currentRangeStart {
            ranges.append(currentRangeStart..<range.upperBound)
        }
        return ranges
    }


    private func streamPreloadRange(range: Range<Int64>, worker: Int, allowRefresh: Bool) async throws {
        let failedResource = try await resolve()
        do {
            try await consumePreloadStream(resource: failedResource, range: range, worker: worker)
        } catch MediaTransportError.expiredURL(_) where allowRefresh {
            DiagnosticsLogger.shared.log(
                "TransportRetry",
                "status=403/410 bulkStart=\(range.lowerBound) retrying current 115 URL before refresh"
            )
            try? await Task.sleep(nanoseconds: 250_000_000)

            if let current = resource, current.finalURL != failedResource.finalURL {
                try await consumePreloadStream(resource: current, range: range, worker: worker)
                return
            }

            do {
                try await consumePreloadStream(resource: failedResource, range: range, worker: worker)
            } catch MediaTransportError.expiredURL(_) {
                let refreshed = try await refreshPlaybackResource(failedResource: failedResource)
                try await consumePreloadStream(resource: refreshed, range: range, worker: worker)
            }
        }
    }

    private func consumePreloadStream(resource: TransportResolvedResource, range: Range<Int64>, worker: Int) async throws {
        metricsValue.activeRequestCount += 1
        metricsValue.networkRequestCount += 1
        let startedAt = Date()
        defer { metricsValue.activeRequestCount = max(0, metricsValue.activeRequestCount - 1) }

        let stream = httpClient.stream(resource: resource, range: range, worker: worker)
        let segmentSize = max(1, configuration.segmentSizeBytes)
        var buffer = Data()
        var segmentStart = range.lowerBound
        var received: Int64 = 0

        for try await chunk in stream {
            guard !Task.isCancelled, !stopped else { throw CancellationError() }
            buffer.append(chunk)
            received += Int64(chunk.count)
            metricsValue.bytesDownloaded += Int64(chunk.count)
            metricsValue.elapsedSeconds = Date().timeIntervalSince(createdAt)
            recordDownload(bytes: Int64(chunk.count))
            logProgressIfNeeded()

            while segmentStart < range.upperBound {
                let expectedLength = Int(min(segmentSize, range.upperBound - segmentStart))
                guard buffer.count >= expectedLength else { break }
                let segmentData = Data(buffer.prefix(expectedLength))
                buffer.removeFirst(expectedLength)
                await storeSegment(segmentData, start: segmentStart)
                segmentStart += Int64(expectedLength)
            }
        }

        if Task.isCancelled || stopped { throw CancellationError() }
        guard received == Int64(range.count), buffer.isEmpty, segmentStart == range.upperBound else {
            throw MediaTransportError.shortRead(expected: Int(range.count), actual: Int(received))
        }

        let elapsed = max(Date().timeIntervalSince(startedAt), 0.001)
        DiagnosticsLogger.shared.log(
            "TransportBulk",
            "worker=\(worker) start=\(range.lowerBound) length=\(range.count) ms=\(Int(elapsed * 1000)) speedBps=\(Int(Double(range.count) / elapsed))"
        )
    }

    private func cancelPreloadNetworkTasks() {
        let starts = inFlight.compactMap { start, entry in
            entry.preloadOnly ? start : nil
        }
        for start in starts {
            inFlight[start]?.task.cancel()
            inFlight[start] = nil
        }

        let blocks = Array(preloadBlocks.values)
        blocks.forEach { $0.task.cancel() }
        preloadBlocks.removeAll()
        blocks.forEach { resumeSegmentWaiters(in: $0.range) }
    }

    private func acceptsReadDemand(_ offset: Int64) -> Bool {
        let candidate = max(0, offset)
        if Date() < priorityDemandUntil, abs(candidate - demandOffset) > 32 * 1_048_576 { return false }
        return candidate + 4 * 1_048_576 >= demandOffset
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
