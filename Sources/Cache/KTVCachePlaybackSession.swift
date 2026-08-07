import Foundation

final class KTVCachePlaybackSession {
    let originalURL: URL
    let proxyURL: URL

    private enum LaneID: String {
        case primary = "A"
        case secondary = "B"
    }

    private final class LaneState {
        let id: LaneID
        var loader: EPLKTVPreloadHandle?
        var generation: UInt64 = 0
        var active = false
        var segmentStart: Int64 = 0
        var segmentEnd: Int64 = 0
        var loaded: Int64 = 0
        var startedAt = Date()
        var cacheStart: Int64 = 0
        var requestCount = 0
        var failureCount = 0
        var consecutiveFailureCount = 0

        init(id: LaneID) { self.id = id }
    }

    private enum DualLanePhase: String {
        case singleBaseline
        case dualTrial
        case dualKept
        case dualRejected
    }

    private enum DualLaneAction {
        case none
        case startTrial(singleSpeed: Double)
        case keep(singleSpeed: Double, dualSpeed: Double)
        case reject(singleSpeed: Double, dualSpeed: Double, reason: String)
    }

    private let source: ResolvedPlaybackSource
    private let headers: [String: String]
    private let configuration: MediaTransportConfiguration
    private let openWarmupEnabled: Bool
    private let cacheBudgetBytes: Int64
    private let baselineCacheBytes: Int64
    private let lock = NSLock()
    private let segmentBytes: Int64 = 32 * 1_048_576
    private let singleBaselineSeconds: TimeInterval = 10
    private let dualTrialSeconds: TimeInterval = 15
    private let schedulerAnchorByte: Int64 = 0
    private let primaryLane = LaneState(id: .primary)
    private let secondaryLane = LaneState(id: .secondary)

    private var contentLength: Int64
    private var targetCacheBytes: Int64
    private var rangeMap = PlaybackRangeMap()
    private var playbackPosition: Double = 0
    private var playbackDuration: Double = 0
    private var lastSeekAt = Date.distantPast
    private var startedAt = Date()
    private var lastSampleAt = Date()
    private var lastSampleBytes: Int64 = 0
    private var currentBytesPerSecond: Double = 0
    private var loadedBytes: Int64 = 0
    private var lastProgressAt = Date()
    private var stopped = false
    private var initialPreloadStarted = false
    private var playbackPreparationFinished = false
    private var playbackPreparationCallbacks: [() -> Void] = []

    private var metadataGeneration: UInt64 = 0
    private var metadataHandle: EPLKTVPreloadHandle?

    private var dualPhase: DualLanePhase = .singleBaseline
    private var dualWindowStartedAt = Date()
    private var dualWindowStartBytes: Int64 = 0
    private var singleLaneBaselineSpeed: Double = 0
    private var dualTrialFailureBaseline = 0
    private var lastBufferMapLogAt = Date.distantPast

    init(source: ResolvedPlaybackSource, configuration: MediaTransportConfiguration, openWarmupEnabled: Bool = true) throws {
        self.source = source
        self.originalURL = source.url
        self.headers = source.headers
        self.configuration = configuration
        self.openWarmupEnabled = openWarmupEnabled
        self.contentLength = max(source.mediaSource.size ?? 0, 0)
        let cacheBytes = configuration.diskLimitBytes > 0 ? configuration.diskLimitBytes : 2 * 1_073_741_824
        self.cacheBudgetBytes = cacheBytes
        self.targetCacheBytes = contentLength > 0 ? min(contentLength, cacheBytes) : cacheBytes
        if let error = EPLKTVCacheBridge.start(maxCacheLength: cacheBytes, allowedHeaderKeys: Array(source.headers.keys)) { throw error }
        self.proxyURL = EPLKTVCacheBridge.proxyURL(for: source.url)
        self.baselineCacheBytes = EPLKTVCacheBridge.cacheLength(for: source.url)
        self.loadedBytes = baselineCacheBytes
        self.lastSampleBytes = baselineCacheBytes
        self.dualWindowStartBytes = baselineCacheBytes
        DiagnosticsLogger.shared.log(
            "KTVCache",
            "proxy started originalHost=\(source.url.host ?? "unknown") proxyPort=\(proxyURL.port ?? 0) cacheBudget=\(cacheBytes)B target=\(targetCacheBytes)B segment=\(segmentBytes)B scheduler=contiguous-frontier-1x2 metadataWarmup=\(openWarmupEnabled) \(NetworkPathMonitor.shared.diagnosticSummary)"
        )
    }

    deinit { stop() }

    func prepareForPlayback(completion: @escaping () -> Void) {
        lock.lock()
        guard !stopped else { lock.unlock(); return }
        if playbackPreparationFinished {
            lock.unlock()
            DispatchQueue.main.async { completion() }
            return
        }
        playbackPreparationCallbacks.append(completion)
        playbackPreparationFinished = true
        let callbacks = playbackPreparationCallbacks
        playbackPreparationCallbacks.removeAll()
        lock.unlock()

        startInitialPreloadOnce()
        if shouldWarmLargeMP4Metadata { scheduleLargeMP4MetadataWarmup() }
        probeOriginInBackground()
        DispatchQueue.main.async { callbacks.forEach { $0() } }
    }

    func stop() {
        lock.lock()
        guard !stopped else { lock.unlock(); return }
        stopped = true
        metadataGeneration &+= 1
        let metadata = metadataHandle
        metadataHandle = nil
        playbackPreparationCallbacks.removeAll()
        primaryLane.generation &+= 1
        secondaryLane.generation &+= 1
        let primary = primaryLane.loader
        let secondary = secondaryLane.loader
        primaryLane.loader = nil
        secondaryLane.loader = nil
        primaryLane.active = false
        secondaryLane.active = false
        rangeMap.clearDownloading(lane: LaneID.primary.rawValue)
        rangeMap.clearDownloading(lane: LaneID.secondary.rawValue)
        lock.unlock()
        metadata?.close()
        primary?.close()
        secondary?.close()
        if !configuration.keepLastCache { EPLKTVCacheBridge.deleteCache(for: originalURL) }
    }

    func updatePlayback(position: Double, duration: Double) {
        lock.lock()
        playbackPosition = max(0, position)
        if duration.isFinite, duration > 0 { playbackDuration = duration }
        lock.unlock()
    }

    func prioritizeSeek(position: Double, duration: Double) {
        lock.lock()
        playbackPosition = max(0, position)
        if duration.isFinite, duration > 0 { playbackDuration = duration }
        lastSeekAt = Date()
        let frontier = rangeMap.contiguousFrontier(from: schedulerAnchorByte)
        lock.unlock()
        DiagnosticsLogger.shared.log(
            "BufferAnchor",
            "reason=user-seek position=\(position) byteGuess=disabled schedulerAnchor=\(schedulerAnchorByte) frontier=\(frontier) action=keep-sequential-preload waitingForRealProxyDemand=true"
        )
        ensurePreloadActive(reason: "seek keeps contiguous frontier")
    }

    func yieldBandwidthToPlayback(position: Double, duration: Double, reason: String) {
        updatePlayback(position: position, duration: duration)
        DiagnosticsLogger.shared.log("BufferAnchor", "reason=\(reason) position=\(position) action=no-byte-guess-no-lane-cancel")
        ensurePreloadActive(reason: reason)
    }

    func ensurePreloadActive(reason: String) {
        scheduleAvailableWorkers(reason: reason)
    }

    func startupFallbackReason() -> String? {
        lock.lock()
        let idleSeconds = Date().timeIntervalSince(lastProgressAt)
        let active = primaryLane.active || secondaryLane.active || metadataHandle != nil
        let failures = primaryLane.failureCount + secondaryLane.failureCount
        let stopped = self.stopped
        lock.unlock()
        guard !stopped, !active, failures >= 3, idleSeconds >= 12 else { return nil }
        return "KTV连续Range已停止推进 idle=\(Int(idleSeconds))s failures=\(failures)"
    }

    func metrics() -> TransportMetricsSnapshot {
        let itemCacheBytes = EPLKTVCacheBridge.cacheLength(for: originalURL)
        let resourceBytes = max(resolvedContentLength(), EPLKTVCacheBridge.resourceLength(for: originalURL))
        let ktvZoneCount = EPLKTVCacheBridge.cacheZoneCount(for: originalURL)
        let now = Date()

        lock.lock()
        loadedBytes = max(loadedBytes, itemCacheBytes)
        sampleSpeedLocked(now: now)
        let dualAction = evaluateDualLaneLocked(now: now, cacheBytes: itemCacheBytes)
        let bytes = loadedBytes
        let speed = currentBytesPerSecond
        let activeRequests = (primaryLane.active ? 1 : 0) + (secondaryLane.active ? 1 : 0) + (metadataHandle != nil ? 1 : 0)
        let failures = primaryLane.failureCount + secondaryLane.failureCount
        let requests = primaryLane.requestCount + secondaryLane.requestCount
        let elapsed = max(now.timeIntervalSince(startedAt), 0.001)
        let map = rangeMap.snapshot(anchor: schedulerAnchorByte, resourceLength: resourceBytes)
        let shouldLogMap = now.timeIntervalSince(lastBufferMapLogAt) >= 1
        if shouldLogMap { lastBufferMapLogAt = now }
        let laneASummary = laneSummaryLocked(primaryLane)
        let laneBSummary = laneSummaryLocked(secondaryLane)
        let position = playbackPosition
        lock.unlock()

        performDualLaneAction(dualAction)
        if shouldLogMap {
            DiagnosticsLogger.shared.log(
                "BufferMap",
                "position=\(String(format: "%.3f", position)) demandAnchor=unavailable schedulerAnchor=\(map.anchorByte) frontier=\(map.frontierByte) forwardBytes=\(max(0, map.frontierByte - map.anchorByte)) playbackBytes=\(map.playbackBytes) metadataBytes=\(map.metadataBytes) holes=\(map.holeCount) ktvZones=\(ktvZoneCount) laneA=\(laneASummary) laneB=\(laneBSummary) networkBps=\(Int(speed))"
            )
        }

        return TransportMetricsSnapshot(
            bytesDownloaded: max(0, bytes - baselineCacheBytes),
            bytesServed: 0,
            cacheHitBytes: 0,
            networkRequestCount: requests,
            rangeFailureCount: failures,
            activeRequestCount: activeRequests,
            cacheBytes: itemCacheBytes,
            memoryCacheBytes: 0,
            diskCacheBytes: itemCacheBytes,
            contiguousCacheBytes: max(0, map.frontierByte - map.anchorByte),
            metadataCacheBytes: map.metadataBytes,
            sparsePlaybackCacheBytes: max(0, map.playbackBytes - max(0, map.frontierByte - map.anchorByte)),
            cacheHoleCount: map.holeCount,
            ktvCacheZoneCount: ktvZoneCount,
            schedulerAnchorByte: map.anchorByte,
            schedulerFrontierByte: map.frontierByte,
            currentDownloadBytesPerSecond: speed,
            elapsedSeconds: elapsed
        )
    }

    private var shouldWarmLargeMP4Metadata: Bool {
        let duration = source.mediaSource.durationSeconds ?? 0
        return openWarmupEnabled && source.mediaSource.normalizedContainer == "mp4" && (contentLength >= 4 * 1_073_741_824 || duration >= 3_600)
    }

    private func startInitialPreloadOnce() {
        lock.lock()
        guard !initialPreloadStarted, !stopped else { lock.unlock(); return }
        initialPreloadStarted = true
        dualPhase = .singleBaseline
        dualWindowStartedAt = Date()
        dualWindowStartBytes = EPLKTVCacheBridge.cacheLength(for: originalURL)
        lock.unlock()
        DiagnosticsLogger.shared.log("KTVAdaptive", "contiguous primary warmup anchor=\(schedulerAnchorByte) baselineSeconds=\(Int(singleBaselineSeconds))")
        scheduleAvailableWorkers(reason: "initial")
    }

    private func scheduleAvailableWorkers(reason: String) {
        startLaneIfPossible(.primary, reason: reason)
        lock.lock()
        let allowsSecondary = dualPhase == .dualTrial || dualPhase == .dualKept
        lock.unlock()
        if allowsSecondary { startLaneIfPossible(.secondary, reason: reason) }
    }

    private func startLaneIfPossible(_ laneID: LaneID, reason: String) {
        guard configuration.ktvContinuousPreloadEnabled else {
            DiagnosticsLogger.shared.log("KTVCache", "continuous preload disabled")
            return
        }
        if NetworkPathMonitor.shared.isCellular && !configuration.ktvPreloadOnCellular {
            DiagnosticsLogger.shared.log("KTVCache", "continuous preload skipped on cellular")
            return
        }

        let itemCacheBytes = EPLKTVCacheBridge.cacheLength(for: originalURL)
        lock.lock()
        guard !stopped else { lock.unlock(); return }
        let lane = laneID == .primary ? primaryLane : secondaryLane
        guard !lane.active else { lock.unlock(); return }
        let workerLimit = (dualPhase == .dualTrial || dualPhase == .dualKept) ? 2 : 1
        guard laneID == .primary || workerLimit == 2 else { lock.unlock(); return }
        let schedulerLimit = schedulingUpperBoundLocked()
        guard let claim = rangeMap.nextClaim(from: schedulerAnchorByte, resourceLength: schedulerLimit, segmentBytes: segmentBytes, workerLimit: workerLimit) else {
            let frontier = rangeMap.contiguousFrontier(from: schedulerAnchorByte)
            lock.unlock()
            if frontier >= schedulerLimit { DiagnosticsLogger.shared.log("KTVAdaptive", "contiguous target reached frontier=\(frontier) target=\(schedulerLimit)") }
            return
        }

        lane.generation &+= 1
        let generation = lane.generation
        lane.active = true
        lane.segmentStart = claim.lowerBound
        lane.segmentEnd = claim.upperBound - 1
        lane.loaded = 0
        lane.startedAt = Date()
        lane.cacheStart = itemCacheBytes
        lane.requestCount += 1
        if reason != "segment-retry" { lane.consecutiveFailureCount = 0 }
        rangeMap.setDownloading(claim, lane: laneID.rawValue)
        lastProgressAt = Date()
        lock.unlock()

        let segmentStart = claim.lowerBound
        let segmentEnd = claim.upperBound - 1
        let loader = EPLKTVCacheBridge.preload(
            url: originalURL,
            headers: headers,
            startOffset: segmentStart,
            endOffset: segmentEnd,
            progress: { [weak self, weak lane] loadedLength, _ in
                guard let self, let lane else { return }
                let cacheBytes = EPLKTVCacheBridge.cacheLength(for: self.originalURL)
                self.lock.lock()
                guard generation == lane.generation else { self.lock.unlock(); return }
                lane.loaded = max(lane.loaded, loadedLength)
                let availableEnd = min(claim.upperBound, claim.lowerBound + max(0, loadedLength))
                if availableEnd > claim.lowerBound { self.rangeMap.insertPlayback(claim.lowerBound..<availableEnd) }
                self.loadedBytes = max(self.loadedBytes, cacheBytes)
                self.lastProgressAt = Date()
                self.sampleSpeedLocked(now: Date())
                self.lock.unlock()
            },
            completion: { [weak self, weak lane] error in
                guard let self, let lane else { return }
                let cacheBytes = EPLKTVCacheBridge.cacheLength(for: self.originalURL)
                self.lock.lock()
                guard generation == lane.generation else { self.lock.unlock(); return }
                lane.active = false
                lane.loader = nil
                self.rangeMap.clearDownloading(lane: lane.id.rawValue)
                let elapsed = max(Date().timeIntervalSince(lane.startedAt), 0.001)
                let loaded = max(0, lane.loaded)
                let newCacheBytes = max(0, cacheBytes - lane.cacheStart)
                let cacheHit = newCacheBytes == 0
                let networkBytes = cacheHit ? 0 : min(newCacheBytes, loaded)
                let speed = networkBytes > 0 ? Double(networkBytes) / elapsed : 0
                let mixedCache = loaded > 0 && networkBytes > 0 && networkBytes < loaded / 2
                if let _ = error {
                    lane.failureCount += 1
                    lane.consecutiveFailureCount += 1
                } else {
                    lane.consecutiveFailureCount = 0
                    self.rangeMap.insertPlayback(claim)
                }
                self.loadedBytes = max(self.loadedBytes, cacheBytes)
                self.lastProgressAt = Date()
                let consecutiveFailures = lane.consecutiveFailureCount
                self.lock.unlock()

                if let error {
                    let nsError = error as NSError
                    let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
                    let underlyingSummary = underlying.map { "\($0.domain):\($0.code)" } ?? "none"
                    DiagnosticsLogger.shared.log("KTVAdaptive", "lane=\(lane.id.rawValue) segment failed range=\(segmentStart)-\(segmentEnd) loaded=\(loaded) networkBytes=\(networkBytes) speed=\(Int(speed))B/s errorDomain=\(nsError.domain) errorCode=\(nsError.code) underlying=\(underlyingSummary) error=\(error.localizedDescription)")
                    if lane.id == .secondary {
                        self.rejectDualLaneImmediately(reason: "secondary-error-\(nsError.code)")
                        self.scheduleAvailableWorkers(reason: "secondary-hole-returned-to-primary")
                    } else if consecutiveFailures <= 3 {
                        let delay = 0.75 * Double(consecutiveFailures)
                        DiagnosticsLogger.shared.log("KTVAdaptive", "lane=A retry count=\(consecutiveFailures) delayMs=\(Int(delay * 1000)) hole=\(segmentStart)-\(segmentEnd)")
                        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) { [weak self] in self?.scheduleAvailableWorkers(reason: "segment-retry") }
                    } else {
                        DiagnosticsLogger.shared.log("KTVAdaptive", "lane=A retry suspended consecutive=\(consecutiveFailures) reason=\(error.localizedDescription)")
                    }
                } else {
                    DiagnosticsLogger.shared.log("KTVAdaptive", "lane=\(lane.id.rawValue) segment finished range=\(segmentStart)-\(segmentEnd) cacheHit=\(cacheHit) mixedCache=\(mixedCache) newCache=\(newCacheBytes) networkBytes=\(networkBytes) loaded=\(loaded) speed=\(Int(speed))B/s")
                    self.scheduleAvailableWorkers(reason: "segment-next")
                }
            }
        )

        lock.lock()
        if generation == lane.generation { lane.loader = loader } else { loader.close() }
        lock.unlock()
        DiagnosticsLogger.shared.log("KTVAdaptive", "lane=\(laneID.rawValue) segment start reason=\(reason) range=\(segmentStart)-\(segmentEnd) adjacency=frontier-window")
    }

    private func schedulingUpperBoundLocked() -> Int64 {
        let desired = targetCacheBytes > 0 ? schedulerAnchorByte + targetCacheBytes : Int64.max
        return contentLength > 0 ? min(contentLength, desired) : desired
    }

    private func evaluateDualLaneLocked(now: Date, cacheBytes: Int64) -> DualLaneAction {
        guard now.timeIntervalSince(lastSeekAt) >= 2 else { return .none }
        let map = rangeMap.snapshot(anchor: schedulerAnchorByte, resourceLength: contentLength)
        guard map.frontierByte < schedulingUpperBoundLocked() else { return .none }
        let elapsed = now.timeIntervalSince(dualWindowStartedAt)
        switch dualPhase {
        case .singleBaseline:
            guard elapsed >= singleBaselineSeconds, primaryLane.active || map.frontierByte > schedulerAnchorByte else { return .none }
            let speed = Double(max(0, cacheBytes - dualWindowStartBytes)) / max(elapsed, 0.001)
            singleLaneBaselineSpeed = speed
            dualPhase = .dualTrial
            dualWindowStartedAt = now
            dualWindowStartBytes = cacheBytes
            dualTrialFailureBaseline = primaryLane.failureCount + secondaryLane.failureCount
            return .startTrial(singleSpeed: speed)
        case .dualTrial:
            guard elapsed >= dualTrialSeconds else { return .none }
            let dualSpeed = Double(max(0, cacheBytes - dualWindowStartBytes)) / max(elapsed, 0.001)
            let failures = primaryLane.failureCount + secondaryLane.failureCount - dualTrialFailureBaseline
            let improved = dualSpeed >= max(singleLaneBaselineSpeed * 1.12, singleLaneBaselineSpeed + 1_048_576)
            if failures == 0, improved {
                dualPhase = .dualKept
                return .keep(singleSpeed: singleLaneBaselineSpeed, dualSpeed: dualSpeed)
            }
            dualPhase = .dualRejected
            let reason = failures > 0 ? "failure-count-\(failures)" : "gain-below-12-percent"
            return .reject(singleSpeed: singleLaneBaselineSpeed, dualSpeed: dualSpeed, reason: reason)
        case .dualKept, .dualRejected:
            return .none
        }
    }

    private func performDualLaneAction(_ action: DualLaneAction) {
        switch action {
        case .none:
            return
        case .startTrial(let singleSpeed):
            DiagnosticsLogger.shared.log("KTVAdaptive", "adjacent dual trial start baseline=\(Int(singleSpeed))B/s rule=no-gap")
            scheduleAvailableWorkers(reason: "adjacent-dual-trial")
        case .keep(let singleSpeed, let dualSpeed):
            DiagnosticsLogger.shared.log("KTVAdaptive", "adjacent dual kept single=\(Int(singleSpeed))B/s dual=\(Int(dualSpeed))B/s gain=\(percentageGain(from: singleSpeed, to: dualSpeed))%")
        case .reject(let singleSpeed, let dualSpeed, let reason):
            DiagnosticsLogger.shared.log("KTVAdaptive", "adjacent dual rejected single=\(Int(singleSpeed))B/s dual=\(Int(dualSpeed))B/s gain=\(percentageGain(from: singleSpeed, to: dualSpeed))% reason=\(reason)")
            stopSecondaryLane(reason: reason)
            scheduleAvailableWorkers(reason: "dual-rejected-fill-hole")
        }
    }

    private func rejectDualLaneImmediately(reason: String) {
        lock.lock()
        guard !stopped, dualPhase == .dualTrial || dualPhase == .dualKept else { lock.unlock(); return }
        dualPhase = .dualRejected
        lock.unlock()
        stopSecondaryLane(reason: reason)
    }

    private func stopSecondaryLane(reason: String) {
        lock.lock()
        secondaryLane.generation &+= 1
        let loader = secondaryLane.loader
        secondaryLane.loader = nil
        secondaryLane.active = false
        rangeMap.clearDownloading(lane: LaneID.secondary.rawValue)
        lock.unlock()
        loader?.close()
        DiagnosticsLogger.shared.log("KTVAdaptive", "dual lane stopped reason=\(reason)")
    }

    private func scheduleLargeMP4MetadataWarmup() {
        lock.lock()
        metadataGeneration &+= 1
        let generation = metadataGeneration
        lock.unlock()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.startLargeMP4MetadataWarmup(generation: generation)
        }
    }

    private func startLargeMP4MetadataWarmup(generation: UInt64) {
        let resourceLength = resolvedContentLength()
        guard resourceLength > 32 * 1_048_576 else { return }
        let tailBytes: Int64 = 16 * 1_048_576
        let start = max(0, resourceLength - tailBytes)
        let end = resourceLength - 1
        let started = Date()
        let handle = EPLKTVCacheBridge.preload(
            url: originalURL,
            headers: headers,
            startOffset: start,
            endOffset: end,
            progress: { [weak self] loadedLength, _ in
                guard let self else { return }
                self.lock.lock()
                guard generation == self.metadataGeneration else { self.lock.unlock(); return }
                let upper = min(end + 1, start + max(0, loadedLength))
                if upper > start { self.rangeMap.insertMetadata(start..<upper) }
                self.lastProgressAt = Date()
                self.lock.unlock()
            },
            completion: { [weak self] error in
                guard let self else { return }
                self.lock.lock()
                guard generation == self.metadataGeneration else { self.lock.unlock(); return }
                if error == nil { self.rangeMap.insertMetadata(start..<(end + 1)) }
                self.metadataHandle = nil
                self.lastProgressAt = Date()
                self.lock.unlock()
                DiagnosticsLogger.shared.log("KTVMetadata", "tail range=\(start)-\(end) ms=\(Int(Date().timeIntervalSince(started) * 1000)) error=\(error?.localizedDescription ?? "none")")
            }
        )
        lock.lock()
        guard generation == metadataGeneration, !stopped else { lock.unlock(); handle.close(); return }
        metadataHandle?.close()
        metadataHandle = handle
        lock.unlock()
        DiagnosticsLogger.shared.log("KTVMetadata", "tail preload start range=\(start)-\(end) classification=metadata-not-playable")
    }

    private func percentageGain(from baseline: Double, to value: Double) -> Int {
        guard baseline > 0 else { return value > 0 ? 100 : 0 }
        return Int(((value / baseline) - 1) * 100)
    }

    private func resolvedContentLength() -> Int64 {
        lock.lock()
        let bytes = contentLength
        lock.unlock()
        return bytes
    }

    private func updateResolvedResource(_ resource: TransportResolvedResource) {
        lock.lock()
        if resource.contentLength > 0 {
            contentLength = max(contentLength, resource.contentLength)
            targetCacheBytes = min(contentLength, cacheBudgetBytes)
        }
        lock.unlock()
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

    private func probeOriginInBackground() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let started = Date()
                let resource = try await RedirectResolver().resolve(source: self.source)
                let elapsedMs = Int(Date().timeIntervalSince(started) * 1_000)
                self.updateResolvedResource(resource)
                DiagnosticsLogger.shared.log("KTVOrigin", "probe finalHost=\(resource.finalURL.host ?? "unknown") redirects=\(resource.redirectCount) bytes=\(resource.contentLength) range=\(resource.supportsByteRanges) ms=\(elapsedMs) \(NetworkPathMonitor.shared.diagnosticSummary)")
            } catch {
                DiagnosticsLogger.shared.log("KTVOrigin", "probe failed error=\(error.localizedDescription) \(NetworkPathMonitor.shared.diagnosticSummary)")
            }
        }
    }

    private func laneSummaryLocked(_ lane: LaneState) -> String {
        guard lane.active else { return "idle" }
        return "\(lane.segmentStart)-\(lane.segmentEnd):\(lane.loaded)"
    }
}
