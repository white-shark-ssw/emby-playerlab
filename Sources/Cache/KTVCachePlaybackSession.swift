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
        var nextOffset: Int64 = 0
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
    private let cacheBudgetBytes: Int64
    private let baselineCacheBytes: Int64
    private let lock = NSLock()
    private let segmentBytes: Int64 = 32 * 1_048_576
    private let secondaryLeadBytes: Int64 = 96 * 1_048_576
    private let seekDebounceInterval: TimeInterval = 0.75
    private let singleBaselineSeconds: TimeInterval = 10
    private let dualTrialSeconds: TimeInterval = 15
    private let foregroundYieldSeconds: TimeInterval = 3
    private let primaryLane = LaneState(id: .primary)
    private let secondaryLane = LaneState(id: .secondary)

    private var contentLength: Int64
    private var targetCacheBytes: Int64
    private var mediaBytesPerSecond: Double
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
    private var completed = false
    private var lastProgressAt = Date()
    private var slowSince: Date?
    private var lastRotationAt = Date.distantPast
    private var stopped = false
    private var initialPreloadStarted = false
    private var playbackPreparationStarted = false
    private var playbackPreparationFinished = false
    private var playbackPreparationCallbacks: [() -> Void] = []
    private var foregroundPriorityUntil = Date.distantPast
    private var foregroundResumeOffset: Int64 = 0
    private var foregroundResumeSecondary = false
    private var foregroundResumeWorkItem: DispatchWorkItem?

    private var warmupGeneration: UInt64 = 0
    private var warmupRemaining = 0
    private var warmupHandles: [EPLKTVPreloadHandle] = []
    private var warmupCompletion: (() -> Void)?

    private var dualPhase: DualLanePhase = .singleBaseline
    private var dualWindowStartedAt = Date()
    private var dualWindowStartBytes: Int64 = 0
    private var singleLaneBaselineSpeed: Double = 0
    private var dualTrialFailureBaseline = 0

    init(source: ResolvedPlaybackSource, configuration: MediaTransportConfiguration) throws {
        self.source = source
        self.originalURL = source.url
        self.headers = source.headers
        self.configuration = configuration
        self.contentLength = max(source.mediaSource.size ?? 0, 0)
        let duration = max(source.mediaSource.durationSeconds ?? 0, 1)
        self.mediaBytesPerSecond = contentLength > 0 ? Double(contentLength) / duration : 2 * 1_048_576
        let cacheBytes = configuration.diskLimitBytes > 0 ? configuration.diskLimitBytes : 2 * 1_073_741_824
        self.cacheBudgetBytes = cacheBytes
        self.targetCacheBytes = contentLength > 0 ? min(contentLength, cacheBytes) : cacheBytes
        if let error = EPLKTVCacheBridge.start(maxCacheLength: cacheBytes, allowedHeaderKeys: Array(source.headers.keys)) { throw error }
        self.proxyURL = EPLKTVCacheBridge.proxyURL(for: source.url)
        self.baselineCacheBytes = EPLKTVCacheBridge.cacheLength(for: source.url)
        self.loadedBytes = self.baselineCacheBytes
        self.lastSampleBytes = self.baselineCacheBytes
        self.dualWindowStartBytes = self.baselineCacheBytes
        DiagnosticsLogger.shared.log(
            "KTVCache",
            "proxy started originalHost=\(source.url.host ?? "unknown") proxyPort=\(proxyURL.port ?? 0) cacheBudget=\(cacheBytes)B target=\(targetCacheBytes)B segment=\(segmentBytes)B lanes=adaptive-1x2 \(NetworkPathMonitor.shared.diagnosticSummary)"
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
        if playbackPreparationStarted { lock.unlock(); return }
        playbackPreparationStarted = true
        lock.unlock()

        let duration = source.mediaSource.durationSeconds ?? 0
        let isLargeMP4 = source.mediaSource.normalizedContainer == "mp4" && (contentLength >= 4 * 1_073_741_824 || duration >= 3_600)
        if isLargeMP4 {
            DiagnosticsLogger.shared.log("KTVOpenWarmup", "begin item=\(source.itemId) knownBytes=\(contentLength) duration=\(duration)")
            Task { [weak self] in
                guard let self else { return }
                do {
                    let startedAt = Date()
                    let resource = try await RedirectResolver().resolve(source: self.source)
                    let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
                    self.updateResolvedResource(resource)
                    DiagnosticsLogger.shared.log("KTVOrigin", "probe finalHost=\(resource.finalURL.host ?? "unknown") redirects=\(resource.redirectCount) bytes=\(resource.contentLength) range=\(resource.supportsByteRanges) ms=\(elapsedMs) \(NetworkPathMonitor.shared.diagnosticSummary)")
                    self.startLargeMP4Warmup(resourceLength: resource.contentLength) { [weak self] in self?.finishPlaybackPreparation() }
                } catch {
                    DiagnosticsLogger.shared.log("KTVOpenWarmup", "origin resolve failed error=\(error.localizedDescription); continue without tail warmup")
                    self.startInitialPreloadOnce()
                    self.finishPlaybackPreparation()
                }
            }
        } else {
            startInitialPreloadOnce()
            finishPlaybackPreparation()
            probeOriginInBackground()
        }
    }

    private func finishPlaybackPreparation() {
        lock.lock()
        guard !stopped, !playbackPreparationFinished else { lock.unlock(); return }
        playbackPreparationFinished = true
        let callbacks = playbackPreparationCallbacks
        playbackPreparationCallbacks.removeAll()
        lock.unlock()
        DispatchQueue.main.async { callbacks.forEach { $0() } }
    }

    func stop() {
        lock.lock()
        guard !stopped else { lock.unlock(); return }
        stopped = true
        seekDebounceWorkItem?.cancel()
        seekDebounceWorkItem = nil
        foregroundResumeWorkItem?.cancel()
        foregroundResumeWorkItem = nil
        warmupGeneration &+= 1
        let warmups = warmupHandles
        warmupHandles.removeAll()
        warmupCompletion = nil
        playbackPreparationCallbacks.removeAll()
        primaryLane.generation &+= 1
        secondaryLane.generation &+= 1
        let primary = primaryLane.loader
        let secondary = secondaryLane.loader
        primaryLane.loader = nil
        secondaryLane.loader = nil
        primaryLane.active = false
        secondaryLane.active = false
        lock.unlock()
        warmups.forEach { $0.close() }
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
        let resourceBytes = resolvedContentLength()
        guard resourceBytes > 0, duration.isFinite, duration > 0 else {
            ensurePreloadActive(reason: "seek without byte map")
            return
        }
        let ratio = min(max(position / duration, 0), 1)
        let rawOffset = Int64(Double(resourceBytes) * ratio)
        let alignedOffset = max(0, min(resourceBytes - 1, rawOffset / 1_048_576 * 1_048_576))

        lock.lock()
        playbackPosition = max(0, position)
        playbackDuration = duration
        lastSeekAt = Date()
        wrappedToStart = false
        seekDebounceWorkItem?.cancel()
        seekDebounceGeneration &+= 1
        let generation = seekDebounceGeneration
        let targetCoveredByActiveLane = laneContainsOffsetLocked(primaryLane, alignedOffset) || laneContainsOffsetLocked(secondaryLane, alignedOffset)
        let work = DispatchWorkItem { [weak self] in self?.commitSeekPriority(position: position, duration: duration, alignedOffset: alignedOffset, generation: generation) }
        seekDebounceWorkItem = targetCoveredByActiveLane ? nil : work
        lock.unlock()

        if targetCoveredByActiveLane {
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
        let targetCoveredByActiveLane = laneContainsOffsetLocked(primaryLane, alignedOffset) || laneContainsOffsetLocked(secondaryLane, alignedOffset)
        lock.unlock()
        guard !targetCoveredByActiveLane else {
            DiagnosticsLogger.shared.log("KTVAdaptive", "seek final target covered position=\(position) byte=\(alignedOffset)")
            return
        }
        let start = firstMissingOffset(from: alignedOffset)
        DiagnosticsLogger.shared.log("KTVAdaptive", "seek reprioritize final position=\(position) duration=\(duration) byte=\(alignedOffset) start=\(start)")
        startLane(.primary, reason: "seek-priority-final", startOffset: start)
    }

    func yieldBandwidthToPlayback(position: Double, duration: Double, reason: String) {
        let now = Date()
        let until = now.addingTimeInterval(foregroundYieldSeconds)

        lock.lock()
        guard !stopped else { lock.unlock(); return }
        playbackPosition = max(0, position)
        if duration.isFinite, duration > 0 { playbackDuration = duration }
        if until > foregroundPriorityUntil { foregroundPriorityUntil = until }

        let wasAlreadyYielding = foregroundResumeWorkItem != nil
        let primaryOffset = primaryLane.active ? min(primaryLane.segmentEnd + 1, primaryLane.segmentStart + max(0, primaryLane.loaded)) : primaryLane.nextOffset
        foregroundResumeOffset = max(foregroundResumeOffset, primaryOffset)
        foregroundResumeSecondary = foregroundResumeSecondary || dualPhase == .dualTrial || dualPhase == .dualKept
        if dualPhase == .dualTrial {
            dualPhase = .singleBaseline
            dualWindowStartedAt = now
            dualWindowStartBytes = EPLKTVCacheBridge.cacheLength(for: originalURL)
        }

        primaryLane.generation &+= 1
        secondaryLane.generation &+= 1
        let primary = primaryLane.loader
        let secondary = secondaryLane.loader
        primaryLane.loader = nil
        secondaryLane.loader = nil
        primaryLane.active = false
        secondaryLane.active = false
        slowSince = nil

        if !wasAlreadyYielding {
            let work = DispatchWorkItem { [weak self] in self?.resumeBackgroundAfterForegroundPriority() }
            foregroundResumeWorkItem = work
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + foregroundYieldSeconds, execute: work)
        }
        lock.unlock()

        primary?.close()
        secondary?.close()
        if !wasAlreadyYielding {
            DiagnosticsLogger.shared.log("KTVAdaptive", "foreground priority reason=\(reason) position=\(position) pauseMs=\(Int(foregroundYieldSeconds * 1000))")
        }
    }

    private func resumeBackgroundAfterForegroundPriority() {
        lock.lock()
        guard !stopped, foregroundResumeWorkItem != nil else { lock.unlock(); return }
        let remaining = foregroundPriorityUntil.timeIntervalSinceNow
        if remaining > 0 {
            let work = DispatchWorkItem { [weak self] in self?.resumeBackgroundAfterForegroundPriority() }
            foregroundResumeWorkItem = work
            lock.unlock()
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + remaining, execute: work)
            return
        }
        foregroundResumeWorkItem = nil
        let primaryOffset = foregroundResumeOffset
        let resumeSecondary = foregroundResumeSecondary && dualPhase == .dualKept
        foregroundResumeOffset = 0
        foregroundResumeSecondary = false
        lock.unlock()

        let primaryStart = firstMissingOffset(from: primaryOffset)
        DiagnosticsLogger.shared.log("KTVAdaptive", "foreground priority ended primaryRestart=\(primaryStart) secondary=\(resumeSecondary)")
        startLane(.primary, reason: "foreground-resume", startOffset: primaryStart)
        if resumeSecondary {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self else { return }
                self.startLane(.secondary, reason: "foreground-resume", startOffset: self.firstMissingOffset(from: primaryStart + self.secondaryLeadBytes))
            }
        }
    }

    func ensurePreloadActive(reason: String) {
        lock.lock()
        let noProgressSeconds = Date().timeIntervalSince(lastProgressAt)
        let shouldRestart = !completed && (!primaryLane.active || noProgressSeconds > 8)
        let restartOffset = primaryLane.active ? min(primaryLane.segmentEnd + 1, max(primaryLane.segmentStart, primaryLane.segmentStart + primaryLane.loaded)) : primaryLane.nextOffset
        lock.unlock()
        guard shouldRestart else { return }
        startLane(.primary, reason: reason, startOffset: firstMissingOffset(from: restartOffset))
    }

    func metrics() -> TransportMetricsSnapshot {
        let itemCacheBytes = EPLKTVCacheBridge.cacheLength(for: originalURL)
        let resourceBytes = max(resolvedContentLength(), EPLKTVCacheBridge.resourceLength(for: originalURL))
        let now = Date()

        lock.lock()
        loadedBytes = max(loadedBytes, itemCacheBytes)
        sampleSpeedLocked(now: now)
        evaluateSlowConnectionLocked(now: now)
        let dualAction = evaluateDualLaneLocked(now: now, cacheBytes: itemCacheBytes)
        let bytes = loadedBytes
        let speed = currentBytesPerSecond
        let activeRequests = (primaryLane.active ? 1 : 0) + (secondaryLane.active ? 1 : 0) + (warmupRemaining > 0 ? warmupRemaining : 0)
        let failures = primaryLane.failureCount + secondaryLane.failureCount
        let requests = primaryLane.requestCount + secondaryLane.requestCount
        let elapsed = max(now.timeIntervalSince(startedAt), 0.001)
        let playbackByte = byteOffsetLocked(position: playbackPosition, duration: playbackDuration, resourceBytes: resourceBytes)
        let trackedContiguous = sessionRanges.contiguousLength(from: playbackByte, maximumLength: max(0, resourceBytes - playbackByte))
        let shouldRestart = slowSince != nil && now.timeIntervalSince(slowSince ?? now) >= 12 && now.timeIntervalSince(lastRotationAt) >= 20
        let restartOffset = min(primaryLane.segmentEnd + 1, max(primaryLane.segmentStart, primaryLane.segmentStart + primaryLane.loaded))
        lock.unlock()

        performDualLaneAction(dualAction)
        if shouldRestart { restartSlowPrimary(from: restartOffset, observedSpeed: speed) }

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
            contiguousCacheBytes: trackedContiguous,
            currentDownloadBytesPerSecond: speed,
            elapsedSeconds: elapsed
        )
    }

    private func startInitialPreloadOnce() {
        lock.lock()
        guard !initialPreloadStarted, !stopped else { lock.unlock(); return }
        initialPreloadStarted = true
        dualWindowStartedAt = Date()
        dualWindowStartBytes = EPLKTVCacheBridge.cacheLength(for: originalURL)
        lock.unlock()
        startLane(.primary, reason: "initial", startOffset: firstMissingOffset(from: 0))
    }

    private func startLane(_ laneID: LaneID, reason: String, startOffset: Int64) {
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
        if Date() < foregroundPriorityUntil { lock.unlock(); return }
        if laneID == .secondary, dualPhase != .dualTrial, dualPhase != .dualKept { lock.unlock(); return }
        if targetCacheBytes > 0, itemCacheBytes >= max(0, targetCacheBytes - 1_048_576) {
            completed = true
            primaryLane.generation &+= 1
            secondaryLane.generation &+= 1
            primaryLane.active = false
            secondaryLane.active = false
            let primary = primaryLane.loader
            let secondary = secondaryLane.loader
            primaryLane.loader = nil
            secondaryLane.loader = nil
            lock.unlock()
            primary?.close()
            secondary?.close()
            DiagnosticsLogger.shared.log("KTVAdaptive", "cache target reached cached=\(itemCacheBytes) target=\(targetCacheBytes)")
            return
        }

        let lane = laneID == .primary ? primaryLane : secondaryLane
        var offset = max(0, startOffset)
        let resourceBytes = contentLength
        if resourceBytes > 0, offset >= resourceBytes {
            if laneID == .primary, !wrappedToStart {
                wrappedToStart = true
                offset = 0
            } else {
                lane.active = false
                if laneID == .primary { completed = secondaryLane.active == false }
                lock.unlock()
                DiagnosticsLogger.shared.log("KTVAdaptive", "lane=\(laneID.rawValue) traversal finished cached=\(itemCacheBytes) completeFile=\(EPLKTVCacheBridge.completeFileURL(for: originalURL) != nil)")
                return
            }
        }

        offset = adjustedOffsetAvoidingOtherLaneLocked(offset, laneID: laneID)
        if resourceBytes > 0, offset >= resourceBytes {
            if laneID == .primary, !wrappedToStart {
                wrappedToStart = true
                offset = 0
            } else {
                lane.active = false
                lock.unlock()
                DiagnosticsLogger.shared.log("KTVAdaptive", "lane=\(laneID.rawValue) no non-overlapping range remains")
                return
            }
        }
        let endOffset = resourceBytes > 0 ? min(resourceBytes - 1, offset + segmentBytes - 1) : offset + segmentBytes - 1
        lane.generation &+= 1
        let generation = lane.generation
        let previous = lane.loader
        lane.loader = nil
        lane.active = true
        lane.segmentStart = offset
        lane.segmentEnd = endOffset
        lane.loaded = 0
        lane.startedAt = Date()
        lane.cacheStart = itemCacheBytes
        lane.nextOffset = endOffset + 1
        lane.requestCount += 1
        if reason != "segment-retry" && reason != "secondary-retry" { lane.consecutiveFailureCount = 0 }
        lastProgressAt = Date()
        if laneID == .primary { slowSince = nil }
        lock.unlock()
        previous?.close()

        let segmentStart = offset
        let segmentEnd = endOffset
        let newLoader = EPLKTVCacheBridge.preload(
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
                let availableEnd = min(lane.segmentEnd + 1, lane.segmentStart + max(0, loadedLength))
                if availableEnd > lane.segmentStart { self.sessionRanges.insert(lane.segmentStart..<availableEnd) }
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
                let elapsed = max(Date().timeIntervalSince(lane.startedAt), 0.001)
                let loaded = max(0, lane.loaded)
                let newCacheBytes = max(0, cacheBytes - lane.cacheStart)
                let cacheHit = newCacheBytes == 0
                let networkBytes = cacheHit ? 0 : min(newCacheBytes, loaded)
                let speed = networkBytes > 0 ? Double(networkBytes) / elapsed : 0
                if error != nil {
                    lane.failureCount += 1
                    lane.consecutiveFailureCount += 1
                } else {
                    lane.consecutiveFailureCount = 0
                    if lane.segmentEnd >= lane.segmentStart { self.sessionRanges.insert(lane.segmentStart..<(lane.segmentEnd + 1)) }
                }
                self.loadedBytes = max(self.loadedBytes, cacheBytes)
                let next = lane.nextOffset
                let continueLane = lane.id == .primary || self.dualPhase == .dualTrial || self.dualPhase == .dualKept
                self.lock.unlock()

                if let error {
                    DiagnosticsLogger.shared.log("KTVAdaptive", "lane=\(lane.id.rawValue) segment failed range=\(segmentStart)-\(segmentEnd) loaded=\(loaded) networkBytes=\(networkBytes) speed=\(Int(speed))B/s error=\(error.localizedDescription)")
                    let retryOffset = segmentStart + loaded
                    if lane.id == .secondary {
                        if lane.consecutiveFailureCount <= 1 {
                            DiagnosticsLogger.shared.log("KTVAdaptive", "lane=B transient retry count=\(lane.consecutiveFailureCount) restart=\(retryOffset)")
                            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.75) { [weak self] in
                                guard let self else { return }
                                self.startLane(.secondary, reason: "secondary-retry", startOffset: self.firstMissingOffset(from: retryOffset))
                            }
                        } else {
                            self.rejectDualLaneImmediately(reason: "secondary-error-\(error.localizedDescription)")
                        }
                    } else if lane.consecutiveFailureCount <= 3 {
                        let delay = 0.75 * Double(lane.consecutiveFailureCount)
                        DiagnosticsLogger.shared.log("KTVAdaptive", "lane=A retry count=\(lane.consecutiveFailureCount) delayMs=\(Int(delay * 1000)) restart=\(retryOffset)")
                        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) { [weak self] in
                            guard let self else { return }
                            self.startLane(.primary, reason: "segment-retry", startOffset: self.firstMissingOffset(from: retryOffset))
                        }
                    } else {
                        DiagnosticsLogger.shared.log("KTVAdaptive", "lane=A retry suspended consecutive=\(lane.consecutiveFailureCount) reason=\(error.localizedDescription)")
                    }
                } else {
                    DiagnosticsLogger.shared.log("KTVAdaptive", "lane=\(lane.id.rawValue) segment finished range=\(segmentStart)-\(segmentEnd) cacheHit=\(cacheHit) newCache=\(newCacheBytes) networkBytes=\(networkBytes) loaded=\(loaded) speed=\(Int(speed))B/s next=\(next)")
                    if continueLane {
                        DispatchQueue.global(qos: .utility).async { [weak self] in
                            guard let self else { return }
                            self.startLane(lane.id, reason: "segment-next", startOffset: self.firstMissingOffset(from: next))
                        }
                    }
                }
            }
        )

        lock.lock()
        if generation == lane.generation { lane.loader = newLoader }
        else { newLoader.close() }
        lock.unlock()
        DiagnosticsLogger.shared.log("KTVAdaptive", "lane=\(laneID.rawValue) segment start reason=\(reason) range=\(segmentStart)-\(segmentEnd) size=\(segmentBytes)")
    }

    private func startSecondaryTrial(singleSpeed: Double) {
        lock.lock()
        guard !stopped, dualPhase == .dualTrial, !secondaryLane.active else { lock.unlock(); return }
        let resourceBytes = contentLength
        let playbackByte = byteOffsetLocked(position: playbackPosition, duration: playbackDuration, resourceBytes: resourceBytes)
        let primaryTail = primaryLane.active ? primaryLane.segmentEnd + 1 : primaryLane.nextOffset
        let preferred = max(primaryTail + secondaryLeadBytes, playbackByte + secondaryLeadBytes)
        lock.unlock()
        let start = firstMissingOffset(from: preferred)
        DiagnosticsLogger.shared.log("KTVAdaptive", "dual trial start baseline=\(Int(singleSpeed))B/s laneBStart=\(start) lead=\(secondaryLeadBytes)")
        startLane(.secondary, reason: "dual-trial", startOffset: start)
    }

    private func stopSecondaryLane(reason: String) {
        lock.lock()
        secondaryLane.generation &+= 1
        let loader = secondaryLane.loader
        secondaryLane.loader = nil
        secondaryLane.active = false
        lock.unlock()
        loader?.close()
        DiagnosticsLogger.shared.log("KTVAdaptive", "dual lane stopped reason=\(reason)")
    }

    private func evaluateDualLaneLocked(now: Date, cacheBytes: Int64) -> DualLaneAction {
        guard !completed, contentLength == 0 || targetCacheBytes > cacheBytes + 4 * segmentBytes else { return .none }
        guard now.timeIntervalSince(lastSeekAt) >= 3 else { return .none }
        let elapsed = now.timeIntervalSince(dualWindowStartedAt)
        switch dualPhase {
        case .singleBaseline:
            guard elapsed >= singleBaselineSeconds, primaryLane.active else { return .none }
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
            startSecondaryTrial(singleSpeed: singleSpeed)
        case .keep(let singleSpeed, let dualSpeed):
            DiagnosticsLogger.shared.log("KTVAdaptive", "dual lane kept single=\(Int(singleSpeed))B/s dual=\(Int(dualSpeed))B/s gain=\(percentageGain(from: singleSpeed, to: dualSpeed))%")
        case .reject(let singleSpeed, let dualSpeed, let reason):
            DiagnosticsLogger.shared.log("KTVAdaptive", "dual lane rejected single=\(Int(singleSpeed))B/s dual=\(Int(dualSpeed))B/s gain=\(percentageGain(from: singleSpeed, to: dualSpeed))% reason=\(reason)")
            stopSecondaryLane(reason: reason)
        }
    }

    private func rejectDualLaneImmediately(reason: String) {
        lock.lock()
        guard dualPhase == .dualTrial || dualPhase == .dualKept else { lock.unlock(); return }
        dualPhase = .dualRejected
        lock.unlock()
        stopSecondaryLane(reason: reason)
    }

    private func percentageGain(from baseline: Double, to value: Double) -> Int {
        guard baseline > 0 else { return value > 0 ? 100 : 0 }
        return Int(((value / baseline) - 1) * 100)
    }

    private func evaluateSlowConnectionLocked(now: Date) {
        guard primaryLane.active, now.timeIntervalSince(lastSeekAt) >= 2 else { slowSince = nil; return }
        let threshold = max(mediaBytesPerSecond * 0.9, 1 * 1_048_576)
        let noProgress = now.timeIntervalSince(lastProgressAt) >= 4
        let tooSlow = currentBytesPerSecond > 0 && currentBytesPerSecond < threshold
        if noProgress || tooSlow {
            if slowSince == nil { slowSince = now }
        } else {
            slowSince = nil
        }
    }

    private func restartSlowPrimary(from offset: Int64, observedSpeed: Double) {
        lock.lock()
        guard !stopped, primaryLane.active, Date().timeIntervalSince(lastRotationAt) >= 20, Date().timeIntervalSince(lastSeekAt) >= 2 else { lock.unlock(); return }
        lastRotationAt = Date()
        slowSince = nil
        lock.unlock()
        DiagnosticsLogger.shared.log("KTVAdaptive", "slow primary restart speed=\(Int(observedSpeed))B/s restart=\(offset) segment=\(segmentBytes)")
        startLane(.primary, reason: "slow-restart", startOffset: firstMissingOffset(from: offset))
    }

    private func laneContainsOffsetLocked(_ lane: LaneState, _ offset: Int64) -> Bool {
        guard lane.active, lane.loaded > 0 else { return false }
        let availableEnd = min(lane.segmentEnd + 1, lane.segmentStart + lane.loaded)
        return offset >= lane.segmentStart && offset < availableEnd
    }

    private func adjustedOffsetAvoidingOtherLaneLocked(_ offset: Int64, laneID: LaneID) -> Int64 {
        let other = laneID == .primary ? secondaryLane : primaryLane
        guard other.active else { return offset }
        let candidateEnd = offset + segmentBytes - 1
        if candidateEnd < other.segmentStart || offset > other.segmentEnd { return offset }
        return other.segmentEnd + 1
    }

    private func firstMissingOffset(from offset: Int64) -> Int64 {
        lock.lock()
        let upper = contentLength > 0 ? contentLength : Int64.max
        let missing = sessionRanges.firstMissingOffset(from: max(0, offset), upperBound: upper) ?? max(0, offset)
        lock.unlock()
        return missing
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
            let duration = max(source.mediaSource.durationSeconds ?? 0, 1)
            mediaBytesPerSecond = Double(contentLength) / duration
        }
        lock.unlock()
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

    private func probeOriginInBackground() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let startedAt = Date()
                let resource = try await RedirectResolver().resolve(source: self.source)
                let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
                self.updateResolvedResource(resource)
                DiagnosticsLogger.shared.log("KTVOrigin", "probe finalHost=\(resource.finalURL.host ?? "unknown") redirects=\(resource.redirectCount) bytes=\(resource.contentLength) range=\(resource.supportsByteRanges) ms=\(elapsedMs) \(NetworkPathMonitor.shared.diagnosticSummary)")
            } catch {
                DiagnosticsLogger.shared.log("KTVOrigin", "probe failed error=\(error.localizedDescription) \(NetworkPathMonitor.shared.diagnosticSummary)")
            }
        }
    }

    private func startLargeMP4Warmup(resourceLength: Int64, completion: @escaping () -> Void) {
        guard resourceLength > 32 * 1_048_576 else {
            startInitialPreloadOnce()
            DispatchQueue.main.async { completion() }
            return
        }

        let headBytes: Int64 = 8 * 1_048_576
        let tailBytes: Int64 = 16 * 1_048_576
        let ranges: [(String, Int64, Int64)] = [
            ("head", 0, headBytes - 1),
            ("tail", max(0, resourceLength - tailBytes), resourceLength - 1)
        ]

        lock.lock()
        warmupGeneration &+= 1
        let generation = warmupGeneration
        warmupRemaining = ranges.count
        warmupCompletion = completion
        lock.unlock()

        var handles: [EPLKTVPreloadHandle] = []
        for (name, start, end) in ranges {
            let startedAt = Date()
            let handle = EPLKTVCacheBridge.preload(
                url: originalURL,
                headers: headers,
                startOffset: start,
                endOffset: end,
                progress: nil,
                completion: { [weak self] error in
                    guard let self else { return }
                    let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
                    DiagnosticsLogger.shared.log("KTVOpenWarmup", "range=\(name) bytes=\(start)-\(end) ms=\(elapsedMs) error=\(error?.localizedDescription ?? "none")")
                    self.finishWarmupRange(generation: generation)
                }
            )
            handles.append(handle)
        }

        lock.lock()
        if generation == warmupGeneration { warmupHandles = handles }
        else { handles.forEach { $0.close() } }
        lock.unlock()

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 6) { [weak self] in
            self?.finishLargeMP4Warmup(generation: generation, reason: "timeout")
        }
    }

    private func finishWarmupRange(generation: UInt64) {
        lock.lock()
        guard generation == warmupGeneration, warmupRemaining > 0 else { lock.unlock(); return }
        warmupRemaining -= 1
        let done = warmupRemaining == 0
        lock.unlock()
        if done { finishLargeMP4Warmup(generation: generation, reason: "complete") }
    }

    private func finishLargeMP4Warmup(generation: UInt64, reason: String) {
        lock.lock()
        guard generation == warmupGeneration, let completion = warmupCompletion else { lock.unlock(); return }
        warmupGeneration &+= 1
        warmupRemaining = 0
        let handles = warmupHandles
        warmupHandles.removeAll()
        warmupCompletion = nil
        lock.unlock()
        handles.forEach { $0.close() }
        DiagnosticsLogger.shared.log("KTVOpenWarmup", "finished reason=\(reason) cached=\(EPLKTVCacheBridge.cacheLength(for: originalURL))")
        startInitialPreloadOnce()
        DispatchQueue.main.async { completion() }
    }
}
