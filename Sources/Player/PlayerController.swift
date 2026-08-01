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

    @Published private(set) var source: ResolvedPlaybackSource

    private(set) var engine: PlayerEngine
    private let client: EmbyAPIClient
    private var preferredForwardBuffer: Double = 90
    private var progressTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?
    private var seekReportTask: Task<Void, Never>?
    private var seekAnchorReleaseTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var started = false
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

    var avPlayer: AVPlayer? {
        (engine as? AVPlayerEngine)?.player
    }

    var mpvDisplayLayer: AVSampleBufferDisplayLayer? {
        (engine as? MPVPlayerEngine)?.displayLayer
    }

    init(source: ResolvedPlaybackSource, client: EmbyAPIClient, preference: PlayerEnginePreference) {
        self.source = source
        self.client = client
        let initialKind = preference.resolved(for: source.mediaSource)
        self.engineKind = initialKind
        self.engine = PlayerController.makeEngine(kind: initialKind)
        bindEngine()
    }

    func start(preferredForwardBuffer: Double) {
        guard !started else { return }
        started = true
        self.preferredForwardBuffer = preferredForwardBuffer > 0 ? preferredForwardBuffer : 90
        configureAudioSession()
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
    }

    func stop() {
        guard started else { return }
        started = false
        DiagnosticsLogger.shared.log("Lifecycle", "player close requested engine=\(engineKind.title) position=\(snapshot.position)")

        progressTask?.cancel()
        progressTask = nil
        watchdogTask?.cancel()
        watchdogTask = nil
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

        Task {
            await client.reportStopped(source: source, position: position)
        }

        pendingSeekTarget = nil
        pendingSeekDirection = nil
        screenScrubStartPosition = nil
        DiagnosticsLogger.shared.log("Lifecycle", "player close detached")
    }

    func togglePlayPause() {
        if snapshot.isPlaying {
            engine.pause()
            Task { await client.reportProgress(source: source, position: snapshot.position, paused: true, eventName: "Pause") }
        } else {
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
        if shouldBypassMPVStall, offset > 0, let mpvEngine = engine as? MPVPlayerEngine {
            let bypassTarget = clampPosition(max(target, snapshot.position + 30))
            pendingSeekTarget = bypassTarget
            pendingSeekDirection = .forward
            displayedPosition = bypassTarget
            stallMessage = "MPV 已停滞，本次快进将跨过异常区域到 \(formatTime(bypassTarget))。"
            mpvEngine.recoverFromStall(to: bypassTarget, reason: "用户双击跨过异常区域")
        } else {
            engine.seek(to: target, direction: offset >= 0 ? .forward : .backward)
        }
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
        guard kind != engineKind else { return }
        let resumePosition = clampPosition(pendingSeekTarget ?? snapshot.position)
        let shouldPlay = snapshot.isPlaying

        DiagnosticsLogger.shared.log(
            "Engine",
            "Switch \(engineKind.title) -> \(kind.title) reason=\(reason) position=\(resumePosition)"
        )

        pendingSeekTarget = nil
        pendingSeekDirection = nil
        seekAnchorReleaseTask?.cancel()
        seekAnchorReleaseTask = nil
        engine.stop()
        engineKind = kind
        engine = Self.makeEngine(kind: kind)
        bindEngine()
        resetWatchdog()
        prematureEOFMessage = nil
        stallMessage = "已切换到 \(kind.title)：\(reason)"

        engine.prepare(
            url: source.url,
            headers: source.headers,
            preferredForwardBuffer: preferredForwardBuffer,
            startPosition: resumePosition
        )
        if shouldPlay { engine.play() }
    }

    func toggleEngine() {
        switchEngine(to: engineKind == .avPlayer ? .mpv : .avPlayer)
    }

    var effectiveDuration: Double {
        max(snapshot.duration, source.mediaSource.durationSeconds ?? 0)
    }

    var bufferedEnd: Double {
        snapshot.bufferedRanges
            .filter { $0.lowerBound <= snapshot.position + 0.5 }
            .map(\.upperBound)
            .max() ?? 0
    }

    private static func makeEngine(kind: PlayerEngineKind) -> PlayerEngine {
        switch kind {
        case .avPlayer: return AVPlayerEngine()
        case .mpv: return MPVPlayerEngine()
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

                if !self.userIsScrubbing, let pending = self.pendingSeekTarget,
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
                    self.displayedPosition = pending
                    self.scheduleSeekAnchorRelease(expectedTarget: pending)
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

        if shouldBypassMPVStall, target > snapshot.position, let mpvEngine = engine as? MPVPlayerEngine {
            stallMessage = "MPV 已停滞，正在直接跳到 \(formatTime(target))。"
            mpvEngine.recoverFromStall(to: target, reason: "用户拖动跨过异常区域")
        } else {
            engine.seek(to: target, direction: .absolute)
        }
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

        if decision.isPremature, engineKind == .avPlayer {
            prematureEOFMessage = "\(decision.reason)；自动切换 MPV。"
            switchEngine(to: .mpv, reason: "AVPlayer 疑似提前结束")
        } else if decision.isPremature, eofRetryCount < 2 {
            eofRetryCount += 1
            let skip = eofRetryCount == 1 ? 30.0 : 60.0
            let target = clampPosition(snapshot.position + skip)
            prematureEOFMessage = "\(decision.reason)；正在跨过异常区域到 \(formatTime(target))（\(eofRetryCount)/2）"
            if let mpvEngine = engine as? MPVPlayerEngine {
                pendingSeekTarget = target
                pendingSeekDirection = .forward
                displayedPosition = target
                mpvEngine.recoverFromStall(to: target, reason: "MPV 提前 EOF 跨区恢复")
            }
        } else if decision.isPremature {
            prematureEOFMessage = "\(decision.reason)；自动恢复已达上限，请导出日志。"
        } else {
            Task { await client.reportStopped(source: source, position: snapshot.position) }
        }
    }

    private func evaluatePlaybackStall() {
        guard !userIsScrubbing, pendingSeekTarget == nil,
              snapshot.isPlaying || snapshot.isBuffering,
              snapshot.position + 3 < effectiveDuration else {
            resetWatchdogSamples()
            return
        }

        let positionGrowth = snapshot.position - lastWatchdogPosition
        let bufferGrowth = bufferedEnd - lastWatchdogBufferEnd
        if positionGrowth < 0.15 && bufferGrowth < 0.5 {
            stagnantWatchdogIntervals += 1
        } else {
            stagnantWatchdogIntervals = 0
            stallRecoveryCount = 0
            stallMessage = nil
        }
        lastWatchdogPosition = snapshot.position
        lastWatchdogBufferEnd = bufferedEnd

        guard stagnantWatchdogIntervals >= 4 else { return }
        stagnantWatchdogIntervals = 0
        stallRecoveryCount += 1

        DiagnosticsLogger.shared.log(
            "Stall",
            "engine=\(engineKind.title) recovery=\(stallRecoveryCount) position=\(snapshot.position) bufferedEnd=\(bufferedEnd) duration=\(effectiveDuration) waiting=\(snapshot.waitingReason ?? "none")"
        )

        if engineKind == .avPlayer, stallRecoveryCount >= 2 {
            switchEngine(to: .mpv, reason: "AVPlayer 连续停滞且缓冲不增长")
            return
        }

        if engineKind == .mpv, let mpvEngine = engine as? MPVPlayerEngine {
            let skip = stallRecoveryCount == 1 ? 30.0 : 60.0
            let target = clampPosition(snapshot.position + skip)
            let action = stallRecoveryCount == 1
                ? "清理解码缓冲并向后跨过 30 秒"
                : "再次停滞，向后跨过 60 秒"
            stallMessage = "检测到 MPV 停滞：\(action)。"
            pendingSeekTarget = target
            pendingSeekDirection = .forward
            displayedPosition = target
            mpvEngine.recoverFromStall(to: target, reason: action)
            return
        }

        stallMessage = "检测到播放停滞，正在重新加载当前媒体。"
        engine.reload(at: snapshot.position)
        engine.play()
    }

    private var shouldBypassMPVStall: Bool {
        guard engineKind == .mpv else { return false }
        return stallRecoveryCount > 0
            || snapshot.waitingReason == "MPV paused-for-cache"
            || snapshot.waitingReason == "MPV stall bypass"
            || (snapshot.isBuffering && stagnantWatchdogIntervals >= 2)
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

