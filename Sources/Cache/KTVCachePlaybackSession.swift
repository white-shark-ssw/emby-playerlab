import Foundation

final class KTVCachePlaybackSession {
    let originalURL: URL
    let proxyURL: URL

    private let headers: [String: String]
    private let contentLength: Int64
    private let configuration: MediaTransportConfiguration
    private let baselineCacheBytes: Int64
    private let lock = NSLock()
    private var loader: EPLKTVPreloadHandle?
    private var loaderGeneration: UInt64 = 0
    private var startedAt = Date()
    private var lastSampleAt = Date()
    private var lastSampleBytes: Int64 = 0
    private var currentBytesPerSecond: Double = 0
    private var loadedBytes: Int64 = 0
    private var progress: Double = 0
    private var failureCount = 0
    private var active = false
    private var completed = false
    private var lastProgressAt = Date()
    private var stopped = false

    init(source: ResolvedPlaybackSource, configuration: MediaTransportConfiguration) throws {
        self.originalURL = source.url
        self.headers = source.headers
        self.contentLength = max(source.mediaSource.size ?? 0, 0)
        self.configuration = configuration

        let cacheBytes = configuration.diskLimitBytes > 0 ? configuration.diskLimitBytes : 2 * 1_073_741_824
        if let error = EPLKTVCacheBridge.start(maxCacheLength: cacheBytes, allowedHeaderKeys: Array(source.headers.keys)) { throw error }
        self.proxyURL = EPLKTVCacheBridge.proxyURL(for: source.url)
        self.baselineCacheBytes = EPLKTVCacheBridge.cacheLength(for: source.url)
        self.loadedBytes = self.baselineCacheBytes
        self.lastSampleBytes = self.baselineCacheBytes

        DiagnosticsLogger.shared.log(
            "KTVCache",
            "proxy started originalHost=\(source.url.host ?? "unknown") proxyPort=\(proxyURL.port ?? 0) cacheBudget=\(cacheBytes)B"
        )
        startPreloadIfAllowed(reason: "initial")
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

    func ensurePreloadActive(reason: String) {
        lock.lock()
        let shouldRestart = !completed && (!active || Date().timeIntervalSince(lastProgressAt) > 8)
        lock.unlock()
        guard shouldRestart else { return }
        startPreloadIfAllowed(reason: reason)
    }

    func metrics() -> TransportMetricsSnapshot {
        let itemCacheBytes = EPLKTVCacheBridge.cacheLength(for: originalURL)
        let resourceBytes = max(contentLength, EPLKTVCacheBridge.resourceLength(for: originalURL))
        lock.lock()
        loadedBytes = max(loadedBytes, itemCacheBytes)
        sampleSpeedLocked(now: Date())
        let bytes = loadedBytes
        let speed = currentBytesPerSecond
        let isActive = active
        let failures = failureCount
        let elapsed = max(Date().timeIntervalSince(startedAt), 0.001)
        let currentProgress = progress
        lock.unlock()

        let estimatedContiguous: Int64
        if resourceBytes > 0 { estimatedContiguous = min(resourceBytes, max(itemCacheBytes, Int64(Double(resourceBytes) * currentProgress))) }
        else { estimatedContiguous = bytes }

        return TransportMetricsSnapshot(
            bytesDownloaded: max(0, bytes - baselineCacheBytes),
            bytesServed: 0,
            cacheHitBytes: 0,
            networkRequestCount: isActive ? 1 : 0,
            rangeFailureCount: failures,
            activeRequestCount: isActive ? 1 : 0,
            cacheBytes: itemCacheBytes,
            memoryCacheBytes: 0,
            diskCacheBytes: itemCacheBytes,
            contiguousCacheBytes: estimatedContiguous,
            currentDownloadBytesPerSecond: speed,
            elapsedSeconds: elapsed
        )
    }

    private func startPreloadIfAllowed(reason: String) {
        guard configuration.ktvContinuousPreloadEnabled else {
            DiagnosticsLogger.shared.log("KTVCache", "continuous preload disabled")
            return
        }
        if NetworkPathMonitor.shared.isCellular && !configuration.ktvPreloadOnCellular {
            DiagnosticsLogger.shared.log("KTVCache", "continuous preload skipped on cellular")
            return
        }

        lock.lock()
        loaderGeneration &+= 1
        let generation = loaderGeneration
        let previous = loader
        loader = nil
        active = true
        completed = false
        lastProgressAt = Date()
        lastSampleAt = Date()
        lastSampleBytes = loadedBytes
        lock.unlock()
        previous?.close()

        let endOffset = contentLength > 0 ? contentLength - 1 : -1
        let newLoader = EPLKTVCacheBridge.preload(
            url: originalURL,
            headers: headers,
            startOffset: 0,
            endOffset: endOffset,
            progress: { [weak self] loadedLength, progress in
                guard let self else { return }
                self.lock.lock()
                guard generation == self.loaderGeneration else { self.lock.unlock(); return }
                let itemCacheBytes = EPLKTVCacheBridge.cacheLength(for: self.originalURL)
                self.loadedBytes = max(self.loadedBytes, itemCacheBytes, self.baselineCacheBytes + loadedLength)
                self.progress = max(self.progress, progress)
                self.lastProgressAt = Date()
                self.sampleSpeedLocked(now: Date())
                self.lock.unlock()
            },
            completion: { [weak self] error in
                guard let self else { return }
                self.lock.lock()
                guard generation == self.loaderGeneration else { self.lock.unlock(); return }
                self.active = false
                if let error { self.failureCount += 1 }
                else { self.completed = true; self.progress = 1 }
                let loaded = self.loadedBytes
                self.lock.unlock()

                if let error {
                    DiagnosticsLogger.shared.log("KTVCache", "preload failed reason=\(reason) loaded=\(loaded) error=\(error.localizedDescription)")
                } else {
                    let complete = EPLKTVCacheBridge.completeFileURL(for: self.originalURL) != nil
                    DiagnosticsLogger.shared.log("KTVCache", "preload finished loaded=\(loaded) completeFile=\(complete)")
                }
            }
        )

        lock.lock()
        if generation == loaderGeneration { loader = newLoader }
        else { newLoader.close() }
        lock.unlock()
        DiagnosticsLogger.shared.log("KTVCache", "preload start reason=\(reason) range=0-\(endOffset) contentLength=\(contentLength)")
    }

    private func sampleSpeedLocked(now: Date) {
        let interval = now.timeIntervalSince(lastSampleAt)
        guard interval >= 0.8 else { return }
        let delta = max(0, loadedBytes - lastSampleBytes)
        let instant = Double(delta) / interval
        currentBytesPerSecond = currentBytesPerSecond > 0 ? currentBytesPerSecond * 0.65 + instant * 0.35 : instant
        lastSampleAt = now
        lastSampleBytes = loadedBytes
    }
}
