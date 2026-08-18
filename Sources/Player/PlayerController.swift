import AVFoundation
import Combine
import Foundation
import QuartzCore
import UIKit

@MainActor
final class PlayerController: ObservableObject {
    @Published private(set) var snapshot = PlayerSnapshot()
    @Published private(set) var displayedPosition: Double = 0
    @Published private(set) var seekFeedback: String?
    @Published private(set) var scrubFeedback: String?
    @Published private(set) var lastSeekSummary = "尚未 Seek"
    @Published private(set) var prematureEOFMessage: String?
    @Published private(set) var stallMessage: String?
    @Published private(set) var engineKind: PlayerEngineKind
    @Published private(set) var transportSummary: String?
    @Published private(set) var transportCacheFraction: Double = 0
    @Published private(set) var transportCacheRanges: [ClosedRange<Double>] = []
    @Published private(set) var verifiedBufferedRanges: [ClosedRange<Double>] = []
    @Published private(set) var bufferState = PlaybackBufferState()

    @Published private(set) var source: ResolvedPlaybackSource

    private(set) var engine: PlayerEngine
    private let client: EmbyAPIClient
    private let orchestrator: PlaybackOrchestrator
    private let transportContext: PlaybackTransportContext?
    private var preferredForwardBuffer: Double = 90
    private var initialPlaybackTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?
    private var seekReportTask: Task<Void, Never>?
    private var seekAnchorReleaseTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var transportMetricsTask: Task<Void, Never>?
    private var engineSwitchTask: Task<Void, Never>?
    private var startupFallbackTask: Task<Void, Never>?
    private var engineSwitchInProgress = false
    private var engineTransitionAwaitingFirstSnapshot = false
    private var engineSwitchSerial: UInt64 = 0
    private var started = false
    private var playbackSessionStarted = false
    private var userWantsPlayback = false
    private var userIsScrubbing = false
    private var pendingSeekTarget: Double?
    private var pendingSeekDirection: SeekDirection?
    private var screenScrubStartPosition: Double?
    private var engineGeneration = 0
    private var eofRetryCount = 0
    private var stallRecoveryCount = 0
    private var lastWatchdogPosition: Double = 0
    private var lastWatchdogBufferEnd: Double = 0
    private var stagnantWatchdogIntervals = 0
    private var lastTransportMetrics: TransportMetricsSnapshot?
    private var lastHandledEngineError: String?
    private var lastBufferTimelineLogAt = Date.distantPast
    private var lastVerifiedMPVPosition: Double?
    private var stallWatchdogSuppressedUntil = Date.distantPast
    private var hasPlaybackAdvanced = false
    private var initialResumeConfirmationPending = false
    private var initialResumePlaybackBaseline: Double?

    var ksAVIOView: UIView? {
        #if canImport(KSPlayer)
        return (engine as? KSAVIOPlayerEngine)?.playerView
        #else
        return nil
        #endif
    }

    var avPlayer: AVPlayer? {
        if let engine = engine as? AVPlayerEngine { return engine.player }
        if let engine = engine as? KTVAVPlayerEngine { return engine.player }
        return nil
    }

    var mpvDisplayLayer: CAMetalLayer? {
        if let engine = engine as? MPVPlayerEngine { return engine.displayLayer }
        if let engine = engine as? KTVMPVPlayerEngine { return engine.displayLayer }
        return nil
    }

    init(source: ResolvedPlaybackSource, client: EmbyAPIClient, preference: PlayerEnginePreference) {
        self.source = source
        self.client = client
        let orchestrator = PlaybackOrchestrator(source: source, preference: preference)
        self.orchestrator = orchestrator
        let initialKind = orchestrator.currentKind
        let configuration = MediaTransportConfiguration.current()
        let transportContext: PlaybackTransportContext? = PlaybackTransportContext(source: source, client: client, configuration: configuration)
        self.transportContext = transportContext
        self.engineKind = initialKind
        if initialKind == .mpv { DiagnosticsLogger.shared.log("MPVLifecycle", "engine create begin item=\(source.itemId)") }
        self.engine = PlayerController.makeEngine(kind: initialKind, source: source, client: client, transportContext: transportContext)
        if initialKind == .mpv { DiagnosticsLogger.shared.log("MPVLifecycle", "engine create finished item=\(source.itemId)") }
        bindEngine()
    }

    func start(preferredForwardBuffer: Double) {
        guard !started else { return }
        started = true
        self.preferredForwardBuffer = preferredForwardBuffer > 0 ? preferredForwardBuffer : 90
        configureAudioSession()
        userWantsPlayback = true
        initialPlaybackTask?.cancel()
        initialPlaybackTask = Task { [weak self] in
            guard let self else { return }
            let startPosition = await self.resolveInitialPlaybackPosition()
            guard !Task.isCancelled, self.started else { return }
            if startPosition > 0.5, let session = self.transportContext?.session {
                await session.prepareInitialPlayback(position: startPosition, duration: self.source.mediaSource.durationSeconds ?? 0)
                guard !Task.isCancelled, self.started else { return }
            }
            self.initialPlaybackTask = nil
            self.startEngine(at: startPosition)
        }
    }

    private func resolveInitialPlaybackPosition() async -> Double {
        do {
            let item = try await client.libraryItem(itemId: source.itemId)
            guard item.isPlayed == false,
                  let ticks = item.userData?.playbackPositionTicks,
                  ticks > 0 else { return 0 }
            let seconds = Double(ticks) / AppIdentity.ticksPerSecond
            let duration = source.mediaSource.durationSeconds ?? item.durationSeconds ?? 0
            if duration > 0, seconds / duration >= 0.995 { return 0 }
            let resolved = duration > 0 ? min(max(0, seconds), duration) : max(0, seconds)
            DiagnosticsLogger.shared.playback("Resume", "item=\(source.itemId) position=\(String(format: "%.3f", resolved)) duration=\(String(format: "%.3f", duration))")
            return resolved
        } catch {
            DiagnosticsLogger.shared.playback("Resume", "item=\(source.itemId) userdata fetch failed: \(error.localizedDescription)")
            return 0
        }
    }

    private func startEngine(at startPosition: Double) {
        let position = max(0, startPosition)
        displayedPosition = position
        initialResumeConfirmationPending = position > 0.5
        initialResumePlaybackBaseline = nil
        suppressStallWatchdog(for: engineKind == .mpv ? 12 : 6)
        if engineKind == .mpv { DiagnosticsLogger.shared.log("MPVLifecycle", "prepare begin item=\(source.itemId)") }
        engine.prepare(url: source.url, headers: source.headers, preferredForwardBuffer: preferredForwardBuffer, startPosition: position)
        if engineKind == .mpv { DiagnosticsLogger.shared.log("MPVLifecycle", "prepare returned item=\(source.itemId)") }
        engine.play()
        if let session = transportContext?.session { Task { await session.setPlaybackAdvancing(true) } }
        playbackSessionStarted = true

        DiagnosticsLogger.shared.log(
            "Player",
            "Start item=\(source.itemId) title=\(source.itemName) engine=\(engineKind.title) mediaSource=\(source.mediaSource.id) container=\(source.mediaSource.container ?? "unknown") video=\(source.mediaSource.videoCodec ?? "unknown") audio=\(source.mediaSource.audioCodec ?? "unknown") startPosition=\(position) url=\(source.url.absoluteString)"
        )

        Task { await client.reportStart(source: source, position: position, paused: false) }

        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard let self, self.started, self.playbackSessionStarted else { return }
                await self.client.reportProgress(source: self.source, position: self.snapshot.position, paused: !self.snapshot.isPlaying)
            }
        }

        watchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self, self.started, self.playbackSessionStarted else { return }
                self.evaluatePlaybackStall()
            }
        }
        startTransportMetricsPolling()
    }

    func stop() {
        guard started else { return }
        started = false
        userWantsPlayback = false
        initialResumeConfirmationPending = false
        initialResumePlaybackBaseline = nil
        let shouldReportStop = playbackSessionStarted
        playbackSessionStarted = false
        DiagnosticsLogger.shared.log("Lifecycle", "player close requested engine=\(engineKind.title) position=\(snapshot.position)")

        initialPlaybackTask?.cancel()
        initialPlaybackTask = nil
        progressTask?.cancel()
        progressTask = nil
        watchdogTask?.cancel()
        watchdogTask = nil
        transportMetricsTask?.cancel()
        transportMetricsTask = nil
        transportSummary = nil
        transportCacheFraction = 0
        transportCacheRanges = []
        engineSwitchTask?.cancel()
        engineSwitchTask = nil
        startupFallbackTask?.cancel()
        startupFallbackTask = nil
        engineSwitchInProgress = false
        engineTransitionAwaitingFirstSnapshot = false
        EngineTransitionBreadcrumb.clear()
        seekReportTask?.cancel()
        seekReportTask = nil
        seekAnchorReleaseTask?.cancel()
        seekAnchorReleaseTask = nil
        feedbackTask?.cancel()
        feedbackTask = nil

        engineGeneration += 1
        engine.onSnapshot = nil
        engine.onSeekCompleted = nil

        let position = snapshot.position
        engine.stop()
        transportContext?.stop()

        if shouldReportStop {
            let stoppedSource = source
            let stoppedClient = client
            Task {
                let succeeded = await stoppedClient.reportStopped(source: stoppedSource, position: position)
                guard succeeded else { return }
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: EmbyUserDataChange.notification,
                        object: stoppedClient,
                        userInfo: [
                            EmbyUserDataChange.itemIDKey: stoppedSource.itemId,
                            EmbyUserDataChange.reasonKey: EmbyUserDataChange.playbackStoppedReason,
                        ]
                    )
                }
            }
        }

        pendingSeekTarget = nil
        pendingSeekDirection = nil
        screenScrubStartPosition = nil
        DiagnosticsLogger.shared.log("Lifecycle", "player close detached")
    }

    func togglePlayPause() {
        if userWantsPlayback {
            userWantsPlayback = false
            engine.pause()
            if let session = transportContext?.session { Task { await session.setPlaybackAdvancing(false) } }
            Task { await client.reportProgress(source: source, position: snapshot.position, paused: true, eventName: "Pause") }
        } else {
            userWantsPlayback = true
            engine.play()
            if let session = transportContext?.session { Task { await session.setPlaybackAdvancing(true) } }
            Task { await client.reportProgress(source: source, position: snapshot.position, paused: false, eventName: "Unpause") }
        }
    }

    func seek(by offset: Double) {
        seekAnchorReleaseTask?.cancel()
        seekAnchorReleaseTask = nil
        let base = pendingSeekTarget ?? snapshot.position
        let target = clampPosition(base + offset)
        pendingSeekTarget = target
        pendingSeekDirection = offset >= 0 ? .forward : .backward
        displayedPosition = target
        suppressStallWatchdog(for: 3)
        DiagnosticsLogger.shared.log("SeekAnchor", "offset=\(offset) base=\(base) target=\(target) enginePosition=\(snapshot.position)")
        engine.seek(to: target, direction: offset >= 0 ? .forward : .backward)
        #if MDK_LAB
        if engineKind == .ksAVIO { scheduleSeekAnchorRelease(expectedTarget: target) }
        #endif
        showSeekFeedback(offset: offset)
        scheduleSeekReport(position: pendingSeekTarget ?? target)
    }

    func beginScrubbing() {
        seekAnchorReleaseTask?.cancel()
        seekAnchorReleaseTask = nil
        pendingSeekTarget = nil
        pendingSeekDirection = nil
        userIsScrubbing = true
        screenScrubStartPosition = nil
    }

    func updateScrubbing(to value: Double) { displayedPosition = clampPosition(value) }
    func endScrubbing() { commitScrubbedPosition() }

    func beginScreenScrubbing() {
        seekAnchorReleaseTask?.cancel()
        seekAnchorReleaseTask = nil
        pendingSeekTarget = nil
        pendingSeekDirection = nil
        userIsScrubbing = true
        let start = snapshot.position
        screenScrubStartPosition = start
        displayedPosition = start
        scrubFeedback = "\(formatTime(start)) / \(formatTime(effectiveDuration))"
    }

    func updateScreenScrubbing(translationX: CGFloat, viewWidth: CGFloat) {
        guard let start = screenScrubStartPosition else { return }
        let duration = effectiveDuration
        let adjustableSpan = min(max(duration * 0.10, 60), 600)
        let delta = Double(translationX / max(viewWidth, 1)) * adjustableSpan
        let target = clampPosition(start + delta)
        displayedPosition = target
        let signedDelta = Int((target - start).rounded())
        let sign = signedDelta >= 0 ? "+" : ""
        scrubFeedback = "\(formatTime(target)) / \(formatTime(duration))\n\(sign)\(signedDelta) 秒"
    }

    func endScreenScrubbing() {
        guard screenScrubStartPosition != nil else { return }
        screenScrubStartPosition = nil
        scrubFeedback = nil
        commitScrubbedPosition()
    }

    func cancelScreenScrubbing() {
        screenScrubStartPosition = nil
        userIsScrubbing = false
        scrubFeedback = nil
        displayedPosition = snapshot.position
    }

    func switchEngine(to kind: PlayerEngineKind, reason: String = "用户切换") {
        guard kind != engineKind, !engineSwitchInProgress else { return }
        let resumePosition = clampPosition(pendingSeekTarget ?? snapshot.position)
        let shouldPlay = userWantsPlayback
        let previousKind = engineKind
        let previousEngine = engine
        engineSwitchInProgress = true
        engineTransitionAwaitingFirstSnapshot = true
        engineSwitchSerial &+= 1
        let serial = engineSwitchSerial
        EngineTransitionBreadcrumb.record(stage: "requested", from: previousKind, to: kind, position: resumePosition, reason: reason)
        DiagnosticsLogger.shared.log("Engine", "Switch requested \(previousKind.title) -> \(kind.title) reason=\(reason) position=\(resumePosition) serial=\(serial)")

        pendingSeekTarget = nil
        pendingSeekDirection = nil
        seekAnchorReleaseTask?.cancel()
        seekAnchorReleaseTask = nil
        transportMetricsTask?.cancel()
        transportMetricsTask = nil
        lastTransportMetrics = nil
        transportSummary = nil
        startupFallbackTask?.cancel()
        startupFallbackTask = nil

        engineGeneration += 1
        previousEngine.onSnapshot = nil
        previousEngine.onSeekCompleted = nil
        engine = SuspendedPlayerEngine(kind: previousKind)
        resetWatchdog()
        stallMessage = "正在自动切换到 \(kind.title)：\(reason)"
        EngineTransitionBreadcrumb.record(stage: "old-callbacks-detached", from: previousKind, to: kind, position: resumePosition, reason: reason)

        previousEngine.stop()
        EngineTransitionBreadcrumb.record(stage: "old-engine-stopped", from: previousKind, to: kind, position: resumePosition, reason: reason)

        engineSwitchTask?.cancel()
        engineSwitchTask = Task { [weak self] in
            guard let self else { return }
            if let transportContext = self.transportContext { await transportContext.quiesceConsumers() }
            guard !Task.isCancelled, self.started, self.engineSwitchSerial == serial else { return }
            EngineTransitionBreadcrumb.record(stage: "transport-quiesced", from: previousKind, to: kind, position: resumePosition, reason: reason)
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled, self.started, self.engineSwitchSerial == serial else { return }

            let nextEngine = Self.makeEngine(kind: kind, source: self.source, client: self.client, transportContext: self.transportContext)
            self.engine = nextEngine
            self.engineKind = kind
            self.orchestrator.didSwitch(to: kind)
            self.lastHandledEngineError = nil
            self.bindEngine()
            self.prematureEOFMessage = nil
            EngineTransitionBreadcrumb.record(stage: "new-engine-created", from: previousKind, to: kind, position: resumePosition, reason: reason)

            nextEngine.prepare(url: self.source.url, headers: self.source.headers, preferredForwardBuffer: self.preferredForwardBuffer, startPosition: resumePosition)
            if shouldPlay { nextEngine.play() }
            EngineTransitionBreadcrumb.record(stage: "prepare-called", from: previousKind, to: kind, position: resumePosition, reason: reason)
            DiagnosticsLogger.shared.log("Engine", "Switch prepare called \(previousKind.title) -> \(kind.title) serial=\(serial)")
            self.engineSwitchInProgress = false
            self.engineSwitchTask = nil
            self.startTransportMetricsPolling()
        }
    }

    func toggleEngine() {
        let next: PlayerEngineKind
        switch engineKind {
        case .transportAVPlayer: next = .mpv
        default: next = .transportAVPlayer
        }
        switchEngine(to: next)
    }

    var playbackControlIsPlaying: Bool { userWantsPlayback }
    var effectiveDuration: Double { max(snapshot.duration, source.mediaSource.durationSeconds ?? 0) }
    var bufferedEnd: Double { Self.bufferedEnd(for: snapshot) }
    var forwardBufferedDuration: Double { max(0, bufferedEnd - snapshot.position) }

    private static func bufferedEnd(for snapshot: PlayerSnapshot) -> Double {
        let tolerance = 0.05
        return snapshot.bufferedRanges.filter { $0.lowerBound <= snapshot.position + tolerance && $0.upperBound >= snapshot.position - tolerance }.map(\.upperBound).max() ?? snapshot.position
    }

    private func logBufferTimelineIfNeeded(_ value: PlayerSnapshot) {
        let now = Date()
        guard now.timeIntervalSince(lastBufferTimelineLogAt) >= 1 else { return }
        lastBufferTimelineLogAt = now
        let end = Self.bufferedEnd(for: value)
        let forward = max(0, end - value.position)
        let ranges = value.bufferedRanges.prefix(8).map { String(format: "%.2f-%.2f", $0.lowerBound, $0.upperBound) }.joined(separator: ",")
        let suffix = value.bufferedRanges.count > 8 ? ",..." : ""
        DiagnosticsLogger.shared.log("BufferTimeline", "engine=\(engineKind.title) position=\(String(format: "%.3f", value.position)) forwardPlayable=\(String(format: "%.3f", forward)) playableRanges=[\(ranges)\(suffix)] buffering=\(value.isBuffering)")
    }

    var verifiedBufferedEnd: Double { verifiedBufferedRanges.map(\.upperBound).max() ?? 0 }

    private func updatePlaybackBufferState(from value: PlayerSnapshot) {
        bufferState = PlaybackBufferState(livePlayableRanges: value.bufferedRanges, verifiedHistoryRanges: verifiedBufferedRanges, isBuffering: value.isBuffering, waitingReason: value.waitingReason)
    }

    private func updateVerifiedBufferedRanges(from value: PlayerSnapshot) {
        guard !value.bufferedRanges.isEmpty else { return }
        if engineKind == .mpv {
            guard value.bufferedRanges.contains(where: { $0.lowerBound <= value.position + 0.05 && $0.upperBound > value.position + 0.25 }) else { return }
            if let previous = lastVerifiedMPVPosition {
                let delta = value.position - previous
                guard delta > 0.03, delta < 2 else { lastVerifiedMPVPosition = value.position; return }
            } else {
                lastVerifiedMPVPosition = value.position
                return
            }
            lastVerifiedMPVPosition = value.position
        }
        let previous = verifiedBufferedRanges
        let merged = Self.mergeTimeRanges(previous + value.bufferedRanges)
        guard merged != previous else { return }
        verifiedBufferedRanges = merged
        let ranges = merged.prefix(8).map { String(format: "%.2f-%.2f", $0.lowerBound, $0.upperBound) }.joined(separator: ",")
        let suffix = merged.count > 8 ? ",..." : ""
        DiagnosticsLogger.shared.log("BufferHistory", "engine=\(engineKind.title) verifiedRanges=[\(ranges)\(suffix)] verifiedEnd=\(String(format: "%.2f", verifiedBufferedEnd)) count=\(merged.count)")
    }

    private static func mergeTimeRanges(_ ranges: [ClosedRange<Double>]) -> [ClosedRange<Double>] {
        let sorted = ranges.filter { $0.lowerBound.isFinite && $0.upperBound.isFinite && $0.upperBound > $0.lowerBound }.sorted { $0.lowerBound < $1.lowerBound }
        guard var current = sorted.first else { return [] }
        var result: [ClosedRange<Double>] = []
        for range in sorted.dropFirst() {
            if range.lowerBound <= current.upperBound + 1.0 { current = current.lowerBound...max(current.upperBound, range.upperBound) }
            else { result.append(current); current = range }
        }
        result.append(current)
        return result
    }

    private static func makeEngine(kind: PlayerEngineKind, source: ResolvedPlaybackSource, client: EmbyAPIClient, transportContext: PlaybackTransportContext?) -> PlayerEngine {
        let configuration = MediaTransportConfiguration.current()
        switch kind {
        case .ktvAVPlayer:
            return KTVAVPlayerEngine(source: source, configuration: configuration, cacheSession: nil)
        case .resourceLoaderAVPlayer:
            return AVPlayerEngine(kind: .resourceLoaderAVPlayer, transportSource: source, transportClient: client, transportConfiguration: configuration, sharedTransportSession: transportContext?.session)
        case .transportAVPlayer:
            return AVPlayerEngine(kind: .transportAVPlayer, transportSource: source, transportClient: client, transportConfiguration: configuration, sharedTransportSession: transportContext?.session)
        case .ksAVIO:
            #if canImport(KSPlayer)
            return KSAVIOPlayerEngine(source: source, client: client, configuration: configuration, sharedTransportSession: transportContext?.session, ktvCacheSession: nil)
            #else
            return SuspendedPlayerEngine(kind: .ksAVIO)
            #endif
        case .avPlayer:
            return AVPlayerEngine()
        case .mpv:
            return MPVPlayerEngine(sharedTransportSession: transportContext?.session)
        }
    }

    private func bindEngine() {
        engineGeneration += 1
        let generation = engineGeneration

        engine.onSnapshot = { [weak self] value in
            guard let self else { return }
            Task { @MainActor in
                guard generation == self.engineGeneration else { return }
                let wasEnd = self.snapshot.didReachEnd
                self.snapshot = value
                if value.position > 0.25 { self.hasPlaybackAdvanced = true }
                self.confirmInitialResumePlaybackIfNeeded(value)
                self.updateVerifiedBufferedRanges(from: value)
                self.updatePlaybackBufferState(from: value)
                self.logBufferTimelineIfNeeded(value)
                if self.engineTransitionAwaitingFirstSnapshot {
                    self.engineTransitionAwaitingFirstSnapshot = false
                    if let error = value.errorMessage, !error.isEmpty { DiagnosticsLogger.shared.log("Engine", "Switch first snapshot error engine=\(self.engineKind.title) error=\(error)") }
                    else { EngineTransitionBreadcrumb.clear(); DiagnosticsLogger.shared.log("Engine", "Switch first snapshot engine=\(self.engineKind.title) position=\(value.position)") }
                }

                if self.snapshotCanCompleteSeekAnchor, !self.userIsScrubbing, let pending = self.pendingSeekTarget, self.hasReachedPendingTarget(actual: value.position, target: pending) {
                    self.seekAnchorReleaseTask?.cancel()
                    self.seekAnchorReleaseTask = nil
                    self.pendingSeekTarget = nil
                    self.pendingSeekDirection = nil
                    self.displayedPosition = value.position
                    DiagnosticsLogger.shared.log("SeekAnchor", "reached target=\(pending) actual=\(value.position)")
                } else if !self.userIsScrubbing, self.pendingSeekTarget == nil {
                    self.displayedPosition = value.position
                }

                if let error = value.errorMessage, !error.isEmpty, error != self.lastHandledEngineError {
                    self.lastHandledEngineError = error
                    self.handleEngineError(error)
                }

                if value.didReachEnd && !wasEnd { self.handleEndEvent() }
            }
        }

        engine.onSeekCompleted = { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                guard generation == self.engineGeneration else { return }
                if let pending = self.pendingSeekTarget, abs(pending - result.target) < 0.01 {
                    self.seekAnchorReleaseTask?.cancel()
                    self.seekAnchorReleaseTask = nil
                    self.pendingSeekTarget = nil
                    self.pendingSeekDirection = nil
                    self.displayedPosition = result.actualPosition ?? pending
                    self.suppressStallWatchdog(for: 2.5)
                    DiagnosticsLogger.shared.log("SeekAnchor", "completed target=\(pending) actual=\(result.actualPosition ?? pending)")
                }
                let actualText = result.actualPosition.map { String(format: "%.2f", $0) } ?? "unknown"
                self.lastSeekSummary = String(format: "%.0fms · %@ · %@ · 目标 %.2fs / 实际 %@s", result.completionLatencyMs, result.bufferHit ? "缓存命中" : "缓存未命中", result.measurement, result.target, actualText)
                DiagnosticsLogger.shared.log("Seek", "engine=\(self.engineKind.title) target=\(result.target) actual=\(actualText) bufferHit=\(result.bufferHit) completionMs=\(result.completionLatencyMs) measurement=\(result.measurement)")
            }
        }
    }

    private func confirmInitialResumePlaybackIfNeeded(_ value: PlayerSnapshot) {
        guard initialResumeConfirmationPending, userWantsPlayback, value.isPlaying, !value.isBuffering, value.position.isFinite else { return }
        guard let baseline = initialResumePlaybackBaseline else {
            initialResumePlaybackBaseline = value.position
            DiagnosticsLogger.shared.playback("Resume", "playback confirmation baseline=\(String(format: "%.3f", value.position)) engine=\(engineKind.title)")
            return
        }
        if value.position < baseline - 0.5 {
            initialResumePlaybackBaseline = value.position
            return
        }
        guard value.position - baseline >= 0.15 else { return }
        initialResumeConfirmationPending = false
        initialResumePlaybackBaseline = nil
        DiagnosticsLogger.shared.playback("Resume", "playback advanced baseline=\(String(format: "%.3f", baseline)) current=\(String(format: "%.3f", value.position)) action=confirm-real-byte-head")
        if let session = transportContext?.session { Task { await session.confirmInitialResumePlayback() } }
    }

    private func commitScrubbedPosition() {
        userIsScrubbing = false
        let target = clampPosition(displayedPosition)
        pendingSeekTarget = target
        pendingSeekDirection = .absolute
        suppressStallWatchdog(for: 3)
        engine.seek(to: target, direction: .absolute)
        #if MDK_LAB
        if engineKind == .ksAVIO { scheduleSeekAnchorRelease(expectedTarget: target) }
        #endif
        Task { await client.reportProgress(source: source, position: target, paused: !snapshot.isPlaying, eventName: "TimeUpdate") }
    }

    private func scheduleSeekAnchorRelease(expectedTarget: Double) {
        seekAnchorReleaseTask?.cancel()
        seekAnchorReleaseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled, let pending = self.pendingSeekTarget, abs(pending - expectedTarget) < 0.01 else { return }
            self.pendingSeekTarget = nil
            self.pendingSeekDirection = nil
            self.displayedPosition = self.snapshot.position
            DiagnosticsLogger.shared.log("SeekAnchor", "timeout target=\(expectedTarget) actual=\(self.snapshot.position)")
        }
    }


    private var snapshotCanCompleteSeekAnchor: Bool {
        #if MDK_LAB
        return engineKind != .mpv && engineKind != .ksAVIO
        #else
        return engineKind != .mpv
        #endif
    }

    private func hasReachedPendingTarget(actual: Double, target: Double) -> Bool {
        switch pendingSeekDirection {
        case .forward: return actual >= target - 0.25
        case .backward: return actual <= target + 0.25
        case .absolute: return abs(actual - target) <= 0.40
        case .none: return false
        }
    }

    private func scheduleSeekReport(position: Double) {
        seekReportTask?.cancel()
        seekReportTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard let self, !Task.isCancelled else { return }
            await self.client.reportProgress(source: self.source, position: position, paused: !self.snapshot.isPlaying, eventName: "TimeUpdate")
        }
    }

    private func handleEndEvent() {
        let decision = PrematureEOFGuard.evaluate(current: snapshot.position, avDuration: snapshot.duration, embyDuration: source.mediaSource.durationSeconds)
        DiagnosticsLogger.shared.log("EOF", "engine=\(engineKind.title) premature=\(decision.isPremature) reason=\(decision.reason) current=\(snapshot.position) engineDuration=\(snapshot.duration) embyDuration=\(source.mediaSource.durationSeconds ?? 0)")

        guard decision.isPremature else {
            userWantsPlayback = false
            if let session = transportContext?.session { Task { await session.setPlaybackAdvancing(false) } }
            let stoppedSource = source
            let stoppedClient = client
            let stoppedPosition = snapshot.position
            Task {
                let succeeded = await stoppedClient.reportStopped(source: stoppedSource, position: stoppedPosition)
                guard succeeded else { return }
                await MainActor.run {
                    NotificationCenter.default.post(name: EmbyUserDataChange.notification, object: stoppedClient, userInfo: [EmbyUserDataChange.itemIDKey: stoppedSource.itemId, EmbyUserDataChange.reasonKey: EmbyUserDataChange.playbackStoppedReason])
                }
            }
            return
        }

        switch orchestrator.actionForPrematureEOF(kind: engineKind, reason: decision.reason) {
        case .switchEngine(let next, let reason): prematureEOFMessage = "\(decision.reason)；App 正在自动切换到 \(next.title)。"; switchEngine(to: next, reason: reason)
        case .reloadCurrent(let reason): prematureEOFMessage = reason; engine.reload(at: snapshot.position); engine.play()
        case .recoverTransport(let message), .wait(let message): prematureEOFMessage = message; engine.recoverStall(position: snapshot.position, duration: effectiveDuration)
        }
    }

    private func handleEngineError(_ message: String) {
        guard !engineSwitchInProgress, !engineTransitionAwaitingFirstSnapshot else { return }
        if scheduleStartupCompatibilityFallbackIfNeeded(message: message) { return }
        guard let action = orchestrator.actionForEngineError(kind: engineKind, message: message) else { return }
        if case .switchEngine(let next, let reason) = action { stallMessage = "\(engineKind.title) 发生错误，正在自动切换到 \(next.title)。"; switchEngine(to: next, reason: reason) }
    }

    private func scheduleStartupCompatibilityFallbackIfNeeded(message: String) -> Bool {
        let normalized = message.lowercased()
        let startupAVKinds: Set<PlayerEngineKind> = [.ktvAVPlayer, .resourceLoaderAVPlayer, .transportAVPlayer]
        guard orchestrator.automaticMode, startupAVKinds.contains(engineKind), source.mediaSource.normalizedContainer == "mp4", snapshot.position < 1, normalized.contains("cannot open") || normalized.contains("无法打开") else { return false }
        guard startupFallbackTask == nil else { return true }
        DiagnosticsLogger.shared.log("StartupFallback", "armed item=\(source.itemId) error=\(message) position=\(snapshot.position)")
        stallMessage = "AVPlayer 无法打开此视频，正在确认下载链路后使用兼容播放器重新打开。"

        startupFallbackTask = Task { [weak self] in
            guard let self else { return }
            for attempt in 1...6 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, self.started, startupAVKinds.contains(self.engineKind), self.snapshot.position < 1 else { self.startupFallbackTask = nil; return }
                let metrics = self.lastTransportMetrics
                let healthyBytes = metrics?.bytesDownloaded ?? 0
                let cacheBytes = metrics?.cacheBytes ?? 0
                let speed = metrics?.currentDownloadBytesPerSecond ?? 0
                let active = metrics?.activeRequestCount ?? 0
                let transportHealthy = healthyBytes >= 16 * 1_048_576 || cacheBytes >= 32 * 1_048_576 || (active > 0 && speed >= 2 * 1_048_576)
                DiagnosticsLogger.shared.log("StartupFallback", "check item=\(self.source.itemId) attempt=\(attempt) downloaded=\(healthyBytes) cache=\(cacheBytes) speed=\(Int(speed))B/s active=\(active) healthy=\(transportHealthy)")
                guard transportHealthy else { continue }
                MediaCompatibilityStore.markCompatibilityEngineRequired(itemId: self.source.itemId, reason: "avplayer-startup-cannot-open")
                self.stallMessage = "媒体数据下载正常，但 AVPlayer 无法打开容器；正在从当前播放点使用 高兼容引擎重新打开。"
                self.startupFallbackTask = nil
                self.switchEngine(to: .mpv, reason: "启动阶段 Cannot Open，传输健康，受控回退到 MPV")
                return
            }
            DiagnosticsLogger.shared.log("StartupFallback", "deferred item=\(self.source.itemId) reason=transport-not-confirmed")
            self.stallMessage = "AVPlayer 无法打开视频，但当前下载链路尚未确认健康，请稍后重试。"
            self.startupFallbackTask = nil
        }
        return true
    }

    private func evaluatePlaybackStall() {
        guard Date() >= stallWatchdogSuppressedUntil, !engineSwitchInProgress, !engineTransitionAwaitingFirstSnapshot, startupFallbackTask == nil, !userIsScrubbing, pendingSeekTarget == nil, snapshot.isPlaying || snapshot.isBuffering, snapshot.position + 3 < effectiveDuration else { resetWatchdogSamples(); return }
        if !hasPlaybackAdvanced && snapshot.position < 0.25 { resetWatchdogSamples(); return }
        if !snapshot.isBuffering, snapshot.waitingReason == nil, forwardBufferedDuration >= 1.5 { resetWatchdogSamples(); return }

        let positionGrowth = snapshot.position - lastWatchdogPosition
        let bufferGrowth = bufferedEnd - lastWatchdogBufferEnd
        if positionGrowth < 0.15 && bufferGrowth < 0.5 { stagnantWatchdogIntervals += 1 }
        else { stagnantWatchdogIntervals = 0; stallRecoveryCount = 0; stallMessage = nil }
        lastWatchdogPosition = snapshot.position
        lastWatchdogBufferEnd = bufferedEnd

        let recoveryThreshold = engineKind == .ktvAVPlayer || engineKind == .resourceLoaderAVPlayer || engineKind == .transportAVPlayer ? 2 : 3
        guard stagnantWatchdogIntervals >= recoveryThreshold else { return }
        stagnantWatchdogIntervals = 0
        stallRecoveryCount += 1
        DiagnosticsLogger.shared.log("Stall", "engine=\(engineKind.title) recovery=\(stallRecoveryCount) position=\(snapshot.position) bufferedEnd=\(bufferedEnd) duration=\(effectiveDuration) waiting=\(snapshot.waitingReason ?? "none")")

        let action = orchestrator.actionForStall(kind: engineKind, recoveryCount: stallRecoveryCount, snapshot: snapshot, metrics: lastTransportMetrics)
        switch action {
        case .recoverTransport(let message): stallMessage = message; engine.recoverStall(position: snapshot.position, duration: effectiveDuration)
        case .switchEngine(let next, let reason): stallMessage = "自动切换到 \(next.title)：\(reason)"; switchEngine(to: next, reason: reason)
        case .reloadCurrent(let reason): stallMessage = reason; engine.reload(at: snapshot.position); engine.play()
        case .wait(let message): stallMessage = message
        }
    }

    private func promoteFullCacheRangeIfNeeded(_ metrics: TransportMetricsSnapshot) {
        guard metrics.resourceBytes > 0, metrics.cacheHoleCount == 0, metrics.cacheBytes >= metrics.resourceBytes else { return }
        let duration = effectiveDuration
        guard duration > 0 else { return }
        let fullRange = 0...duration
        guard verifiedBufferedRanges != [fullRange] else { return }
        verifiedBufferedRanges = [fullRange]
        bufferState.verifiedHistoryRanges = verifiedBufferedRanges
        DiagnosticsLogger.shared.log("BufferHistory", "transport cache complete bytes=\(metrics.cacheBytes)/\(metrics.resourceBytes) action=promote-full-duration duration=\(String(format: "%.3f", duration))")
    }

    private func startTransportMetricsPolling() {
        transportMetricsTask?.cancel()
        transportMetricsTask = nil
        transportSummary = nil
        transportCacheFraction = 0
        transportCacheRanges = []
        lastTransportMetrics = nil

        transportMetricsTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, self.started else { return }
                let engine = self.engine
                if let metrics = await engine.transportMetrics(), self.engine === engine {
                    self.lastTransportMetrics = metrics
                    self.transportSummary = metrics.summary
                    self.transportCacheFraction = metrics.resourceBytes > 0 ? min(1, max(0, Double(metrics.cacheBytes) / Double(metrics.resourceBytes))) : 0
                    let byteRanges: [Range<Int64>]
                    if let session = self.transportContext?.session { byteRanges = await session.cachedByteRanges() } else { byteRanges = [] }
                    self.transportCacheRanges = metrics.resourceBytes > 0 ? byteRanges.compactMap { byteRange in
                        let lower = min(1, max(0, Double(byteRange.lowerBound) / Double(metrics.resourceBytes)))
                        let upper = min(1, max(0, Double(byteRange.upperBound) / Double(metrics.resourceBytes)))
                        return upper > lower ? lower...upper : nil
                    } : []
                    self.promoteFullCacheRangeIfNeeded(metrics)
                } else if self.engine === engine {
                    self.lastTransportMetrics = nil
                    self.transportCacheFraction = 0
                    self.transportCacheRanges = []
                }
            }
        }
    }

    private func resetWatchdog() { stallRecoveryCount = 0; resetWatchdogSamples() }
    private func resetWatchdogSamples() { stagnantWatchdogIntervals = 0; lastWatchdogPosition = snapshot.position; lastWatchdogBufferEnd = bufferedEnd }
    private func suppressStallWatchdog(for seconds: TimeInterval) { stallWatchdogSuppressedUntil = max(stallWatchdogSuppressedUntil, Date().addingTimeInterval(seconds)); resetWatchdogSamples() }

    private func clampPosition(_ value: Double) -> Double {
        let upper = effectiveDuration
        return min(max(0, value), upper > 0 ? upper : max(0, value))
    }

    private func showSeekFeedback(offset: Double) {
        let seconds = abs(Int(offset.rounded()))
        seekFeedback = offset >= 0 ? "↻ \(seconds) 秒" : "↺ \(seconds) 秒"
        feedbackTask?.cancel()
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            self?.seekFeedback = nil
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
        } catch {
            DiagnosticsLogger.shared.log("Audio", "Audio session failed: \(error.localizedDescription)")
        }
    }
}
