import Foundation

final class KTVCachePlaybackSession {
    let originalURL: URL
    let proxyURL: URL

    private let headers: [String: String]
    private let contentLength: Int64
    private let configuration: MediaTransportConfiguration
    private let baselineCacheBytes: Int64
    private let targetCacheBytes: Int64
    private let mediaBytesPerSecond: Double
    private let lock = NSLock()
    private let segmentBytes: Int64 = 32 * 1_048_576
    private let seekDebounceInterval: TimeInterval = 0.75

    private var loader: EPLKTVPreloadHandle?
    private var loaderGeneration: UInt64 = 0
    private var activeSegmentStart: Int64 = 0
    private var activeSegmentEnd: Int64 = 0
    private var activeSegmentLoaded: Int64 = 0
    private var activeSegmentStartedAt = Date()
    private var activeSegmentCacheStart: Int64 = 0
    private var nextOffset: Int64 = 0
    private var sessionRanges = SparseByteRangeSet()
    private var wrappedToStart = false
    private var playbackPosition: Double = 0
    private var playbackDuration: Double = 0
    private var lastSeekAt = Date.distantPast
    private var seekDebounceWorkItem: DispatchWorkItem?
    private var seekDebounceGeneration: UInt64 = 0
    private var startedAt = Date()
    private var lastSampleAt = Date()
    private var lastSampleBytes: Int64 = 0
    private var currentBytesPerSecond: Double = 0
    private var loadedBytes: Int64 = 0
    private var failureCount = 0
    private var requestCount = 0
    private var active = false
    private var completed = false
    private var lastProgressAt = Date()
    private var slowSince: Date?
    private var lastRotationAt = Date.distantPast
    private var stopped = false

    init(source: ResolvedPlaybackSource, configuration: MediaTransportConfiguration) throws {
        self.originalURL = source.url
        self.headers = source.headers
        self.contentLength = max(source.mediaSource.size ?? 0, 0)
        self.configuration = configuration
        let duration = max(source.mediaSource.durationSeconds ?? 0, 1)
        self.mediaBytesPerSecond = contentLength > 0 ? Double(contentLength) / duration : 2 * 1_048_576
        let cacheBytes = configuration.diskLimitBytes > 0 ? configuration.diskLimitBytes : 2 * 1_073_741_824
        self.targetCacheBytes = contentLength > 0 ? min(contentLength, cacheBytes) : cacheBytes
        if let error = EPLKTVCacheBridge.start(maxCacheLength: cacheBytes, allowedHeaderKeys: Array(source.headers.keys)) { throw error }
        self.proxyURL = EPLKTVCacheBridge.proxyURL(for: source.url)
        self.baselineCacheBytes = EPLKTVCacheBridge.cacheLength(for: source.url)
        self.loadedBytes = self.baselineCacheBytes
        self.lastSampleBytes = self.baselineCacheBytes
        DiagnosticsLogger.shared.log(
            "KTVCache",
            "proxy started originalHost=\(source.url.host ?? "unknown") proxyPort=\(proxyURL.port ?? 0) cacheBudget=\(cacheBytes)B target=\(targetCacheBytes)B segment=\(segmentBytes)B \(NetworkPathMonitor.shared.diagnosticSummary)"
        )
        Task { [source] in
            do {
                let startedAt = Date()
                let resource = try await RedirectResolver().resolve(source: source)
                let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
                DiagnosticsLogger.shared.log("KTVOrigin", "probe finalHost=\(resource.finalURL.host ?? "unknown") redirects=\(resource.redirectCount) bytes=\(resource.contentLength) range=\(resource.supportsByteRanges) ms=\(elapsedMs) \(NetworkPathMonitor.shared.diagnosticSummary)")
            } catch {
                DiagnosticsLogger.shared.log("KTVOrigin", "probe failed error=\(error.localizedDescription) \(NetworkPathMonitor.shared.diagnosticSummary)")
            }
        }
        startPreloadIfAllowed(reason: "initial", startOffset: firstMissingOffset(from: 0))
    }

    deinit { stop() }

    func stop() {
        lock.lock()
        guard !stopped else { lock.unlock(); return }
        stopped = true
        seekDebounceWorkItem?.cancel()
        seekDebounceWorkItem = nil
        loaderGeneration &+= 1
        let current = loader
        loader = nil
        active = false
        lock.unlock()
        current?.close()
        if !configuration.keepLastCache { EPLKTVCacheBridge.deleteCache(for: originalURL) }
    }

    func updatePlayback(position: Double, duration: Double) {
        lock.lock()
        playbackPosition = max(0, position)
        if duration.isFinite, duration > 0 { playbackDuration = duration }
        lock.unlock()
    }

    func prioritizeSeek(position: Double, duration: Double) {
        guard contentLength > 0, duration.isFinite, duration > 0 else {
            ensurePreloadActive(reason: "seek without byte map")
            return
        }
        let ratio = min(max(position / duration, 0), 1)
        let rawOffset = Int64(Double(contentLength) * ratio)
        let alignedOffset = max(0, min(contentLength - 1, rawOffset / 1_048_576 * 1_048_576))

        lock.lock()
        playbackPosition = max(0, position)
        playbackDuration = duration
        lastSeekAt = Date()
        wrappedToStart = false
        seekDebounceWorkItem?.cancel()
        seekDebounceGeneration &+= 1
        let generation = seekDebounceGeneration
        let activeContainsTarget = active && alignedOffset >= activeSegmentStart && alignedOffset <= activeSegmentEnd
        let work = DispatchWorkItem { [weak self] in self?.commitSeekPriority(position: position, duration: duration, alignedOffset: alignedOffset, generation: generation) }
        seekDebounceWorkItem = activeContainsTarget ? nil : work
        lock.unlock()

        if activeContainsTarget {
            DiagnosticsLogger.shared.log("KTVAdaptive", "seek coalesced target already covered position=\(position) byte=\(alignedOffset)")
            return
        }
        DiagnosticsLogger.shared.log("KTVAdaptive", "seek queued position=\(position) duration=\(duration) byte=\(alignedOffset) debounceMs=\(Int(seekDebounceInterval * 1000))")
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + seekDebounceInterval, execute: work)
    }

    private func commitSeekPriority(position: Double, duration: Double, alignedOffset: Int64, generation: UInt64) {
        lock.lock()
        guard !stopped, seekDebounceWorkItem != nil, generation == seekDebounceGeneration else { lock.unlock(); return }
        seekDebounceWorkItem = nil
        let activeContainsTarget = active && alignedOffset >= activeSegmentStart && alignedOffset <= activeSegmentEnd
        lock.unlock()
        guard !activeContainsTarget else {
            DiagnosticsLogger.shared.log("KTVAdaptive", "seek final target covered position=\(position) byte=\(alignedOffset)")
            return
        }
        let start = firstMissingOffset(from: alignedOffset)
        DiagnosticsLogger.shared.log("KTVAdaptive", "seek reprioritize final position=\(position) duration=\(duration) byte=\(alignedOffset) start=\(start)")
        startPreloadIfAllowed(reason: "seek-priority-final", startOffset: start)
    }

    func ensurePreloadActive(reason: String) {
        lock.lock()
        let noProgressSeconds = Date().timeIntervalSince(lastProgressAt)
        let shouldRestart = !completed && (!active || noProgressSeconds > 8)
        let restartOffset = active ? min(activeSegmentEnd + 1, max(activeSegmentStart, activeSegmentStart + activeSegmentLoaded)) : nextOffset
        lock.unlock()
        guard shouldRestart else { return }
        startPreloadIfAllowed(reason: reason, startOffset: firstMissingOffset(from: restartOffset))
    }

    func metrics() -> TransportMetricsSnapshot {
        let itemCacheBytes = EPLKTVCacheBridge.cacheLength(for: originalURL)
        let resourceBytes = max(contentLength, EPLKTVCacheBridge.resourceLength(for: originalURL))
        let now = Date()

        lock.lock()
        loadedBytes = max(loadedBytes, itemCacheBytes)
        sampleSpeedLocked(now: now)
        evaluateSlowConnectionLocked(now: now)
        let bytes = loadedBytes
        let speed = currentBytesPerSecond
        let isActive = active
        let failures = failureCount
        let requests = requestCount
        let elapsed = max(now.timeIntervalSince(startedAt), 0.001)
        let playbackByte = byteOffsetLocked(position: playbackPosition, duration: playbackDuration, resourceBytes: resourceBytes)
        let trackedContiguous = sessionRanges.contiguousLength(from: playbackByte, maximumLength: max(0, resourceBytes - playbackByte))
        let shouldRotate = slowSince != nil && now.timeIntervalSince(slowSince ?? now) >= 8 && now.timeIntervalSince(lastRotationAt) >= 12
        let rotateOffset = min(activeSegmentEnd + 1, max(activeSegmentStart, activeSegmentStart + activeSegmentLoaded))
        lock.unlock()

        if shouldRotate {
            rotateSlowConnection(from: rotateOffset, observedSpeed: speed)
        }

        return TransportMetricsSnapshot(
            bytesDownloaded: max(0, bytes - baselineCacheBytes),
            bytesServed: 0,
            cacheHitBytes: 0,
            networkRequestCount: requests,
            rangeFailureCount: failures,
            activeRequestCount: isActive ? 1 : 0,
            cacheBytes: itemCacheBytes,
            memoryCacheBytes: 0,
            diskCacheBytes: itemCacheBytes,
            contiguousCacheBytes: trackedContiguous,
            currentDownloadBytesPerSecond: speed,
            elapsedSeconds: elapsed
        )
    }

    private func startPreloadIfAllowed(reason: String, startOffset: Int64) {
        guard configuration.ktvContinuousPreloadEnabled else {
            DiagnosticsLogger.shared.log("KTVCache", "continuous preload disabled")
            return
        }
        if NetworkPathMonitor.shared.isCellular && !configuration.ktvPreloadOnCellular {
            DiagnosticsLogger.shared.log("KTVCache", "continuous preload skipped on cellular")
            return
        }
        guard !stopped else { return }

        let itemCacheBytes = EPLKTVCacheBridge.cacheLength(for: originalURL)
        if targetCacheBytes > 0, itemCacheBytes >= max(0, targetCacheBytes - 1_048_576) {
            lock.lock()
            completed = true
            active = false
            lock.unlock()
            DiagnosticsLogger.shared.log("KTVAdaptive", "cache target reached cached=\(itemCacheBytes) target=\(targetCacheBytes)")
            return
        }

        var offset = max(0, startOffset)
        if contentLength > 0, offset >= contentLength {
            lock.lock()
            if !wrappedToStart {
                wrappedToStart = true
                offset = 0
            } else {
                completed = true
                active = false
                lock.unlock()
                DiagnosticsLogger.shared.log("KTVAdaptive", "preload traversal finished cached=\(itemCacheBytes) completeFile=\(EPLKTVCacheBridge.completeFileURL(for: originalURL) != nil)")
                return
            }
            lock.unlock()
        }

        lock.lock()
        let segmentBytes = self.segmentBytes
        let endOffset = contentLength > 0 ? min(contentLength - 1, offset + segmentBytes - 1) : offset + segmentBytes - 1
        loaderGeneration &+= 1
        let generation = loaderGeneration
        let previous = loader
        loader = nil
        active = true
        completed = false
        activeSegmentStart = offset
        activeSegmentEnd = endOffset
        activeSegmentLoaded = 0
        activeSegmentStartedAt = Date()
        activeSegmentCacheStart = itemCacheBytes
        lastProgressAt = Date()
        slowSince = nil
        requestCount += 1
        nextOffset = endOffset + 1
        lock.unlock()
        previous?.close()

        let segmentStart = offset
        let segmentEnd = endOffset
        let newLoader = EPLKTVCacheBridge.preload(
            url: originalURL,
            headers: headers,
            startOffset: segmentStart,
            endOffset: segmentEnd,
            progress: { [weak self] loadedLength, _ in
                guard let self else { return }
                let cacheBytes = EPLKTVCacheBridge.cacheLength(for: self.originalURL)
                self.lock.lock()
                guard generation == self.loaderGeneration else { self.lock.unlock(); return }
                self.activeSegmentLoaded = max(self.activeSegmentLoaded, loadedLength)
                let availableEnd = min(self.activeSegmentEnd + 1, self.activeSegmentStart + max(0, loadedLength))
                if availableEnd > self.activeSegmentStart { self.sessionRanges.insert(self.activeSegmentStart..<availableEnd) }
                self.loadedBytes = max(self.loadedBytes, cacheBytes)
                self.lastProgressAt = Date()
                self.sampleSpeedLocked(now: Date())
                self.lock.unlock()
            },
            completion: { [weak self] error in
                guard let self else { return }
                let cacheBytes = EPLKTVCacheBridge.cacheLength(for: self.originalURL)
                self.lock.lock()
                guard generation == self.loaderGeneration else { self.lock.unlock(); return }
                self.active = false
                self.loader = nil
                let elapsed = max(Date().timeIntervalSince(self.activeSegmentStartedAt), 0.001)
                let loaded = max(0, self.activeSegmentLoaded)
                let newCacheBytes = max(0, cacheBytes - self.activeSegmentCacheStart)
                let cacheHit = newCacheBytes == 0
                let networkBytes = cacheHit ? 0 : min(newCacheBytes, loaded)
                let speed = networkBytes > 0 ? Double(networkBytes) / elapsed : 0
                if error != nil { self.failureCount += 1 }
                else if self.activeSegmentEnd >= self.activeSegmentStart {
                    self.sessionRanges.insert(self.activeSegmentStart..<(self.activeSegmentEnd + 1))
                }
                self.loadedBytes = max(self.loadedBytes, cacheBytes)
                let next = self.nextOffset
                self.lock.unlock()

                if let error {
                    DiagnosticsLogger.shared.log("KTVAdaptive", "segment failed range=\(segmentStart)-\(segmentEnd) loaded=\(loaded) networkBytes=\(networkBytes) speed=\(Int(speed))B/s error=\(error.localizedDescription)")
                    let retryOffset = segmentStart + loaded
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self else { return }
                        self.startPreloadIfAllowed(reason: "segment-retry", startOffset: self.firstMissingOffset(from: retryOffset))
                    }
                } else {
                    DiagnosticsLogger.shared.log("KTVAdaptive", "segment finished range=\(segmentStart)-\(segmentEnd) cacheHit=\(cacheHit) newCache=\(newCacheBytes) networkBytes=\(networkBytes) loaded=\(loaded) speed=\(Int(speed))B/s next=\(next)")
                    DispatchQueue.global(qos: .utility).async { [weak self] in
                        guard let self else { return }
                        self.startPreloadIfAllowed(reason: "segment-next", startOffset: self.firstMissingOffset(from: next))
                    }
                }
            }
        )

        lock.lock()
        if generation == loaderGeneration { loader = newLoader }
        else { newLoader.close() }
        lock.unlock()
        DiagnosticsLogger.shared.log("KTVAdaptive", "segment start reason=\(reason) range=\(segmentStart)-\(segmentEnd) size=\(segmentBytes)")
    }

    private func evaluateSlowConnectionLocked(now: Date) {
        guard active, now.timeIntervalSince(lastSeekAt) >= 2 else { slowSince = nil; return }
        let threshold = max(mediaBytesPerSecond * 1.15, 2 * 1_048_576)
        let noProgress = now.timeIntervalSince(lastProgressAt) >= 4
        let tooSlow = currentBytesPerSecond > 0 && currentBytesPerSecond < threshold
        if noProgress || tooSlow {
            if slowSince == nil { slowSince = now }
        } else {
            slowSince = nil
        }
    }

    private func rotateSlowConnection(from offset: Int64, observedSpeed: Double) {
        lock.lock()
        guard !stopped, active, Date().timeIntervalSince(lastRotationAt) >= 12, Date().timeIntervalSince(lastSeekAt) >= 2 else { lock.unlock(); return }
        lastRotationAt = Date()
        slowSince = nil
        lock.unlock()
        DiagnosticsLogger.shared.log("KTVAdaptive", "slow connection restart speed=\(Int(observedSpeed))B/s restart=\(offset) segment=\(segmentBytes)")
        startPreloadIfAllowed(reason: "slow-restart", startOffset: firstMissingOffset(from: offset))
    }

    private func firstMissingOffset(from offset: Int64) -> Int64 {
        lock.lock()
        let upper = contentLength > 0 ? contentLength : Int64.max
        let missing = sessionRanges.firstMissingOffset(from: max(0, offset), upperBound: upper) ?? max(0, offset)
        lock.unlock()
        return missing
    }

    private func byteOffsetLocked(position: Double, duration: Double, resourceBytes: Int64) -> Int64 {
        guard resourceBytes > 0, duration.isFinite, duration > 0 else { return 0 }
        let ratio = min(max(position / duration, 0), 1)
        return min(resourceBytes - 1, max(0, Int64(Double(resourceBytes) * ratio)))
    }

    private func sampleSpeedLocked(now: Date) {
        let interval = now.timeIntervalSince(lastSampleAt)
        guard interval >= 0.8 else { return }
        let cacheBytes = EPLKTVCacheBridge.cacheLength(for: originalURL)
        loadedBytes = max(loadedBytes, cacheBytes)
        let delta = max(0, cacheBytes - lastSampleBytes)
        let instant = Double(delta) / interval
        currentBytesPerSecond = currentBytesPerSecond > 0 ? currentBytesPerSecond * 0.55 + instant * 0.45 : instant
        lastSampleAt = now
        lastSampleBytes = cacheBytes
    }

}
