import Foundation

final class KTVCachePlaybackSession {
    let originalURL: URL
    let proxyURL: URL

    private struct SegmentTrial: Codable {
        var samples: [Double] = []

        var average: Double {
            guard !samples.isEmpty else { return 0 }
            return samples.reduce(0, +) / Double(samples.count)
        }
    }

    private struct StoredProfile: Codable {
        let segmentBytes: Int64
        let averageBytesPerSecond: Double
    }

    private let headers: [String: String]
    private let contentLength: Int64
    private let configuration: MediaTransportConfiguration
    private let baselineCacheBytes: Int64
    private let targetCacheBytes: Int64
    private let mediaBytesPerSecond: Double
    private let profileKey: String
    private let lock = NSLock()
    private let candidateSegmentBytes: [Int64] = [16, 32, 64].map { Int64($0) * 1_048_576 }

    private var loader: EPLKTVPreloadHandle?
    private var loaderGeneration: UInt64 = 0
    private var activeSegmentStart: Int64 = 0
    private var activeSegmentEnd: Int64 = 0
    private var activeSegmentLoaded: Int64 = 0
    private var activeSegmentStartedAt = Date()
    private var activeSegmentCacheStart: Int64 = 0
    private var nextOffset: Int64 = 0
    private var preferredSegmentBytes: Int64 = 32 * 1_048_576
    private var trialIndex = 0
    private var trialResults: [Int64: SegmentTrial] = [:]
    private var sessionRanges = SparseByteRangeSet()
    private var wrappedToStart = false
    private var playbackPosition: Double = 0
    private var playbackDuration: Double = 0
    private var lastSeekAt = Date.distantPast
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
        self.profileKey = "ktv.adaptive.\(source.url.host?.lowercased() ?? "unknown")"

        let cacheBytes = configuration.diskLimitBytes > 0 ? configuration.diskLimitBytes : 2 * 1_073_741_824
        self.targetCacheBytes = contentLength > 0 ? min(contentLength, cacheBytes) : cacheBytes
        if let error = EPLKTVCacheBridge.start(maxCacheLength: cacheBytes, allowedHeaderKeys: Array(source.headers.keys)) { throw error }
        self.proxyURL = EPLKTVCacheBridge.proxyURL(for: source.url)
        self.baselineCacheBytes = EPLKTVCacheBridge.cacheLength(for: source.url)
        self.loadedBytes = self.baselineCacheBytes
        self.lastSampleBytes = self.baselineCacheBytes
        self.preferredSegmentBytes = Self.loadProfile(key: profileKey)?.segmentBytes ?? 32 * 1_048_576

        DiagnosticsLogger.shared.log(
            "KTVCache",
            "proxy started originalHost=\(source.url.host ?? "unknown") proxyPort=\(proxyURL.port ?? 0) cacheBudget=\(cacheBytes)B target=\(targetCacheBytes)B adaptiveSegment=\(preferredSegmentBytes)B"
        )
        startPreloadIfAllowed(reason: "initial", startOffset: firstMissingOffset(from: 0))
    }

    deinit { stop() }

    func stop() {
        lock.lock()
        guard !stopped else { lock.unlock(); return }
        stopped = true
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
        let activeContainsTarget = active && alignedOffset >= activeSegmentStart && alignedOffset <= activeSegmentEnd
        lock.unlock()

        guard !activeContainsTarget else {
            DiagnosticsLogger.shared.log("KTVAdaptive", "seek target already covered position=\(position) byte=\(alignedOffset)")
            return
        }
        DiagnosticsLogger.shared.log("KTVAdaptive", "seek reprioritize position=\(position) duration=\(duration) byte=\(alignedOffset)")
        startPreloadIfAllowed(reason: "seek-priority", startOffset: firstMissingOffset(from: alignedOffset))
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
        let segmentBytes = nextSegmentSizeLocked()
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
                let effectiveBytes = newCacheBytes > 0 ? newCacheBytes : loaded
                let speed = Double(effectiveBytes) / elapsed
                if error != nil { self.failureCount += 1 }
                else if self.activeSegmentEnd >= self.activeSegmentStart {
                    self.sessionRanges.insert(self.activeSegmentStart..<(self.activeSegmentEnd + 1))
                    self.recordTrialLocked(segmentBytes: segmentBytes, speed: speed, newCacheBytes: newCacheBytes)
                }
                self.loadedBytes = max(self.loadedBytes, cacheBytes)
                let next = self.nextOffset
                self.lock.unlock()

                if let error {
                    DiagnosticsLogger.shared.log("KTVAdaptive", "segment failed range=\(segmentStart)-\(segmentEnd) loaded=\(loaded) speed=\(Int(speed))B/s error=\(error.localizedDescription)")
                    let retryOffset = segmentStart + loaded
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self else { return }
                        self.startPreloadIfAllowed(reason: "segment-retry", startOffset: self.firstMissingOffset(from: retryOffset))
                    }
                } else {
                    DiagnosticsLogger.shared.log("KTVAdaptive", "segment finished range=\(segmentStart)-\(segmentEnd) newCache=\(newCacheBytes) loaded=\(loaded) speed=\(Int(speed))B/s next=\(next)")
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

    private func nextSegmentSizeLocked() -> Int64 {
        if trialIndex < candidateSegmentBytes.count {
            let candidate = candidateSegmentBytes[trialIndex]
            trialIndex += 1
            return candidate
        }
        return preferredSegmentBytes
    }

    private func recordTrialLocked(segmentBytes: Int64, speed: Double, newCacheBytes: Int64) {
        guard newCacheBytes >= 1_048_576, speed.isFinite, speed > 0 else { return }
        var trial = trialResults[segmentBytes] ?? SegmentTrial()
        trial.samples.append(speed)
        if trial.samples.count > 3 { trial.samples.removeFirst(trial.samples.count - 3) }
        trialResults[segmentBytes] = trial

        let best = trialResults.max { lhs, rhs in lhs.value.average < rhs.value.average }
        guard let best, best.value.average > 0 else { return }
        let old = preferredSegmentBytes
        preferredSegmentBytes = best.key
        if old != preferredSegmentBytes {
            DiagnosticsLogger.shared.log("KTVAdaptive", "segment winner old=\(old) new=\(preferredSegmentBytes) average=\(Int(best.value.average))B/s")
        }
        Self.saveProfile(StoredProfile(segmentBytes: preferredSegmentBytes, averageBytesPerSecond: best.value.average), key: profileKey)
    }

    private func evaluateSlowConnectionLocked(now: Date) {
        guard active else { slowSince = nil; return }
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
        guard !stopped, active, Date().timeIntervalSince(lastRotationAt) >= 12 else { lock.unlock(); return }
        lastRotationAt = Date()
        slowSince = nil
        if let index = candidateSegmentBytes.firstIndex(of: preferredSegmentBytes) {
            preferredSegmentBytes = candidateSegmentBytes[(index + 1) % candidateSegmentBytes.count]
        } else {
            preferredSegmentBytes = 32 * 1_048_576
        }
        let newSize = preferredSegmentBytes
        lock.unlock()
        DiagnosticsLogger.shared.log("KTVAdaptive", "slow connection rotate speed=\(Int(observedSpeed))B/s restart=\(offset) nextSegment=\(newSize)")
        startPreloadIfAllowed(reason: "slow-rotate", startOffset: firstMissingOffset(from: offset))
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

    private static func loadProfile(key: String) -> StoredProfile? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(StoredProfile.self, from: data)
    }

    private static func saveProfile(_ profile: StoredProfile, key: String) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
