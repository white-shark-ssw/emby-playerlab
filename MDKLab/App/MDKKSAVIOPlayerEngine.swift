#if MDK_LAB && canImport(swift_mdk)
import Foundation
import QuartzCore
import UIKit
import swift_mdk

private final class MDKRenderView: UIView {
    var onSurfaceChanged: ((CGSize) -> Void)?

    override class var layerClass: AnyClass { CAMetalLayer.self }
    var metalLayer: CAMetalLayer { layer as! CAMetalLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isOpaque = true
        isUserInteractionEnabled = false
        metalLayer.contentsScale = UIScreen.main.scale
    }

    convenience init() { self.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = window?.screen.scale ?? UIScreen.main.scale
        let size = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
        guard metalLayer.drawableSize != size else { return }
        metalLayer.drawableSize = size
        onSurfaceChanged?(size)
    }

    var currentPixelSize: CGSize {
        let size = metalLayer.drawableSize
        if size.width > 0, size.height > 0 { return size }
        let scale = window?.screen.scale ?? UIScreen.main.scale
        return CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
    }
}

final class KSAVIOPlayerEngine: PlayerEngine {
    private struct PendingSeekResume {
        let id: Int
        let target: Double
        let requestedAt: TimeInterval
        var callbackAt: TimeInterval?
        var callbackPosition: Double?
        var callbackFrameSerial: UInt64?
        var didLogClockAdvance = false
    }

    private struct NativeSeekIntent {
        let id: Int
        let target: Double
        let duration: Double
        let requestedAt: TimeInterval
        let direction: SeekDirection
        let playerGeneration: Int
        var retryCount = 0
        var nativeStartedAt: TimeInterval?
        var nativeStartFrameSerial: UInt64?
    }

    let kind: PlayerEngineKind = .ksAVIO
    var onSnapshot: ((PlayerSnapshot) -> Void)?
    var onSeekCompleted: ((SeekResult) -> Void)?

    private let source: ResolvedPlaybackSource
    private let sharedTransportSession: TransportDataSession?
    private let view: MDKRenderView
    private var renderer: PlayerMetalLayerRenderer
    private var nativeControlQueue = DispatchQueue(label: "OnePlayer.MDK.NativeControl.0", qos: .userInitiated)
    private let playerLock = NSLock()
    private var player: swift_mdk.Player?
    private var stateTimer: DispatchSourceTimer?
    private var renderWatchdogTimer: Timer?
    private var hasRenderedValidFrame = false
    private var lastRenderedFrameAt = CACurrentMediaTime()
    private var lastNativeBuffering = false
    private var lastNativePosition: Double = 0
    private var lastNativeDuration: Double = 0
    private var lastNativeStatus: Int32 = 0
    private var lastNativeBufferMs: Int64 = 0
    private var lastNativeIsPlaying = false
    private var lastNativeEnded = false
    private var transportHTTPServer: TransportHTTPServer?
    private var transportPrepareTask: Task<Void, Never>?
    private var lastURL: URL?
    private var lastHeaders: [String: String] = [:]
    private var preferredForwardBuffer: Double = 90
    private var shouldPlay = false
    private var playbackRate: Double = 1
    private var rateGeneration = 0
    private var generation = 0
    private var firstRenderedGeneration = -1
    private var seekGeneration = 0
    private let seekBufferingUIGraceSeconds: TimeInterval = 0.5
    private let activeNativeSeekFastWatchdogSeconds: TimeInterval = 1.0
    private let activeNativeSeekWatchdogSeconds: TimeInterval = 2.0
    private let activeNativeSeekHardWatchdogSeconds: TimeInterval = 5.0
    private let seekFrameWatchdogSeconds: TimeInterval = 1.5
    private let seekFrameHardWatchdogSeconds: TimeInterval = 4.0
    private var pendingSeekResume: PendingSeekResume?
    private var activeNativeSeek: NativeSeekIntent?
    private var queuedLatestSeek: NativeSeekIntent?
    private var renderedFrameSerial: UInt64 = 0
    private var lastRenderedTimestamp: Double?
    private var seekBufferingGraceStartedAt: TimeInterval?
    private var seekBufferingGraceID: Int?
    private var seekBufferingGraceTarget: Double?
    private var didLogSeekBufferingGraceID: Int?
    private var didInstallLogHandler = false
    private var didConfigureGlobalIO = false
    private var prematureEOFRecoveryActive = false
    private var abnormalMediaRecoveryLevel = 0

    var playerView: UIView? { view }

    init(source: ResolvedPlaybackSource, client: EmbyAPIClient, configuration: MediaTransportConfiguration, sharedTransportSession: TransportDataSession? = nil, ktvCacheSession: KTVCachePlaybackSession? = nil) {
        self.source = source
        self.sharedTransportSession = sharedTransportSession
        let renderView = MDKRenderView()
        guard let renderer = PlayerMetalLayerRenderer(layer: renderView.metalLayer) else { fatalError("Metal is unavailable") }
        self.view = renderView
        self.renderer = renderer
        configureRenderer(renderer)
        renderView.onSurfaceChanged = { [weak self] size in self?.surfaceDidChange(size) }
        _ = client
        _ = configuration
        _ = ktvCacheSession
    }

    private func configureRenderer(_ renderer: PlayerMetalLayerRenderer) {
        renderer.onFrameSubmitted = { [weak self] result in
            DispatchQueue.main.async { [weak self] in self?.recordRenderedFrame(result) }
        }
        renderer.onRenderCompleted = { elapsedMs in
            guard elapsedMs >= 250 else { return }
            DiagnosticsLogger.shared.playback("MDKNativeIsolation", "operation=render completedMs=\(String(format: "%.1f", elapsedMs)) mainThread=false")
        }
    }

    private func currentPlayerReference() -> swift_mdk.Player? {
        playerLock.lock()
        let value = player
        playerLock.unlock()
        return value
    }

    private func installPlayer(_ value: swift_mdk.Player?) {
        playerLock.lock()
        player = value
        playerLock.unlock()
    }

    private func takePlayer() -> swift_mdk.Player? {
        playerLock.lock()
        let value = player
        player = nil
        playerLock.unlock()
        return value
    }

    private func isCurrentPlayer(_ candidate: swift_mdk.Player, generation expectedGeneration: Int) -> Bool {
        playerLock.lock()
        let matches = generation == expectedGeneration && player === candidate
        playerLock.unlock()
        return matches
    }

    private func surfaceDidChange(_ size: CGSize) {
        DiagnosticsLogger.shared.playback("MDKSurface", "size=\(Int(size.width))x\(Int(size.height)) backend=CAMetalLayer mainNativeCall=false")
        guard let player = currentPlayerReference() else { return }
        let currentGeneration = generation
        let renderer = self.renderer
        let queue = nativeControlQueue
        queue.async { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: currentGeneration) else { return }
            renderer.setSurfaceSize(size, player: player)
        }
    }

    private func requestPlayerState(playing: Bool, expectedPlayer: swift_mdk.Player? = nil, generation expectedGeneration: Int? = nil) {
        guard let player = expectedPlayer ?? currentPlayerReference() else { return }
        let currentGeneration = expectedGeneration ?? generation
        let queue = nativeControlQueue
        queue.async { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: currentGeneration) else { return }
            player.state = playing ? .Playing : .Paused
        }
    }

    private func startRenderWatchdog() {
        renderWatchdogTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.evaluateRenderLiveness() }
        renderWatchdogTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func evaluateRenderLiveness() {
        guard shouldPlay, hasRenderedValidFrame, !lastNativeBuffering else { return }
        let age = CACurrentMediaTime() - lastRenderedFrameAt
        guard age >= 4 else { return }
        hasRenderedValidFrame = false
        let message = "MDK native isolation render timeout"
        DiagnosticsLogger.shared.playback("MDKNativeIsolation", "operation=render timeoutMs=\(Int(age * 1_000)) mainResponsive=true action=quarantine-engine")
        onSnapshot?(PlayerSnapshot(position: lastNativePosition, duration: lastNativeDuration, isPlaying: false, isBuffering: false, waitingReason: "MDK 渲染线程未响应", errorMessage: message))
    }

    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double) {
        stopPlayerOnly()
        generation &+= 1
        let currentGeneration = generation
        nativeControlQueue = DispatchQueue(label: "OnePlayer.MDK.NativeControl.\(currentGeneration)", qos: .userInitiated)
        guard let newRenderer = PlayerMetalLayerRenderer(layer: view.metalLayer) else { return }
        renderer = newRenderer
        configureRenderer(newRenderer)
        startRenderWatchdog()
        self.preferredForwardBuffer = preferredForwardBuffer
        lastURL = url
        lastHeaders = headers
        pendingSeekResume = nil
        activeNativeSeek = nil
        queuedLatestSeek = nil
        renderedFrameSerial = 0
        lastRenderedTimestamp = nil
        seekBufferingGraceStartedAt = nil
        seekBufferingGraceID = nil
        seekBufferingGraceTarget = nil
        didLogSeekBufferingGraceID = nil
        prematureEOFRecoveryActive = false
        hasRenderedValidFrame = false
        lastRenderedFrameAt = CACurrentMediaTime()
        lastNativeBuffering = false
        lastNativePosition = max(0, startPosition)
        lastNativeDuration = source.mediaSource.durationSeconds ?? 0
        lastNativeStatus = 0
        lastNativeBufferMs = 0
        lastNativeIsPlaying = false
        lastNativeEnded = false
        installMDKLoggingIfNeeded()
        configureMDKIOIfNeeded()

        guard let sharedTransportSession else {
            startMDKPlayer(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition, generation: currentGeneration, transportMode: "direct-http302")
            DiagnosticsLogger.shared.playback("MDKTransport", "mode=direct-http302 unifiedTransportAvailable=false nasMediaProxy=false")
            return
        }

        let server = TransportHTTPServer(session: sharedTransportSession, fileExtension: mediaFileExtension, stopSessionOnStop: false)
        transportHTTPServer = server
        DiagnosticsLogger.shared.playback("MDKTransport", "mode=unified-localhost starting=true host=127.0.0.1 unifiedTransportActive=true nasMediaProxy=false")
        transportPrepareTask = Task { @MainActor [weak self, weak server] in
            guard let self, let server else { return }
            do {
                let localURL = try await server.start()
                guard !Task.isCancelled, currentGeneration == self.generation, self.transportHTTPServer === server else { server.stop(); return }
                self.transportPrepareTask = nil
                DiagnosticsLogger.shared.playback("MDKTransport", "mode=unified-localhost ready=true host=127.0.0.1 port=\(localURL.port ?? 0) unifiedTransportActive=true nasMediaProxy=false")
                self.startMDKPlayer(url: localURL, headers: [:], preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition, generation: currentGeneration, transportMode: "unified-localhost")
            } catch {
                guard !Task.isCancelled, currentGeneration == self.generation else { return }
                self.transportPrepareTask = nil
                if self.transportHTTPServer === server { self.transportHTTPServer = nil }
                server.stop()
                let message = "MDK UnifiedTransport 本地桥启动失败：\(error.localizedDescription)"
                DiagnosticsLogger.shared.playback("MDKTransport", "mode=unified-localhost ready=false error=\(error.localizedDescription) directFallback=false nasMediaProxy=false")
                self.onSnapshot?(PlayerSnapshot(position: max(0, startPosition), duration: self.source.mediaSource.durationSeconds ?? 0, isPlaying: false, isBuffering: false, errorMessage: message))
            }
        }
    }

    func play() {
        shouldPlay = true
        requestPlayerState(playing: true)
    }

    func pause() {
        shouldPlay = false
        DiagnosticsLogger.shared.playback("MDKLifecycle", "phase=pause-request generation=\(generation) nativeOutstanding=\(nativeSeekOutstandingCount) action=isolated-native-state")
        requestPlayerState(playing: false)
    }

    func setPlaybackRate(_ rate: Double) {
        let clamped = min(8, max(0.15, rate))
        playbackRate = clamped
        rateGeneration &+= 1
        let currentRateGeneration = rateGeneration
        guard let player = currentPlayerReference() else {
            DiagnosticsLogger.shared.playback("MDKRate", "requested=\(String(format: "%.2f", clamped)) state=pending-player")
            return
        }
        let currentPlayerGeneration = generation
        let startPosition = lastNativePosition
        let startedAt = CACurrentMediaTime()
        let queue = nativeControlQueue
        queue.async { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: currentPlayerGeneration), self.rateGeneration == currentRateGeneration else { return }
            player.playbackRate = Float(clamped)
            let applied = Double(player.playbackRate)
            DiagnosticsLogger.shared.playback("MDKRate", "requested=\(String(format: "%.2f", clamped)) applied=\(String(format: "%.2f", applied)) sourceFPS=\(self.sourceFrameRateText) decoder=VT mainNativeCall=false")
            DispatchQueue.main.async { [weak self, weak player] in
                guard let self, let player, self.isCurrentPlayer(player, generation: currentPlayerGeneration), self.rateGeneration == currentRateGeneration else { return }
                self.scheduleRateHealth(player: player, generation: currentRateGeneration, requested: clamped, startedAt: startedAt, startPosition: startPosition, delay: 1.5)
                self.scheduleRateHealth(player: player, generation: currentRateGeneration, requested: clamped, startedAt: startedAt, startPosition: startPosition, delay: 4.0)
            }
        }
    }

    func seek(to targetSeconds: Double, direction: SeekDirection) {
        guard let player = currentPlayerReference() else { return }
        let target = max(0, targetSeconds)
        let duration = max(source.mediaSource.durationSeconds ?? 0, lastNativeDuration)
        let requestedAt = Date().timeIntervalSince1970
        let currentPlayerGeneration = generation
        seekGeneration &+= 1
        let seekID = seekGeneration
        let intent = NativeSeekIntent(id: seekID, target: target, duration: duration, requestedAt: requestedAt, direction: direction, playerGeneration: currentPlayerGeneration)
        pendingSeekResume = PendingSeekResume(id: seekID, target: target, requestedAt: requestedAt, callbackAt: nil, callbackPosition: nil, callbackFrameSerial: nil)
        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(seekID) target=\(String(format: "%.3f", target)) phase=request generation=\(currentPlayerGeneration) nativeOutstanding=\(nativeSeekOutstandingCount) unifiedTransport=\(sharedTransportSession != nil) direction=\(String(describing: direction))")

        if let activeNativeSeek {
            let replaced = queuedLatestSeek?.id
            queuedLatestSeek = intent
            DiagnosticsLogger.shared.playback("MDKSeekCoalesce", "latest=\(seekID) target=\(String(format: "%.3f", target)) active=\(activeNativeSeek.id) replacedQueued=\(replaced.map { String($0) } ?? "none") action=latest-wins")
        } else {
            dispatchNativeSeek(intent, player: player)
        }
    }

    private var nativeSeekOutstandingCount: Int { (activeNativeSeek == nil ? 0 : 1) + (queuedLatestSeek == nil ? 0 : 1) }

    private func dispatchNativeSeek(_ intent: NativeSeekIntent, player: swift_mdk.Player) {
        guard intent.playerGeneration == generation, self.player === player else { return }
        activeNativeSeek = intent
        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(intent.id) target=\(String(format: "%.3f", intent.target)) phase=native-arm retry=\(intent.retryCount) nativeOutstanding=\(nativeSeekOutstandingCount)")

        if let session = sharedTransportSession {
            DiagnosticsLogger.shared.playback("MDKSeekHTTP", "id=\(intent.id) action=preserve-existing-stream-before-native-seek")
            Task { @MainActor [weak self, weak player] in
                await session.prioritizeSeek(position: intent.target, duration: intent.duration)
                guard let self, let player, intent.playerGeneration == self.generation, self.player === player, self.activeNativeSeek?.id == intent.id else { return }
                if let queued = self.queuedLatestSeek {
                    self.activeNativeSeek = nil
                    self.queuedLatestSeek = nil
                    DiagnosticsLogger.shared.playback("MDKSeekCoalesce", "skipped=\(intent.id) latest=\(queued.id) phase=before-native-dispatch action=latest-wins")
                    self.dispatchNativeSeek(queued, player: player)
                    return
                }
                self.performNativeSeek(intent, player: player)
            }
        } else {
            performNativeSeek(intent, player: player)
        }
    }

    private func performNativeSeek(_ intent: NativeSeekIntent, player: swift_mdk.Player) {
        guard intent.playerGeneration == generation, self.player === player, activeNativeSeek?.id == intent.id else { return }
        var dispatchedIntent = intent
        let nativeStartedAt = Date().timeIntervalSince1970
        dispatchedIntent.nativeStartedAt = nativeStartedAt
        dispatchedIntent.nativeStartFrameSerial = renderedFrameSerial
        activeNativeSeek = dispatchedIntent
        seekBufferingGraceStartedAt = nativeStartedAt
        seekBufferingGraceID = dispatchedIntent.id
        seekBufferingGraceTarget = dispatchedIntent.target
        didLogSeekBufferingGraceID = nil

        let queue = nativeControlQueue
        queue.async { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: dispatchedIntent.playerGeneration) else { return }
            let immediateResult = player.seek(self.milliseconds(dispatchedIntent.target), flags: .Default) { [weak self, weak player] actualMs in
                let callbackAt = Date().timeIntervalSince1970
                DispatchQueue.main.async { [weak self, weak player] in
                    guard let self else { return }
                    let requestLatency = (callbackAt - dispatchedIntent.requestedAt) * 1_000
                    let nativeLatency = (callbackAt - nativeStartedAt) * 1_000
                    guard let player, self.isCurrentPlayer(player, generation: dispatchedIntent.playerGeneration) else {
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) result=\(actualMs) current=false action=discard-stale-player-generation requestGeneration=\(dispatchedIntent.playerGeneration) activeGeneration=\(self.generation)")
                        return
                    }
                    guard self.activeNativeSeek?.id == dispatchedIntent.id else {
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) result=\(actualMs) action=discard-nonactive-native")
                        return
                    }

                    self.activeNativeSeek = nil
                    let isCurrent = self.pendingSeekResume?.id == dispatchedIntent.id
                    if actualMs >= 0 {
                        let actual = self.seconds(actualMs)
                        if var pending = self.pendingSeekResume, pending.id == dispatchedIntent.id {
                            pending.callbackAt = callbackAt
                            pending.callbackPosition = actual
                            pending.callbackFrameSerial = self.renderedFrameSerial
                            self.pendingSeekResume = pending
                            self.scheduleSeekFrameWatchdog(player: player, seekID: dispatchedIntent.id, playerGeneration: dispatchedIntent.playerGeneration, hard: false)
                        }
                        if isCurrent, self.shouldPlay { self.requestPlayerState(playing: true, expectedPlayer: player, generation: dispatchedIntent.playerGeneration) }
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) actual=\(String(format: "%.3f", actual)) current=\(isCurrent) action=\(isCurrent ? "callback-current-await-frame" : "diagnostic-only") nativeOutstanding=\(self.nativeSeekOutstandingCount) unifiedTransport=\(self.sharedTransportSession != nil) direction=\(String(describing: dispatchedIntent.direction)) nativeQueue=isolated")
                    } else if actualMs == -2, isCurrent, self.queuedLatestSeek == nil, dispatchedIntent.retryCount < 1 {
                        var retry = dispatchedIntent
                        retry.retryCount += 1
                        retry.nativeStartedAt = nil
                        self.queuedLatestSeek = retry
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) result=-2 current=true action=retry-ignored-once")
                    } else if actualMs == -2, self.queuedLatestSeek != nil {
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) result=-2 current=false action=ignored-dispatch-latest")
                    } else {
                        let recoveryTarget = self.latestDesiredTarget(fallback: dispatchedIntent.target)
                        if self.lastNativeEnded {
                            self.pendingSeekResume = nil
                            self.queuedLatestSeek = nil
                            DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) result=\(actualMs) current=\(isCurrent) action=eof-negative-callback-in-place-reprepare latestTarget=\(String(format: "%.3f", recoveryTarget)) source=cached-native-snapshot")
                            self.recoverStall(position: recoveryTarget, duration: dispatchedIntent.duration)
                            return
                        }
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) result=\(actualMs) current=\(isCurrent) action=negative-callback-recover latestTarget=\(String(format: "%.3f", recoveryTarget))")
                        self.recoverWedgedSeek(reason: "negative-callback-\(actualMs)", fallbackTarget: recoveryTarget, playerGeneration: dispatchedIntent.playerGeneration)
                        return
                    }
                    self.dispatchQueuedSeekIfNeeded(player: player)
                }
            }
            DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) phase=native-dispatch immediateResult=\(immediateResult) semantics=advisory retry=\(dispatchedIntent.retryCount) nativeOutstanding=isolated mainNativeCall=false")
            DispatchQueue.main.async { [weak self, weak player] in
                guard let self, let player, self.isCurrentPlayer(player, generation: dispatchedIntent.playerGeneration), self.activeNativeSeek?.id == dispatchedIntent.id else { return }
                self.scheduleActiveNativeSeekFastWatchdog(player: player, intent: dispatchedIntent)
                self.scheduleActiveNativeSeekWatchdog(player: player, intent: dispatchedIntent, hard: false)
            }
        }
    }

    private func dispatchQueuedSeekIfNeeded(player: swift_mdk.Player) {
        guard activeNativeSeek == nil, let next = queuedLatestSeek else { return }
        queuedLatestSeek = nil
        dispatchNativeSeek(next, player: player)
    }

    func reload(at seconds: Double) {
        guard let url = lastURL else { return }
        let resume = shouldPlay
        prepare(url: url, headers: lastHeaders, preferredForwardBuffer: preferredForwardBuffer, startPosition: seconds)
        if resume { play() }
    }

    func recoverStall(position: Double, duration: Double) {
        guard let player = currentPlayerReference() else { return }
        if let sharedTransportSession { Task { await sharedTransportSession.recoverStall(position: position, duration: duration) } }
        let status = lastNativeStatus
        let prematureEnd = lastNativeEnded && duration > 0 && position + max(3, duration * 0.005) < duration
        if prematureEnd, shouldPlay {
            guard !prematureEOFRecoveryActive else {
                DiagnosticsLogger.shared.playback("MDKRecovery", "position=\(String(format: "%.3f", position)) action=wait-existing-eof-recovery")
                return
            }
            guard abnormalMediaRecoveryLevel < 2 else {
                DiagnosticsLogger.shared.playback("MDKCompat", "position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) status=0x\(String(status, radix: 16)) level=\(abnormalMediaRecoveryLevel) action=exhausted-mdk-generations")
                onSnapshot?(PlayerSnapshot(position: position, duration: duration, isPlaying: false, isBuffering: false, waitingReason: "MDK 异常媒体恢复已用尽", errorMessage: "MDK abnormal media recovery exhausted"))
                return
            }
            prematureEOFRecoveryActive = true
            abnormalMediaRecoveryLevel += 1
            let level = abnormalMediaRecoveryLevel
            let profile = level == 1 ? "fresh-player" : "software-tolerant"
            DiagnosticsLogger.shared.playback("MDKCompat", "position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) status=0x\(String(status, radix: 16)) level=\(level) profile=\(profile) action=quarantine-eos-generation-and-rebuild samePlayerPrepare=false unifiedTransport=\(sharedTransportSession != nil)")
            reload(at: position)
            return
        }
        DiagnosticsLogger.shared.playback("MDKRecovery", "position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) playing=\(lastNativeIsPlaying) status=0x\(String(status, radix: 16)) unifiedTransport=\(sharedTransportSession != nil) action=prioritize-and-play source=cached-native-snapshot")
        if shouldPlay { requestPlayerState(playing: true, expectedPlayer: player, generation: generation) }
    }

    func transportMetrics() async -> TransportMetricsSnapshot? {
        guard let sharedTransportSession else { return nil }
        return await sharedTransportSession.metrics()
    }

    func stop() {
        shouldPlay = false
        generation &+= 1
        rateGeneration &+= 1
        prematureEOFRecoveryActive = false
        abnormalMediaRecoveryLevel = 0
        stopPlayerOnly()
        onSnapshot = nil
        onSeekCompleted = nil
    }

    private func startMDKPlayer(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double, generation currentGeneration: Int, transportMode: String) {
        guard currentGeneration == generation else { return }
        let player = swift_mdk.Player()
        installPlayer(player)
        let renderer = self.renderer
        let queue = nativeControlQueue
        let surfaceSize = view.currentPixelSize
        startStateTimer(player: player, generation: currentGeneration, queue: queue)
        queue.async { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: currentGeneration) else { return }
            let compatLevel = self.abnormalMediaRecoveryLevel
            let decoderList = compatLevel >= 2 ? ["FFmpeg", "VT"] : ["VT", "FFmpeg"]
            player.videoDecoders = decoderList
            player.playbackRate = Float(self.playbackRate)
            player.setBufferRange(msMin: 1_000, msMax: Int64(max(3_000, min(30_000, preferredForwardBuffer * 1_000))), drop: false)
            self.applyHTTPHeaders(headers, to: player)
            self.attachCallbacks(to: player, generation: currentGeneration)
            renderer.bind(player)
            renderer.setSurfaceSize(surfaceSize, player: player)
            player.setProperty(name: "keep_open", value: "1")
            if compatLevel >= 2 {
                player.setProperty(name: "avformat.err_detect", value: "ignore_err")
                player.setProperty(name: "avformat.fflags", value: "+discardcorrupt")
            }
            let compatProfile = compatLevel == 0 ? "normal" : (compatLevel == 1 ? "fresh-player" : "software-tolerant")
            DiagnosticsLogger.shared.playback("MDKCompat", "generation=\(currentGeneration) level=\(compatLevel) profile=\(compatProfile) videoDecoders=\(decoderList.joined(separator: ",")) avformatTolerance=\(compatLevel >= 2 ? "ignore_err+discardcorrupt" : "off") globalDemuxTolerance=off")
            player.media = url.absoluteString
            player.prepare(from: self.milliseconds(startPosition), complete: { [weak self, weak player] preparedAtMs, boost in
                guard let self, let player, self.isCurrentPlayer(player, generation: currentGeneration) else { return false }
                boost = true
                if self.shouldPlay { self.requestPlayerState(playing: true, expectedPlayer: player, generation: currentGeneration) }
                DiagnosticsLogger.shared.playback("MDKPrepare", "preparedAtMs=\(preparedAtMs) requestedStart=\(String(format: "%.3f", startPosition)) sourceFPS=\(self.sourceFrameRateText) compatLevel=\(compatLevel) videoDecoders=\(decoderList.joined(separator: ",")) transport=\(transportMode) mainNativeCall=false")
                return true
            })
            DiagnosticsLogger.shared.playback("MDK", "prepare item=\(self.source.itemId) version=\(swift_mdk.version()) transport=\(transportMode) localHost=\(url.host == "127.0.0.1") sharedTransport=\(self.sharedTransportSession != nil ? "active" : "unavailable") headers=\(headers.keys.sorted().joined(separator: ",")) rate=\(String(format: "%.2f", self.playbackRate)) nativeQueue=isolated")
        }
    }

    private func attachCallbacks(to player: swift_mdk.Player, generation: Int) {
        player.onStateChanged { [weak self, weak player] state in
            DispatchQueue.main.async { [weak self, weak player] in
                guard let self, let player, self.isCurrentPlayer(player, generation: generation) else { return }
                DiagnosticsLogger.shared.playback("MDKState", "state=\(String(describing: state)) position=\(String(format: "%.3f", self.lastNativePosition)) nativeCallbackMainRead=false")
            }
        }
        player.onMediaStatusChanged { [weak self, weak player] status in
            DispatchQueue.main.async { [weak self, weak player] in
                guard let self, let player, self.isCurrentPlayer(player, generation: generation) else { return }
                DiagnosticsLogger.shared.playback("MDKStatus", "raw=0x\(String(status.rawValue, radix: 16)) position=\(String(format: "%.3f", self.lastNativePosition)) nativeCallbackMainRead=false")
                if self.shouldPlay, self.isPrepared(status.rawValue) { self.requestPlayerState(playing: true, expectedPlayer: player, generation: generation) }
            }
            return true
        }
    }

    private func startStateTimer(player: swift_mdk.Player, generation: Int, queue: DispatchQueue) {
        stateTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.10, repeating: 0.10, leeway: .milliseconds(20))
        timer.setEventHandler { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: generation) else { return }
            self.pollState(player: player, generation: generation)
        }
        stateTimer = timer
        timer.resume()
    }

    private func pollState(player: swift_mdk.Player, generation: Int) {
        guard isCurrentPlayer(player, generation: generation) else { return }
        let position = seconds(player.position)
        let info = player.mediaInfo
        let duration = max(seconds(info.duration), source.mediaSource.durationSeconds ?? 0)
        let status = player.mediaStatus.rawValue
        let rawBuffering = hasStatus(status, bit: 3) || hasStatus(status, bit: 4)
        let ended = hasStatus(status, bit: 6)
        let isPlaying = player.state == .Playing && !ended
        let bufferMs = player.buffered()
        DispatchQueue.main.async { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: generation) else { return }
            self.consumeStateSample(position: position, duration: duration, status: status, rawBuffering: rawBuffering, ended: ended, isPlaying: isPlaying, bufferMs: bufferMs)
        }
    }

    private func consumeStateSample(position: Double, duration: Double, status: Int32, rawBuffering: Bool, ended: Bool, isPlaying: Bool, bufferMs: Int64) {
        let now = Date().timeIntervalSince1970
        lastNativePosition = position
        lastNativeDuration = duration
        lastNativeBuffering = rawBuffering
        lastNativeStatus = status
        lastNativeBufferMs = bufferMs
        lastNativeIsPlaying = isPlaying
        lastNativeEnded = ended

        if ended, duration > 0, position + max(3, duration * 0.005) < duration, activeNativeSeek != nil || queuedLatestSeek != nil || pendingSeekResume != nil {
            let recoveryTarget = latestDesiredTarget(fallback: position)
            activeNativeSeek = nil
            queuedLatestSeek = nil
            pendingSeekResume = nil
            DiagnosticsLogger.shared.playback("MDKSeekWedge", "reason=premature-eof-during-seek position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) latestTarget=\(String(format: "%.3f", recoveryTarget)) action=in-place-reprepare-no-rebuild")
            recoverStall(position: recoveryTarget, duration: duration)
            return
        }

        var suppressSeekBuffering = false
        if rawBuffering, let graceStartedAt = seekBufferingGraceStartedAt, now - graceStartedAt < seekBufferingUIGraceSeconds {
            suppressSeekBuffering = true
            if didLogSeekBufferingGraceID != seekBufferingGraceID {
                didLogSeekBufferingGraceID = seekBufferingGraceID
                DiagnosticsLogger.shared.playback("MDKBuffering", "id=\(seekBufferingGraceID ?? -1) target=\(String(format: "%.3f", seekBufferingGraceTarget ?? position)) raw=true ui=false reason=active-native-seek-grace graceMs=\(Int(seekBufferingUIGraceSeconds * 1_000))")
            }
        }
        let buffering = rawBuffering && !suppressSeekBuffering
        let forwardBuffered = seconds(bufferMs)
        let bufferedEnd = duration > 0 ? min(duration, position + forwardBuffered) : position + forwardBuffered
        onSnapshot?(PlayerSnapshot(position: position, duration: duration, bufferedRanges: bufferedEnd > position ? [position...bufferedEnd] : [], isPlaying: isPlaying, isBuffering: buffering, waitingReason: buffering ? "MDK 等待媒体数据" : nil, errorMessage: hasStatus(status, bit: 31) ? "MDK media status invalid" : nil, didReachEnd: ended))

        if var pending = pendingSeekResume, !pending.didLogClockAdvance, let callbackPosition = pending.callbackPosition, abs(position - callbackPosition) > 0.08 {
            let resumeMs = (now - pending.requestedAt) * 1_000
            let afterCallbackMs = pending.callbackAt.map { (now - $0) * 1_000 }
            pending.didLogClockAdvance = true
            pendingSeekResume = pending
            DiagnosticsLogger.shared.playback("MDKSeekHealth", "id=\(pending.id) target=\(String(format: "%.3f", pending.target)) callbackPosition=\(String(format: "%.3f", callbackPosition)) firstClockAdvance=\(String(format: "%.3f", position)) resumeMs=\(String(format: "%.1f", resumeMs)) afterCallbackMs=\(afterCallbackMs.map { String(format: "%.1f", $0) } ?? "pending") playing=\(isPlaying) rawBuffering=\(rawBuffering) uiBuffering=\(buffering) bufferMs=\(bufferMs) nativeOutstanding=\(nativeSeekOutstandingCount) awaitingRenderedFrame=true unifiedTransport=\(sharedTransportSession != nil)")
        }
    }

    private func scheduleActiveNativeSeekFastWatchdog(player: swift_mdk.Player, intent: NativeSeekIntent) {
        guard let nativeStartedAt = intent.nativeStartedAt, let startFrameSerial = intent.nativeStartFrameSerial else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + activeNativeSeekFastWatchdogSeconds) { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: intent.playerGeneration), self.activeNativeSeek?.id == intent.id else { return }
            guard self.renderedFrameSerial <= startFrameSerial else {
                DiagnosticsLogger.shared.playback("MDKSeekFastWatchdog", "id=\(intent.id) elapsedNativeMs=\(String(format: "%.1f", (Date().timeIntervalSince1970 - nativeStartedAt) * 1_000)) action=defer-render-progress")
                return
            }
            guard let session = self.sharedTransportSession else {
                DiagnosticsLogger.shared.playback("MDKSeekFastWatchdog", "id=\(intent.id) elapsedNativeMs=\(String(format: "%.1f", (Date().timeIntervalSince1970 - nativeStartedAt) * 1_000)) action=defer-no-unified-transport")
                return
            }
            Task { [weak self, weak player] in
                let metrics = await session.metrics()
                await MainActor.run {
                    guard let self, let player, self.isCurrentPlayer(player, generation: intent.playerGeneration), self.activeNativeSeek?.id == intent.id else { return }
                    let rawBuffering = self.lastNativeBuffering
                    let bufferMs = self.lastNativeBufferMs
                    let noRenderedProgress = self.renderedFrameSerial <= startFrameSerial
                    let transportHealthy = metrics.rangeFailureCount == 0 && metrics.resourceBytes > 0 && (metrics.cacheBytes > 0 || metrics.currentDownloadBytesPerSecond >= 1_048_576 || metrics.activeRequestCount == 0)
                    let engineDataHealthy = bufferMs >= 500 && !rawBuffering
                    let shouldRecover = noRenderedProgress && transportHealthy && engineDataHealthy
                    let recoveryTarget = self.latestDesiredTarget(fallback: intent.target)
                    DiagnosticsLogger.shared.playback("MDKSeekFastWatchdog", "id=\(intent.id) target=\(String(format: "%.3f", intent.target)) elapsedNativeMs=\(String(format: "%.1f", (Date().timeIntervalSince1970 - nativeStartedAt) * 1_000)) frameSerial=\(self.renderedFrameSerial)/\(startFrameSerial) bufferMs=\(bufferMs) rawBuffering=\(rawBuffering) transportHealthy=\(transportHealthy) cacheBytes=\(metrics.cacheBytes) active=\(metrics.activeRequestCount) networkBps=\(Int(metrics.currentDownloadBytesPerSecond)) latestTarget=\(String(format: "%.3f", recoveryTarget)) action=\(shouldRecover ? "recover-latest-target" : "defer-standard-watchdog") source=cached-native-snapshot")
                    if shouldRecover { self.recoverWedgedSeek(reason: "active-native-fast-timeout", fallbackTarget: recoveryTarget, playerGeneration: intent.playerGeneration) }
                }
            }
        }
    }

    private func scheduleActiveNativeSeekWatchdog(player: swift_mdk.Player, intent: NativeSeekIntent, hard: Bool) {
        guard let nativeStartedAt = intent.nativeStartedAt else { return }
        let delay = hard ? activeNativeSeekHardWatchdogSeconds - activeNativeSeekWatchdogSeconds : activeNativeSeekWatchdogSeconds
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.1, delay)) { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: intent.playerGeneration), self.activeNativeSeek?.id == intent.id else { return }
            let now = Date().timeIntervalSince1970
            let rawBuffering = self.lastNativeBuffering
            let bufferMs = self.lastNativeBufferMs
            let recoveryTarget = self.latestDesiredTarget(fallback: intent.target)
            let shouldRecover = hard || bufferMs >= 500 || !rawBuffering
            DiagnosticsLogger.shared.playback("MDKSeekWatchdog", "id=\(intent.id) target=\(String(format: "%.3f", intent.target)) elapsedNativeMs=\(String(format: "%.1f", (now - nativeStartedAt) * 1_000)) position=\(String(format: "%.3f", self.lastNativePosition)) playing=\(self.lastNativeIsPlaying) status=0x\(String(self.lastNativeStatus, radix: 16)) bufferMs=\(bufferMs) rawBuffering=\(rawBuffering) nativeOutstanding=\(self.nativeSeekOutstandingCount) latestTarget=\(String(format: "%.3f", recoveryTarget)) action=\(shouldRecover ? "recover-latest-target" : "wait-media-data") unifiedTransport=\(self.sharedTransportSession != nil) source=cached-native-snapshot")
            if let session = self.sharedTransportSession {
                Task {
                    let metrics = await session.metrics()
                    DiagnosticsLogger.shared.playback("MDKSeekWatchdog", "id=\(intent.id) transport anchor=\(metrics.schedulerAnchorByte) frontier=\(metrics.schedulerFrontierByte) cacheBytes=\(metrics.cacheBytes) active=\(metrics.activeRequestCount) networkBps=\(Int(metrics.currentDownloadBytesPerSecond))")
                }
            }
            if shouldRecover {
                self.recoverWedgedSeek(reason: hard ? "active-native-hard-timeout" : "active-native-timeout", fallbackTarget: recoveryTarget, playerGeneration: intent.playerGeneration)
            } else {
                self.scheduleActiveNativeSeekWatchdog(player: player, intent: intent, hard: true)
            }
        }
    }

    private func scheduleSeekFrameWatchdog(player: swift_mdk.Player, seekID: Int, playerGeneration: Int, hard: Bool) {
        let delay = hard ? seekFrameHardWatchdogSeconds - seekFrameWatchdogSeconds : seekFrameWatchdogSeconds
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.1, delay)) { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: playerGeneration), let pending = self.pendingSeekResume, pending.id == seekID, pending.callbackAt != nil else { return }
            let rawBuffering = self.lastNativeBuffering
            let bufferMs = self.lastNativeBufferMs
            let recoveryTarget = self.latestDesiredTarget(fallback: pending.target)
            let shouldRecover = self.shouldPlay && (hard || bufferMs >= 500 || !rawBuffering)
            DiagnosticsLogger.shared.playback("MDKSeekFrameWatchdog", "id=\(seekID) target=\(String(format: "%.3f", pending.target)) renderedSerial=\(self.renderedFrameSerial) callbackSerial=\(pending.callbackFrameSerial.map { String($0) } ?? "pending") position=\(String(format: "%.3f", self.lastNativePosition)) bufferMs=\(bufferMs) rawBuffering=\(rawBuffering) playingWanted=\(self.shouldPlay) action=\(shouldRecover ? "recover-latest-target" : (self.shouldPlay ? "wait-media-data" : "paused-wait-frame")) latestTarget=\(String(format: "%.3f", recoveryTarget)) source=cached-native-snapshot")
            if shouldRecover {
                self.recoverWedgedSeek(reason: hard ? "callback-without-new-frame-hard" : "callback-without-new-frame", fallbackTarget: recoveryTarget, playerGeneration: playerGeneration)
            } else if self.shouldPlay, !hard {
                self.scheduleSeekFrameWatchdog(player: player, seekID: seekID, playerGeneration: playerGeneration, hard: true)
            }
        }
    }

    private func latestDesiredTarget(fallback: Double) -> Double {
        max(0, queuedLatestSeek?.target ?? pendingSeekResume?.target ?? activeNativeSeek?.target ?? fallback)
    }

    private func recoverWedgedSeek(reason: String, fallbackTarget: Double, playerGeneration: Int) {
        guard playerGeneration == generation, player != nil else { return }
        let recoveryTarget = latestDesiredTarget(fallback: fallbackTarget)
        DiagnosticsLogger.shared.playback("MDKSeekWedge", "reason=\(reason) active=\(activeNativeSeek?.id ?? -1) queued=\(queuedLatestSeek?.id ?? -1) latestTarget=\(String(format: "%.3f", recoveryTarget)) action=rebuild-player-at-latest-target")
        transportHTTPServer?.resetClientStreams(reason: "mdk-seek-wedge-\(reason)")
        activeNativeSeek = nil
        queuedLatestSeek = nil
        reload(at: recoveryTarget)
    }

    private func scheduleRateHealth(player: swift_mdk.Player, generation: Int, requested: Double, startedAt: TimeInterval, startPosition: Double, delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak player] in
            guard let self, let player, self.rateGeneration == generation, self.currentPlayerReference() === player else { return }
            let elapsed = max(0.001, CACurrentMediaTime() - startedAt)
            let currentPosition = self.lastNativePosition
            let actualRate = max(0, (currentPosition - startPosition) / elapsed)
            DiagnosticsLogger.shared.playback("MDKRateHealth", "requested=\(String(format: "%.2f", requested)) actual=\(String(format: "%.2f", actualRate)) sample=\(String(format: "%.1f", elapsed))s position=\(String(format: "%.3f", currentPosition)) status=0x\(String(self.lastNativeStatus, radix: 16)) playing=\(self.lastNativeIsPlaying) sourceFPS=\(self.sourceFrameRateText) decoder=VT source=cached-native-snapshot mainNativeCall=false")
        }
    }

    private func recordRenderedFrame(_ renderResult: Double) {
        if renderResult.isFinite, renderResult >= 0 {
            hasRenderedValidFrame = true
            lastRenderedFrameAt = CACurrentMediaTime()
        }
        if prematureEOFRecoveryActive, renderResult.isFinite, renderResult >= 0 {
            prematureEOFRecoveryActive = false
            DiagnosticsLogger.shared.playback("MDKRecovery", "action=reprepare-first-frame recoveryComplete=true")
        }
        if firstRenderedGeneration != generation {
            firstRenderedGeneration = generation
            DiagnosticsLogger.shared.playback("MDKFrame", "firstFrameSubmitted generation=\(generation) renderResult=\(renderResult) drawable=\(Int(view.currentPixelSize.width))x\(Int(view.currentPixelSize.height))")
        }
        guard renderResult.isFinite, renderResult >= 0 else { return }
        if let previous = lastRenderedTimestamp, abs(previous - renderResult) < 0.000_001 { return }
        lastRenderedTimestamp = renderResult
        renderedFrameSerial &+= 1
        guard let pending = pendingSeekResume, let callbackAt = pending.callbackAt, let callbackFrameSerial = pending.callbackFrameSerial, renderedFrameSerial > callbackFrameSerial else { return }
        let now = Date().timeIntervalSince1970
        let playerPosition: Double? = currentPlayerReference() == nil ? nil : lastNativePosition
        let callbackLatency = (callbackAt - pending.requestedAt) * 1_000
        let totalLatency = (now - pending.requestedAt) * 1_000
        let afterCallback = (now - callbackAt) * 1_000
        DiagnosticsLogger.shared.playback("MDKSeekFrame", "id=\(pending.id) target=\(String(format: "%.3f", pending.target)) renderTimestamp=\(String(format: "%.6f", renderResult)) renderPosition=\(playerPosition.map { String(format: "%.3f", $0) } ?? "unknown") totalMs=\(String(format: "%.1f", totalLatency)) afterCallbackMs=\(String(format: "%.1f", afterCallback)) frameSerial=\(renderedFrameSerial) action=visual-seek-complete")
        onSeekCompleted?(SeekResult(requestedAt: pending.requestedAt, target: pending.target, actualPosition: playerPosition ?? pending.callbackPosition, bufferHit: callbackLatency < 150, completionLatencyMs: totalLatency, measurement: "MDK first rendered frame after latest seek callback"))
        pendingSeekResume = nil
    }

    private func applyHTTPHeaders(_ headers: [String: String], to player: swift_mdk.Player) {
        guard !headers.isEmpty else { return }
        let value = headers.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }.map { "\($0.key): \($0.value)" }.joined(separator: "\r\n") + "\r\n"
        player.setProperty(name: "avio.headers", value: value)
        player.setProperty(name: "avformat.headers", value: value)
    }

    private func configureMDKIOIfNeeded() {
        guard !didConfigureGlobalIO else { return }
        didConfigureGlobalIO = true
        swift_mdk.setGlobalOption(name: "io.avio", value: 1)
        DiagnosticsLogger.shared.playback("MDKIO", "mode=ffmpeg-native-avio option=io.avio value=1 customAVIO=false transport=unified-localhost-ab")
    }

    private func installMDKLoggingIfNeeded() {
        guard !didInstallLogHandler else { return }
        didInstallLogHandler = true
        swift_mdk.logLevel = .Info
        swift_mdk.setLogHandler { level, message in
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if let marker = trimmed.range(of: "***buffering progress "), let percentEnd = trimmed[marker.upperBound...].firstIndex(of: "%"), let percent = Int(trimmed[marker.upperBound..<percentEnd]), percent != 0, percent != 25, percent != 50, percent != 75, percent != 100 { return }
            DiagnosticsLogger.shared.playback("MDKNative", "level=\(String(describing: level)) \(trimmed)")
        }
    }

    private var sourceFrameRateText: String {
        let video = source.mediaSource.mediaStreams?.first(where: { $0.type?.caseInsensitiveCompare("Video") == .orderedSame })
        let fps = video?.averageFrameRate ?? video?.realFrameRate
        return fps.map { String(format: "%.3f", $0) } ?? "unknown"
    }

    private var mediaFileExtension: String {
        let container = source.mediaSource.normalizedContainer
        return container.isEmpty ? "mkv" : container
    }

    private func hasStatus(_ raw: Int32, bit: Int32) -> Bool { UInt32(bitPattern: raw) & (UInt32(1) << UInt32(bit)) != 0 }
    private func isPrepared(_ raw: Int32) -> Bool { hasStatus(raw, bit: 2) || hasStatus(raw, bit: 8) }
    private func seconds(_ milliseconds: Int64) -> Double { max(0, Double(milliseconds) / 1_000) }
    private func milliseconds(_ seconds: Double) -> Int64 { Int64((max(0, seconds) * 1_000).rounded()) }

    private func stopPlayerOnly() {
        stateTimer?.cancel()
        stateTimer = nil
        renderWatchdogTimer?.invalidate()
        renderWatchdogTimer = nil
        transportPrepareTask?.cancel()
        transportPrepareTask = nil
        let server = transportHTTPServer
        transportHTTPServer = nil
        server?.stop()
        seekGeneration &+= 1
        let activeSeekID = activeNativeSeek?.id
        pendingSeekResume = nil
        activeNativeSeek = nil
        queuedLatestSeek = nil
        seekBufferingGraceStartedAt = nil
        seekBufferingGraceID = nil
        seekBufferingGraceTarget = nil
        didLogSeekBufferingGraceID = nil
        let oldRenderer = renderer
        oldRenderer.detach()
        guard let oldPlayer = takePlayer() else { return }
        let teardownStartedAt = CACurrentMediaTime()
        DiagnosticsLogger.shared.playback("MDKTeardown", "phase=ui-detached generation=\(generation) activeSeek=\(activeSeekID ?? -1) action=isolated-native-stop mainResponsive=true")
        DispatchQueue.global(qos: .utility).async {
            oldRenderer.invalidateNative(oldPlayer)
            oldPlayer.state = .Stopped
            let elapsed = (CACurrentMediaTime() - teardownStartedAt) * 1_000
            DiagnosticsLogger.shared.playback("MDKTeardown", "phase=native-stop-finished ms=\(String(format: "%.1f", elapsed)) activeSeek=\(activeSeekID ?? -1) mainThread=false")
        }
    }
}
#endif