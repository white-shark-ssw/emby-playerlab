import AVFoundation
import Combine
import Foundation
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

    @Published private(set) var source: ResolvedPlaybackSource

    private(set) var engine: PlayerEngine
    private let client: EmbyAPIClient
    private let orchestrator: PlaybackOrchestrator
    private let transportContext: PlaybackTransportContext?
    private var preferredForwardBuffer: Double = 90
    private var progressTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?
    private var seekReportTask: Task<Void, Never>?
    private var seekAnchorReleaseTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var transportMetricsTask: Task<Void, Never>?
    private var compatibilityRecoveryTask: Task<Void, Never>?
    private var compatibilitySeekFallbackTask: Task<Void, Never>?
    private var engineSwitchTask: Task<Void, Never>?
    private var engineSwitchInProgress = false
    private var engineTransitionAwaitingFirstSnapshot = false
    private var engineSwitchSerial: UInt64 = 0
    private var started = false
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
    private var mpvCompatibilityMode = false
    private var mpvCompatibilityReloadCount = 0
    private var mpvCompatibilityLoadInProgress = false
    private var lastTransportMetrics: TransportMetricsSnapshot?
    private var lastHandledEngineError: String?

    var ksAVIOView: UIView? {
        (engine as? KSAVIOPlayerEngine)?.playerView
    }

    var avPlayer: AVPlayer? {
        if let engine = engine as? AVPlayerEngine { return engine.player }
        if let engine = engine as? KTVAVPlayerEngine { return engine.player }
        return nil
    }

    var mpvDisplayLayer: AVSampleBufferDisplayLayer? {
        (engine as? MPVPlayerEngine)?.displayLayer
    }

    init(source: ResolvedPlaybackSource, client: EmbyAPIClient, preference: PlayerEnginePreference) {
        self.source = source
        self.client = client
        let orchestrator = PlaybackOrchestrator(source: source, preference: preference)
        self.orchestrator = orchestrator
        let initialKind = orchestrator.currentKind
        let transportContext: PlaybackTransportContext?
        if initialKind == .resourceLoaderAVPlayer || initialKind == .ksAVIO {
            transportContext = PlaybackTransportContext(
                source: source,
                client: client,
                configuration: MediaTransportConfiguration.current()
            )
        } else {
            transportContext = nil
        }
        self.transportContext = transportContext
        self.engineKind = initialKind
        self.engine = PlayerController.makeEngine(kind: initialKind, source: source, client: client, transportContext: transportContext)
        bindEngine()
    }

    func start(preferredForwardBuffer: Double) {
        guard !started else { return }
        started = true
        self.preferredForwardBuffer = preferredForwardBuffer > 0 ? preferredForwardBuffer : 90
        configureAudioSession()
        userWantsPlayback = true
        engine.prepare(
            url: source.url,
            headers: source.headers,
            preferredForwardBuffer: self.preferredForwardBuffer,
            startPosition: 0
        )
        engine.play()

        DiagnosticsLogger.shared.log(
            "Player",
            "Start item=\(source.itemId) title=\(source.itemName) engine=\(engineKind.title) mediaSource=\(source.mediaSource.id) container=\(source.mediaSource.container ?? "unknown") video=\(source.mediaSource.videoCodec ?? "unknown") audio=\(source.mediaSource.audioCodec ?? "unknown") url=\(source.url.absoluteString)"
        )

        Task {
            await client.reportStart(source: source, position: 0, paused: false)
        }

        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard let self, self.started else { return }
                await self.client.reportProgress(
                    source: self.source,
                    position: self.snapshot.position,
                    paused: !self.snapshot.isPlaying
                )
            }
        }

        watchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self, self.started else { return }
                self.evaluatePlaybackStall()
            }
        }
        startTransportMetricsPolling()
    }

    func stop() {
        guard started else { return }
        started = false
        userWantsPlayback = false
        DiagnosticsLogger.shared.log("Lifecycle", "player close requested engine=\(engineKind.title) position=\(snapshot.position)")

        progressTask?.cancel()
        progressTask = nil
        watchdogTask?.cancel()
        watchdogTask = nil
        transportMetricsTask?.cancel()
        transportMetricsTask = nil
        transportSummary = nil
        compatibilityRecoveryTask?.cancel()
        compatibilityRecoveryTask = nil
        compatibilitySeekFallbackTask?.cancel()
        compatibilitySeekFallbackTask = nil
        engineSwitchTask?.cancel()
        engineSwitchTask = nil
        engineSwitchInProgress = false
        engineTransitionAwaitingFirstSnapshot = false
        EngineTransitionBreadcrumb.clear()
        seekReportTask?.cancel()
        seekReportTask = nil
        seekAnchorReleaseTask?.cancel()
        seekAnchorReleaseTask = nil
        feedbackTask?.cancel()
        feedbackTask = nil

        // Invalidate callbacks before libmpv teardown so stale events cannot mutate a disappearing view.
        engineGeneration += 1
        engine.onSnapshot = nil
        engine.onSeekCompleted = nil

        let position = snapshot.position
        engine.stop()
        transportContext?.stop()

        Task {
            await client.reportStopped(source: source, position: position)
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
            Task { await client.reportProgress(source: source, position: snapshot.position, paused: true, eventName: "Pause") }
        } else {
            userWantsPlayback = true
            engine.play()
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

        DiagnosticsLogger.shared.log(
            "SeekAnchor",
            "offset=\(offset) base=\(base) target=\(target) enginePosition=\(snapshot.position)"
        )
        engine.seek(to: target, direction: offset >= 0 ? .forward : .backward)
        scheduleCompatibilitySeekFallback(
            target: target,
            reason: "兼容模式双击 Seek 未收到 PLAYBACK_RESTART"
        )
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

    func updateScrubbing(to value: Double) {
        displayedPosition = clampPosition(value)
    }

    func endScrubbing() {
        commitScrubbedPosition()
    }

    func beginScreenScrubbing() {
        seekAnchorReleaseTask?.cancel()
        seekAnchorReleaseTask = nil
        pendingSeekTarget = nil
        pendingSeekDirection = nil
        userIsScrubbing = true
        let start = pendingSeekTarget ?? snapshot.position
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
        compatibilityRecoveryTask?.cancel()
        compatibilityRecoveryTask = nil
        compatibilitySeekFallbackTask?.cancel()
        compatibilitySeekFallbackTask = nil
        mpvCompatibilityMode = false
        mpvCompatibilityReloadCount = 0
        mpvCompatibilityLoadInProgress = false
        seekAnchorReleaseTask?.cancel()
        seekAnchorReleaseTask = nil
        transportMetricsTask?.cancel()
        transportMetricsTask = nil
        lastTransportMetrics = nil
        transportSummary = nil

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
        case .ktvAVPlayer: next = .resourceLoaderAVPlayer
        case .resourceLoaderAVPlayer: next = .ksAVIO
        case .transportAVPlayer: next = .resourceLoaderAVPlayer
        case .ksAVIO: next = .ktvAVPlayer
        case .avPlayer: next = .resourceLoaderAVPlayer
        case .mpv: next = .ktvAVPlayer
        }
        switchEngine(to: next)
    }

    var playbackControlIsPlaying: Bool { userWantsPlayback }

    var effectiveDuration: Double {
        max(snapshot.duration, source.mediaSource.durationSeconds ?? 0)
    }

    var bufferedEnd: Double {
        snapshot.bufferedRanges
            .filter { $0.lowerBound <= snapshot.position + 0.5 }
            .map(\.upperBound)
            .max() ?? 0
    }

    private static func makeEngine(
        kind: PlayerEngineKind,
        source: ResolvedPlaybackSource,
        client: EmbyAPIClient,
        transportContext: PlaybackTransportContext?
    ) -> PlayerEngine {
        switch kind {
        case .ktvAVPlayer:
            return KTVAVPlayerEngine(source: source, configuration: MediaTransportConfiguration.current())
        case .resourceLoaderAVPlayer:
            return AVPlayerEngine(
                kind: .resourceLoaderAVPlayer,
                transportSource: source,
                transportClient: client,
                transportConfiguration: MediaTransportConfiguration.current(),
                sharedTransportSession: transportContext?.session
            )
        case .transportAVPlayer:
            return AVPlayerEngine(
                kind: .transportAVPlayer,
                transportSource: source,
                transportClient: client,
                transportConfiguration: MediaTransportConfiguration.current()
            )
        case .ksAVIO:
            return KSAVIOPlayerEngine(
                source: source,
                client: client,
                configuration: MediaTransportConfiguration.current(),
                sharedTransportSession: transportContext?.session
            )
        case .avPlayer:
            return AVPlayerEngine()
        case .mpv:
            return MPVPlayerEngine()
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
                if self.engineTransitionAwaitingFirstSnapshot {
                    self.engineTransitionAwaitingFirstSnapshot = false
                    if let error = value.errorMessage, !error.isEmpty {
                        DiagnosticsLogger.shared.log("Engine", "Switch first snapshot error engine=\(self.engineKind.title) error=\(error)")
                    } else {
                        EngineTransitionBreadcrumb.clear()
                        DiagnosticsLogger.shared.log("Engine", "Switch first snapshot engine=\(self.engineKind.title) position=\(value.position)")
                    }
                }

                if self.engineKind != .mpv,
                   !self.userIsScrubbing,
                   let pending = self.pendingSeekTarget,
                   self.hasReachedPendingTarget(actual: value.position, target: pending) {
                    self.seekAnchorReleaseTask?.cancel()
                    self.seekAnchorReleaseTask = nil
                    self.pendingSeekTarget = nil
                    self.pendingSeekDirection = nil
                    self.displayedPosition = value.position
                    DiagnosticsLogger.shared.log(
                        "SeekAnchor",
                        "reached target=\(pending) actual=\(value.position)"
                    )
                } else if !self.userIsScrubbing, self.pendingSeekTarget == nil {
                    self.displayedPosition = value.position
                }

                if let error = value.errorMessage, !error.isEmpty, error != self.lastHandledEngineError {
                    self.lastHandledEngineError = error
                    self.handleEngineError(error)
                }

                if value.didReachEnd && !wasEnd {
                    self.handleEndEvent()
                }
            }
        }

        engine.onSeekCompleted = { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                guard generation == self.engineGeneration else { return }
                if let pending = self.pendingSeekTarget, abs(pending - result.target) < 0.01 {
                    self.compatibilitySeekFallbackTask?.cancel()
                    self.compatibilitySeekFallbackTask = nil
                    self.seekAnchorReleaseTask?.cancel()
                    self.seekAnchorReleaseTask = nil
                    self.pendingSeekTarget = nil
                    self.pendingSeekDirection = nil
                    self.displayedPosition = result.actualPosition ?? pending
                    DiagnosticsLogger.shared.log(
                        "SeekAnchor",
                        "completed target=\(pending) actual=\(result.actualPosition ?? pending)"
                    )
                }
                let actualText = result.actualPosition.map { String(format: "%.2f", $0) } ?? "unknown"
                self.lastSeekSummary = String(
                    format: "%.0fms · %@ · %@ · 目标 %.2fs / 实际 %@s",
                    result.completionLatencyMs,
                    result.bufferHit ? "缓存命中" : "缓存未命中",
                    result.measurement,
                    result.target,
                    actualText
                )
                DiagnosticsLogger.shared.log(
                    "Seek",
                    "engine=\(self.engineKind.title) target=\(result.target) actual=\(actualText) bufferHit=\(result.bufferHit) completionMs=\(result.completionLatencyMs) measurement=\(result.measurement)"
                )
            }
        }
    }

    private func commitScrubbedPosition() {
        userIsScrubbing = false
        let target = clampPosition(displayedPosition)
        pendingSeekTarget = target
        pendingSeekDirection = .absolute

        engine.seek(to: target, direction: .absolute)
        scheduleCompatibilitySeekFallback(
            target: target,
            reason: "兼容模式拖动 Seek 未收到 PLAYBACK_RESTART"
        )
        Task {
            await client.reportProgress(
                source: source,
                position: target,
                paused: !snapshot.isPlaying,
                eventName: "TimeUpdate"
            )
        }
    }

    private func scheduleSeekAnchorRelease(expectedTarget: Double) {
        seekAnchorReleaseTask?.cancel()
        seekAnchorReleaseTask = Task { [weak self] in
            // Failsafe only. Normal release happens when time-pos reaches the target.
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled,
                  let pending = self.pendingSeekTarget,
                  abs(pending - expectedTarget) < 0.01 else { return }

            self.pendingSeekTarget = nil
            self.pendingSeekDirection = nil
            self.displayedPosition = self.snapshot.position
            DiagnosticsLogger.shared.log(
                "SeekAnchor",
                "timeout target=\(expectedTarget) actual=\(self.snapshot.position)"
            )
        }
    }

    private func hasReachedPendingTarget(actual: Double, target: Double) -> Bool {
        switch pendingSeekDirection {
        case .forward:
            return actual >= target - 0.25
        case .backward:
            return actual <= target + 0.25
        case .absolute:
            return abs(actual - target) <= 0.40
        case .none:
            return false
        }
    }

    private func scheduleSeekReport(position: Double) {
        seekReportTask?.cancel()
        seekReportTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard let self, !Task.isCancelled else { return }
            await self.client.reportProgress(
                source: self.source,
                position: position,
                paused: !self.snapshot.isPlaying,
                eventName: "TimeUpdate"
            )
        }
    }

    private func handleEndEvent() {
        let decision = PrematureEOFGuard.evaluate(
            current: snapshot.position,
            avDuration: snapshot.duration,
            embyDuration: source.mediaSource.durationSeconds
        )
        DiagnosticsLogger.shared.log(
            "EOF",
            "engine=\(engineKind.title) premature=\(decision.isPremature) reason=\(decision.reason) current=\(snapshot.position) engineDuration=\(snapshot.duration) embyDuration=\(source.mediaSource.durationSeconds ?? 0)"
        )

        guard decision.isPremature else {
            userWantsPlayback = false
            Task { await client.reportStopped(source: source, position: snapshot.position) }
            return
        }

        switch orchestrator.actionForPrematureEOF(kind: engineKind, reason: decision.reason) {
        case .switchEngine(let next, let reason):
            prematureEOFMessage = "\(decision.reason)；App 正在自动切换到 \(next.title)。"
            switchEngine(to: next, reason: reason)
        case .reloadCurrent(let reason):
            if engineKind == .mpv, eofRetryCount < 2 {
                eofRetryCount += 1
                let target = clampPosition(snapshot.position + (eofRetryCount == 1 ? 5 : 15))
                prematureEOFMessage = "\(reason)；MPV 正在从 \(formatTime(target)) 恢复。"
                startMPVCompatibilityReload(at: target, reason: reason)
            } else {
                engine.reload(at: snapshot.position)
                engine.play()
            }
        case .recoverTransport(let message), .wait(let message):
            prematureEOFMessage = message
            engine.recoverStall(position: snapshot.position, duration: effectiveDuration)
        }
    }

    private func handleEngineError(_ message: String) {
        guard !engineSwitchInProgress, !engineTransitionAwaitingFirstSnapshot,
              let action = orchestrator.actionForEngineError(kind: engineKind, message: message) else { return }
        if case .switchEngine(let next, let reason) = action {
            stallMessage = "\(engineKind.title) 发生错误，正在自动切换到 \(next.title)。"
            switchEngine(to: next, reason: reason)
        }
    }

    private func evaluatePlaybackStall() {
        guard !engineSwitchInProgress, !engineTransitionAwaitingFirstSnapshot,
              !userIsScrubbing, pendingSeekTarget == nil,
              snapshot.isPlaying || snapshot.isBuffering,
              snapshot.position + 3 < effectiveDuration else {
            resetWatchdogSamples()
            return
        }

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

        DiagnosticsLogger.shared.log(
            "Stall",
            "engine=\(engineKind.title) recovery=\(stallRecoveryCount) position=\(snapshot.position) bufferedEnd=\(bufferedEnd) duration=\(effectiveDuration) waiting=\(snapshot.waitingReason ?? "none")"
        )

        let action = orchestrator.actionForStall(
            kind: engineKind,
            recoveryCount: stallRecoveryCount,
            snapshot: snapshot,
            metrics: lastTransportMetrics
        )
        switch action {
        case .recoverTransport(let message):
            stallMessage = message
            engine.recoverStall(position: snapshot.position, duration: effectiveDuration)
        case .switchEngine(let next, let reason):
            stallMessage = "自动切换到 \(next.title)：\(reason)"
            switchEngine(to: next, reason: reason)
        case .reloadCurrent(let reason):
            stallMessage = reason
            if engineKind == .mpv, source.mediaSource.normalizedContainer == "mp4" {
                startMPVCompatibilityReload(at: clampPosition(snapshot.position + 3), reason: reason)
            } else {
                engine.reload(at: snapshot.position)
                engine.play()
            }
        case .wait(let message):
            stallMessage = message
        }
    }

    private func startTransportMetricsPolling() {
        transportMetricsTask?.cancel()
        transportMetricsTask = nil
        transportSummary = nil
        lastTransportMetrics = nil

        transportMetricsTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, self.started else { return }
                let engine = self.engine
                if let metrics = await engine.transportMetrics(), self.engine === engine {
                    self.lastTransportMetrics = metrics
                    self.transportSummary = metrics.summary
                } else if self.engine === engine {
                    self.lastTransportMetrics = nil
                }
            }
        }
    }

    private func scheduleCompatibilitySeekFallback(target: Double, reason: String) {
        compatibilitySeekFallbackTask?.cancel()
        compatibilitySeekFallbackTask = nil

        guard started,
              engineKind == .mpv,
              mpvCompatibilityMode,
              source.mediaSource.normalizedContainer == "mp4" else { return }

        compatibilitySeekFallbackTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard let self,
                  !Task.isCancelled,
                  self.started,
                  self.engineKind == .mpv,
                  self.mpvCompatibilityMode,
                  let pending = self.pendingSeekTarget,
                  abs(pending - target) < 0.01 else { return }

            DiagnosticsLogger.shared.log(
                "MPVSeekFallback",
                "target=\(target) position=\(self.snapshot.position) reason=\(reason)"
            )
            self.compatibilitySeekFallbackTask = nil
            self.startMPVCompatibilityReload(at: target, reason: reason)
        }
    }

    private func startMPVCompatibilityReload(at requestedPosition: Double, reason: String) {
        guard started,
              engineKind == .mpv,
              source.mediaSource.normalizedContainer == "mp4",
              compatibilityRecoveryTask == nil,
              !mpvCompatibilityLoadInProgress,
              let mpvEngine = engine as? MPVPlayerEngine else { return }

        let startPosition = clampPosition(requestedPosition)
        let previousSource = source
        pendingSeekTarget = startPosition
        pendingSeekDirection = .absolute
        displayedPosition = startPosition
        compatibilitySeekFallbackTask?.cancel()
        compatibilitySeekFallbackTask = nil
        mpvCompatibilityMode = true
        mpvCompatibilityLoadInProgress = true
        mpvCompatibilityReloadCount += 1
        resetWatchdog()

        DiagnosticsLogger.shared.log(
            "MPVCompatibility",
            "begin reason=\(reason) from=\(snapshot.position) start=\(startPosition) reload=\(mpvCompatibilityReloadCount)"
        )

        compatibilityRecoveryTask = Task { [weak self, weak mpvEngine] in
            guard let self, let mpvEngine else { return }

            var refreshedSource = previousSource
            do {
                let playback = try await self.client.playbackInfo(itemId: previousSource.itemId)
                guard !Task.isCancelled, self.started else {
                    self.mpvCompatibilityLoadInProgress = false
                    self.compatibilityRecoveryTask = nil
                    return
                }

                if let mediaSource = playback.mediaSources.first(where: { $0.id == previousSource.mediaSource.id })
                    ?? playback.mediaSources.first {
                    refreshedSource = try self.client.resolvePlaybackSource(
                        itemId: previousSource.itemId,
                        itemName: previousSource.itemName,
                        mediaSource: mediaSource,
                        playSessionId: playback.playSessionId
                    )
                }
            } catch {
                DiagnosticsLogger.shared.log(
                    "MPVCompatibility",
                    "PlaybackInfo refresh failed: \(error.localizedDescription); reusing current playback source"
                )
            }

            guard !Task.isCancelled, self.started, self.engine === mpvEngine else {
                self.mpvCompatibilityLoadInProgress = false
                self.compatibilityRecoveryTask = nil
                return
            }

            self.source = refreshedSource
            self.resetWatchdogSamples()
            mpvEngine.reloadForBadInterleavedMP4(
                url: refreshedSource.url,
                headers: refreshedSource.headers,
                preferredForwardBuffer: self.preferredForwardBuffer,
                startPosition: startPosition,
                reason: reason
            )
            mpvEngine.play()

            Task {
                await self.client.reportStopped(
                    source: previousSource,
                    position: self.snapshot.position
                )
                await self.client.reportStart(
                    source: refreshedSource,
                    position: startPosition,
                    paused: false
                )
            }

            // The file replacement is now queued. STOP/REDIRECT transition events
            // are ignored by MPVPlayerEngine; the next FILE_LOADED/time-pos events will
            // drive normal state again.
            self.mpvCompatibilityLoadInProgress = false
            self.compatibilityRecoveryTask = nil
        }
    }

    private func resetWatchdog() {
        stallRecoveryCount = 0
        resetWatchdogSamples()
    }

    private func resetWatchdogSamples() {
        stagnantWatchdogIntervals = 0
        lastWatchdogPosition = snapshot.position
        lastWatchdogBufferEnd = bufferedEnd
    }

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

