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
    private var preferredForwardBuffer: Double = 90
    private var progressTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?
    private var seekReportTask: Task<Void, Never>?
    private var seekAnchorReleaseTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var transportMetricsTask: Task<Void, Never>?
    private var compatibilityRecoveryTask: Task<Void, Never>?
    private var compatibilitySeekFallbackTask: Task<Void, Never>?
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
    private var mpvCompatibilityMode = false
    private var mpvCompatibilityReloadCount = 0
    private var mpvCompatibilityLoadInProgress = false

    var ksAVIOView: UIView? {
        (engine as? KSAVIOPlayerEngine)?.playerView
    }

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
        self.engine = PlayerController.makeEngine(kind: initialKind, source: source, client: client)
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
        startTransportMetricsPolling()
    }

    func stop() {
        guard started else { return }
        started = false
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
        guard kind != engineKind else { return }
        let resumePosition = clampPosition(pendingSeekTarget ?? snapshot.position)
        let shouldPlay = snapshot.isPlaying

        DiagnosticsLogger.shared.log(
            "Engine",
            "Switch \(engineKind.title) -> \(kind.title) reason=\(reason) position=\(resumePosition)"
        )

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
        engine.stop()
        engineKind = kind
        engine = Self.makeEngine(kind: kind, source: source, client: client)
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
        startTransportMetricsPolling()
    }

    func toggleEngine() {
        let next: PlayerEngineKind
        switch engineKind {
        case .transportAVPlayer: next = .ksAVIO
        case .ksAVIO: next = .avPlayer
        case .avPlayer: next = .mpv
        case .mpv: next = .transportAVPlayer
        }
        switchEngine(to: next)
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

    private static func makeEngine(kind: PlayerEngineKind, source: ResolvedPlaybackSource, client: EmbyAPIClient) -> PlayerEngine {
        switch kind {
        case .transportAVPlayer:
            return AVPlayerEngine(
                kind: .transportAVPlayer,
                transportSource: source,
                transportClient: client,
                transportConfiguration: MediaTransportConfiguration.current()
            )
        case .ksAVIO:
            return KSAVIOPlayerEngine(source: source, client: client, configuration: MediaTransportConfiguration.current())
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

        if decision.isPremature, engineKind != .mpv {
            prematureEOFMessage = "\(decision.reason)；自动切换 MPV。"
            switchEngine(to: .mpv, reason: "AVPlayer 疑似提前结束")
        } else if decision.isPremature, eofRetryCount < 2 {
            guard !mpvCompatibilityLoadInProgress else {
                DiagnosticsLogger.shared.log(
                    "EOF",
                    "ignored during MPV compatibility file transition"
                )
                return
            }
            eofRetryCount += 1
            let skip = eofRetryCount == 1 ? 5.0 : 15.0
            let target = clampPosition(snapshot.position + skip)
            prematureEOFMessage = "\(decision.reason)；启用异常 MP4 兼容读取并从 \(formatTime(target)) 恢复（\(eofRetryCount)/2）"
            startMPVCompatibilityReload(
                at: target,
                reason: "MPV 提前 EOF"
            )
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

        if engineKind == .transportAVPlayer || engineKind == .ksAVIO {
            engine.recoverStall(position: snapshot.position, duration: effectiveDuration)
            stallMessage = snapshot.errorMessage == nil
                ? (engineKind == .ksAVIO ? "KSPlayer AVIO 正在等待精确字节数据；已绕过 localhost 原始 MP4。" : "下载优先传输正在按播放器真实字节需求补齐缺口；不会自动切回已知会卡顿的 MPV。")
                : "下载优先传输失败：\(snapshot.errorMessage ?? "未知错误")"
            return
        }

        if engineKind == .avPlayer, stallRecoveryCount >= 2 {
            switchEngine(to: .mpv, reason: "原生 AVPlayer 连续停滞且缓冲不增长")
            return
        }

        if engineKind == .mpv {
            guard source.mediaSource.normalizedContainer == "mp4" else {
                stallMessage = "检测到 MPV 停滞，正在使用同一实例重新载入当前位置。"
                engine.reload(at: snapshot.position)
                engine.play()
                return
            }

            if !mpvCompatibilityMode {
                let target = clampPosition(snapshot.position + 3)
                stallMessage = "检测到远程 MP4 停滞，正在启用坏交错 MP4 兼容读取。"
                startMPVCompatibilityReload(
                    at: target,
                    reason: "首次停滞：关闭 interleaved_read 和缓存内 Seek"
                )
            } else if mpvCompatibilityReloadCount < 2 {
                let target = clampPosition(snapshot.position + 8)
                stallMessage = "兼容读取仍停滞，正在刷新播放会话并从后方重新载入。"
                startMPVCompatibilityReload(
                    at: target,
                    reason: "兼容模式再次停滞"
                )
            } else {
                stallMessage = "异常 MP4 兼容读取仍无法继续，请拖动到更后方位置并导出日志。"
            }
            return
        }

        stallMessage = "检测到播放停滞，正在重新加载当前媒体。"
        engine.reload(at: snapshot.position)
        engine.play()
    }

    private func startTransportMetricsPolling() {
        transportMetricsTask?.cancel()
        transportMetricsTask = nil
        transportSummary = nil

        if engineKind == .transportAVPlayer, let avEngine = engine as? AVPlayerEngine {
            transportMetricsTask = Task { [weak self, weak avEngine] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard let self, let avEngine, self.started, self.engine === avEngine else { return }
                    if let metrics = await avEngine.transportMetrics() { self.transportSummary = metrics.summary }
                }
            }
        } else if engineKind == .ksAVIO, let ksEngine = engine as? KSAVIOPlayerEngine {
            transportMetricsTask = Task { [weak self, weak ksEngine] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard let self, let ksEngine, self.started, self.engine === ksEngine else { return }
                    if let metrics = await ksEngine.transportMetrics() { self.transportSummary = metrics.summary }
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

