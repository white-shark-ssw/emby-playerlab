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

private final class MDKNativeQuarantineStore {
    static let shared = MDKNativeQuarantineStore()
    private let lock = NSLock()
    private var retainedObjects: [AnyObject] = []

    func retain(_ objects: AnyObject...) {
        lock.lock()
        retainedObjects.append(contentsOf: objects)
        let count = retainedObjects.count
        lock.unlock()
        DiagnosticsLogger.shared.playback("MDKNativeIsolation", "operation=quarantine-retain objects=\(count) action=skip-native-destroy")
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
        var fastPreview = false
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
    private var renderWatchdogTimer: DispatchSourceTimer?
    private let watchdogQueue = DispatchQueue(label: "OnePlayer.MDK.Watchdog", qos: .userInitiated)
    private let healthCoordinator = MDKPlaybackHealthCoordinator()
    private let renderHealthLock = NSLock()
    private var nativeRenderedFrameSerial: UInt64 = 0
    private var nativeLastRenderedFrameAt = CACurrentMediaTime()
    private var nativeRenderedGeneration = -1
    private let renderDispatchLock = NSLock()
    private var renderDispatchPending = false
    private var latestRenderResult: Double?
    private let renderStateDispatchInterval: TimeInterval = 1.0 / 30.0
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
    private let normalBufferMinMs: Int64 = 1_000
    private let seekBufferMinMs: Int64 = 200
    private let relativeSeekBufferMinMs: Int64 = 50
    private var seekLowLatencyBufferActive = false
    private let activeNativeSeekFastWatchdogSeconds: TimeInterval = 1.0
    private let activeNativeSeekWatchdogSeconds: TimeInterval = 2.0
    private let activeNativeSeekHardWatchdogSeconds: TimeInterval = 5.0
    private let seekFrameWatchdogSeconds: TimeInterval = 1.5
    private let seekFrameHardWatchdogSeconds: TimeInterval = 4.0
    private let ignoredSeekSettleCheckSeconds: TimeInterval = 0.18
    private let ignoredSeekSettleHardLimitSeconds: TimeInterval = 0.72
    private var lastUserSeekRequestedAt: TimeInterval?
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
    private var nativeQuarantineActive = false
    private let prepareWatchdogSeconds: TimeInterval = 3.0
    private let coldResumePrepareRecheckSeconds: TimeInterval = 2.0
    private let coldResumePrepareHardLimitSeconds: TimeInterval = 20.0
    private let firstFrameWatchdogSeconds: TimeInterval = 2.0
    private let coldResumeFirstFrameRecheckSeconds: TimeInterval = 1.0
    private let coldResumeFirstFrameHardLimitSeconds: TimeInterval = 12.0
    private let endConfirmationSeconds: TimeInterval = 1.0
    private let renderWatchdogPollSeconds: TimeInterval = 0.25
    private let renderWatchdogTimeoutSeconds: TimeInterval = 2.5
    private let avioShortSeekSizeBytes = 2 * 1_048_576
    private let avioRequestSizeBytes = 2 * 1_048_576
    private let trueHDStartupFallbackSeconds: TimeInterval = 2.0
    private var trueHDStartupFallbackArmedAt: TimeInterval?
    private var trueHDStartupFallbackAttempted = false
    private var preparingGeneration: Int?
    private var preparedGeneration = -1
    private var endCandidateSince: TimeInterval?
    private var endCandidatePosition: Double = 0
    private var endCandidateFrameSerial: UInt64 = 0
    private var inputTraceSession = "unassigned"
    private var inputTraceSource = "unknown"
    private var inputTraceLastSecond = -1
    private var inputTraceDidLogConfirmedEnd = false

    var playerView: UIView? { view }

    init(source: ResolvedPlaybackSource, client: EmbyAPIClient, configuration: MediaTransportConfiguration, sharedTransportSession: TransportDataSession? = nil, ktvCacheSession: KTVCachePlaybackSession? = nil) {
        self.source = source
        self.sharedTransportSession = sharedTransportSession
        let renderView = MDKRenderView()
        guard let renderer = PlayerMetalLayerRenderer(layer: renderView.metalLayer) else { fatalError("Metal is unavailable") }
        self.view = renderView
        self.renderer = renderer
        configureRenderer(renderer, generation: 0)
        renderView.onSurfaceChanged = { [weak self] size in self?.surfaceDidChange(size) }
        _ = client
        _ = configuration
        _ = ktvCacheSession
    }

    private func configureRenderer(_ renderer: PlayerMetalLayerRenderer, generation rendererGeneration: Int) {
        renderer.onFrameSubmitted = { [weak self, weak renderer] result in
            guard let self else { return }
            self.renderHealthLock.lock()
            if rendererGeneration == self.generation {
                self.nativeRenderedFrameSerial &+= 1
                self.nativeLastRenderedFrameAt = CACurrentMediaTime()
                self.nativeRenderedGeneration = rendererGeneration
            }
            self.renderHealthLock.unlock()
            self.renderDispatchLock.lock()
            self.latestRenderResult = result
            if self.renderDispatchPending { self.renderDispatchLock.unlock(); return }
            self.renderDispatchPending = true
            self.renderDispatchLock.unlock()
            DispatchQueue.main.asyncAfter(deadline: .now() + self.renderStateDispatchInterval) { [weak self, weak renderer] in
                guard let self else { return }
                self.renderDispatchLock.lock()
                let latest = self.latestRenderResult ?? result
                self.latestRenderResult = nil
                self.renderDispatchPending = false
                self.renderDispatchLock.unlock()
                guard let renderer, rendererGeneration == self.generation, self.renderer === renderer else {
                    DiagnosticsLogger.shared.playback("MDKNativeIsolation", "operation=discard-stale-render-callback callbackGeneration=\(rendererGeneration) action=no-state-mutation")
                    return
                }
                self.recordRenderedFrame(latest)
            }
        }
        renderer.onRenderCompleted = { [weak self, weak renderer] elapsedMs in
            guard let self, let renderer, rendererGeneration == self.generation, self.renderer === renderer, elapsedMs >= 250 else { return }
            DiagnosticsLogger.shared.playback("MDKNativeIsolation", "operation=render completedMs=\(String(format: "%.1f", elapsedMs)) generation=\(rendererGeneration) mainThread=false")
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
        let currentGeneration = generation
        guard preparedGeneration == currentGeneration, let player = currentPlayerReference() else {
            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\(currentGeneration) phase=surface-deferred prepared=\(preparedGeneration == currentGeneration)")
            return
        }
        let renderer = self.renderer
        let queue = nativeControlQueue
        queue.async { [weak self, weak player] in
            guard let self, let player, self.preparedGeneration == currentGeneration, self.isCurrentPlayer(player, generation: currentGeneration) else { return }
            renderer.setSurfaceSize(size, player: player)
        }
    }

    private func requestPlayerState(playing: Bool, expectedPlayer: swift_mdk.Player? = nil, generation expectedGeneration: Int? = nil) {
        guard let player = expectedPlayer ?? currentPlayerReference() else { return }
        let currentGeneration = expectedGeneration ?? generation
        guard preparedGeneration == currentGeneration else {
            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\(currentGeneration) phase=state-deferred requested=\(playing ? "playing" : "paused")")
            return
        }
        let queue = nativeControlQueue
        queue.async { [weak self, weak player] in
            guard let self, let player, self.preparedGeneration == currentGeneration, self.isCurrentPlayer(player, generation: currentGeneration) else { return }
            player.state = playing ? .Playing : .Paused
        }
    }

    private func startRenderWatchdog() {
        renderWatchdogTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: watchdogQueue)
        timer.schedule(deadline: .now() + renderWatchdogPollSeconds, repeating: renderWatchdogPollSeconds, leeway: .milliseconds(50))
        timer.setEventHandler { [weak self] in self?.evaluateRenderLiveness() }
        renderWatchdogTimer = timer
        timer.resume()
    }

    private func nativeRenderHealth() -> (serial: UInt64, lastAt: TimeInterval, generation: Int) {
        renderHealthLock.lock()
        let value = (nativeRenderedFrameSerial, nativeLastRenderedFrameAt, nativeRenderedGeneration)
        renderHealthLock.unlock()
        return value
    }

    private func evaluateRenderLiveness() {
        let currentGeneration = generation
        guard shouldPlay, preparedGeneration == currentGeneration, !lastNativeBuffering else { return }
        guard activeNativeSeek == nil, pendingSeekResume == nil else { return }
        let health = nativeRenderHealth()
        guard health.generation == currentGeneration, health.serial > 0 else { return }
        let age = CACurrentMediaTime() - health.lastAt
        guard age >= renderWatchdogTimeoutSeconds else { return }
        submitHealthCandidate(.renderTimeout(generation: currentGeneration), fallbackPosition: lastRenderedTimestamp ?? lastNativePosition, message: "MDK renderer made no progress")
    }

    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double) {
        stopPlayerOnly()
        generation &+= 1
        let currentGeneration = generation
        healthCoordinator.reset(generation: currentGeneration)
        healthCoordinator.beginPrepare(generation: currentGeneration)
        inputTraceSession = String(UUID().uuidString.prefix(8)).lowercased()
        inputTraceSource = sharedTransportSession != nil ? "http-unified-localhost" : (url.isFileURL ? "file" : "http-direct")
        inputTraceLastSecond = -1
        inputTraceDidLogConfirmedEnd = false
        DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\(inputTraceSession) source=\(inputTraceSource) event=open generation=\(currentGeneration) start=\(String(format: "%.3f", startPosition)) scheme=\(url.scheme ?? "nil") bytes=\(source.mediaSource.size ?? 0)")
        nativeControlQueue = DispatchQueue(label: "OnePlayer.MDK.NativeControl.\(currentGeneration)", qos: .userInitiated)
        guard let newRenderer = PlayerMetalLayerRenderer(layer: view.metalLayer) else { return }
        renderer = newRenderer
        configureRenderer(newRenderer, generation: currentGeneration)
        self.preferredForwardBuffer = preferredForwardBuffer
        lastURL = url
        lastHeaders = headers
        pendingSeekResume = nil
        activeNativeSeek = nil
        queuedLatestSeek = nil
        lastUserSeekRequestedAt = nil
        renderedFrameSerial = 0
        lastRenderedTimestamp = nil
        seekBufferingGraceStartedAt = nil
        seekBufferingGraceID = nil
        seekBufferingGraceTarget = nil
        didLogSeekBufferingGraceID = nil
        seekLowLatencyBufferActive = false
        prematureEOFRecoveryActive = false
        hasRenderedValidFrame = false
        lastRenderedFrameAt = CACurrentMediaTime()
        renderHealthLock.lock()
        nativeRenderedFrameSerial = 0
        nativeLastRenderedFrameAt = CACurrentMediaTime()
        nativeRenderedGeneration = currentGeneration
        renderHealthLock.unlock()
        lastNativeBuffering = false
        lastNativePosition = max(0, startPosition)
        lastNativeDuration = source.mediaSource.durationSeconds ?? 0
        lastNativeStatus = 0
        lastNativeBufferMs = 0
        lastNativeIsPlaying = false
        lastNativeEnded = false
        preparingGeneration = currentGeneration
        preparedGeneration = -1
        endCandidateSince = nil
        endCandidatePosition = max(0, startPosition)
        endCandidateFrameSerial = 0
        trueHDStartupFallbackArmedAt = nil
        trueHDStartupFallbackAttempted = false
        installMDKLoggingIfNeeded()
        configureMDKIOIfNeeded()
        DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\(currentGeneration) phase=probation-start start=\(String(format: "%.3f", startPosition)) rendererBound=false statePoll=false")

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
        guard preparedGeneration == currentPlayerGeneration else {
            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\(currentPlayerGeneration) phase=rate-deferred requested=\(String(format: "%.2f", clamped))")
            return
        }
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
        guard preparedGeneration == generation else {
            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\(generation) phase=seek-deferred target=\(String(format: "%.3f", target))")
            return
        }
        let duration = max(source.mediaSource.durationSeconds ?? 0, lastNativeDuration)
        let requestedAt = Date().timeIntervalSince1970
        let currentPlayerGeneration = generation
        let previousUserSeekAt = lastUserSeekRequestedAt
        let fastPreview: Bool
        switch direction {
        case .forward, .backward: fastPreview = true
        case .absolute: fastPreview = false
        }
        lastUserSeekRequestedAt = requestedAt
        seekGeneration &+= 1
        let seekID = seekGeneration
        var intent = NativeSeekIntent(id: seekID, target: target, duration: duration, requestedAt: requestedAt, direction: direction, playerGeneration: currentPlayerGeneration)
        intent.fastPreview = fastPreview
        pendingSeekResume = PendingSeekResume(id: seekID, target: target, requestedAt: requestedAt, callbackAt: nil, callbackPosition: nil, callbackFrameSerial: nil)
        DiagnosticsLogger.shared.playback("MDKSeekMode", "id=\(seekID) target=\(String(format: "%.3f", target)) mode=\(fastPreview ? "relative-fast-only" : "absolute-accurate") previousGapMs=\(previousUserSeekAt.map { Int((requestedAt - $0) * 1_000) } ?? -1) preciseSettle=disabled")
        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(seekID) target=\(String(format: "%.3f", target)) phase=request generation=\(currentPlayerGeneration) nativeOutstanding=\(nativeSeekOutstandingCount) unifiedTransport=\(sharedTransportSession != nil) direction=\(String(describing: direction))")
        DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\(inputTraceSession) source=\(inputTraceSource) event=seek-request seekID=\(seekID) target=\(String(format: "%.3f", target)) position=\(String(format: "%.3f", lastNativePosition)) generation=\(currentPlayerGeneration) frameSerial=\(renderedFrameSerial) raw=0x\(String(lastNativeStatus, radix: 16))")

        if let activeNativeSeek {
            let replaced = queuedLatestSeek?.id
            queuedLatestSeek = intent
            DiagnosticsLogger.shared.playback("MDKSeekCoalesce", "latest=\(seekID) target=\(String(format: "%.3f", target)) active=\(activeNativeSeek.id) replacedQueued=\(replaced.map { String($0) } ?? "none") action=queue-latest-single-native")
            return
        }
        dispatchNativeSeek(intent, player: player)
    }

    private var nativeSeekOutstandingCount: Int { (activeNativeSeek == nil ? 0 : 1) + (queuedLatestSeek == nil ? 0 : 1) }

    private func dispatchNativeSeek(_ intent: NativeSeekIntent, player: swift_mdk.Player) {
        guard intent.playerGeneration == generation, self.player === player else { return }
        activeNativeSeek = intent
        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(intent.id) target=\(String(format: "%.3f", intent.target)) phase=native-arm retry=\(intent.retryCount) nativeOutstanding=\(nativeSeekOutstandingCount)")

        if let session = sharedTransportSession {
            DiagnosticsLogger.shared.playback("MDKSeekHTTP", "id=\(intent.id) action=preserve-existing-stream-before-native-seek")
            Task { @MainActor [weak self, weak player] in
                let priorityStartedAt = Date().timeIntervalSince1970
                DiagnosticsLogger.shared.playback("MDKSeekTransportGate", "id=\(intent.id) target=\(String(format: "%.3f", intent.target)) phase=begin")
                await session.prioritizeSeek(position: intent.target, duration: intent.duration)
                let priorityMs = (Date().timeIntervalSince1970 - priorityStartedAt) * 1_000
                DiagnosticsLogger.shared.playback("MDKSeekTransportGate", "id=\(intent.id) target=\(String(format: "%.3f", intent.target)) phase=end waitMs=\(String(format: "%.1f", priorityMs))")
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
        healthCoordinator.beginNativeSeek(generation: dispatchedIntent.playerGeneration, seekID: dispatchedIntent.id, target: dispatchedIntent.target, renderSerial: renderedFrameSerial)
        DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\(inputTraceSession) source=\(inputTraceSource) event=seek-native-start seekID=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) position=\(String(format: "%.3f", lastNativePosition)) retry=\(dispatchedIntent.retryCount) frameSerial=\(renderedFrameSerial) raw=0x\(String(lastNativeStatus, radix: 16))")
        seekBufferingGraceStartedAt = nativeStartedAt
        seekBufferingGraceID = dispatchedIntent.id
        seekBufferingGraceTarget = dispatchedIntent.target
        didLogSeekBufferingGraceID = nil
        seekLowLatencyBufferActive = true

        let queue = nativeControlQueue
        queue.async { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: dispatchedIntent.playerGeneration) else { return }
            let activeSeekBufferMinMs: Int64
            switch dispatchedIntent.direction {
            case .forward, .backward: activeSeekBufferMinMs = self.relativeSeekBufferMinMs
            case .absolute: activeSeekBufferMinMs = self.seekBufferMinMs
            }
            player.setBufferRange(msMin: activeSeekBufferMinMs, msMax: Int64(max(3_000, min(30_000, self.preferredForwardBuffer * 1_000))), drop: false)
            DiagnosticsLogger.shared.playback("MDKSeekBuffer", "id=\(dispatchedIntent.id) phase=low-latency minMs=\(activeSeekBufferMinMs) relativeMinMs=\(self.relativeSeekBufferMinMs) accurateMinMs=\(self.seekBufferMinMs) normalMinMs=\(self.normalBufferMinMs) direction=\(String(describing: dispatchedIntent.direction))")
            let seekFlag: SeekFlag = dispatchedIntent.fastPreview ? .AccurateFromStartInCache : .FromStart
            DiagnosticsLogger.shared.playback("MDKSeekMode", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) nativeMode=\(dispatchedIntent.fastPreview ? "accurate-incache" : "accurate") flagRaw=\(seekFlag.rawValue) cacheAware=\(dispatchedIntent.fastPreview) retry=\(dispatchedIntent.retryCount)")
            let immediateResult = player.seek(self.milliseconds(dispatchedIntent.target), flags: seekFlag) { [weak self, weak player] actualMs in
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
                    self.healthCoordinator.finishNativeSeek(generation: dispatchedIntent.playerGeneration, seekID: dispatchedIntent.id)
                    let isCurrent = self.pendingSeekResume?.id == dispatchedIntent.id
                    DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\(self.inputTraceSession) source=\(self.inputTraceSource) event=seek-callback seekID=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) resultMs=\(actualMs) requestMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) current=\(isCurrent) position=\(String(format: "%.3f", self.lastNativePosition)) frameSerial=\(self.renderedFrameSerial) raw=0x\(String(self.lastNativeStatus, radix: 16))")
                    if actualMs >= 0 {
                        let actual = self.seconds(actualMs)
                        if var pending = self.pendingSeekResume, pending.id == dispatchedIntent.id {
                            pending.callbackAt = callbackAt
                            pending.callbackPosition = actual
                            pending.callbackFrameSerial = self.renderedFrameSerial
                            self.pendingSeekResume = pending
                            self.healthCoordinator.beginSeekFrame(generation: dispatchedIntent.playerGeneration, seekID: dispatchedIntent.id, target: dispatchedIntent.target, callbackLanding: actual, renderSerial: self.renderedFrameSerial)
                            self.scheduleSeekFrameWatchdog(player: player, seekID: dispatchedIntent.id, playerGeneration: dispatchedIntent.playerGeneration, hard: false)
                        }
                        if isCurrent, self.shouldPlay { self.requestPlayerState(playing: true, expectedPlayer: player, generation: dispatchedIntent.playerGeneration) }
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) actual=\(String(format: "%.3f", actual)) current=\(isCurrent) action=\(isCurrent ? "callback-current-await-frame" : "diagnostic-only") nativeOutstanding=\(self.nativeSeekOutstandingCount) unifiedTransport=\(self.sharedTransportSession != nil) direction=\(String(describing: dispatchedIntent.direction)) nativeQueue=isolated")
                    } else if actualMs == -2, isCurrent, dispatchedIntent.fastPreview {
                        if self.shouldPlay { self.requestPlayerState(playing: true, expectedPlayer: player, generation: dispatchedIntent.playerGeneration) }
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) result=-2 current=true action=preview-ignored-no-retry")
                    } else if actualMs == -2, isCurrent, dispatchedIntent.retryCount < 1 {
                        if var pending = self.pendingSeekResume, pending.id == dispatchedIntent.id {
                            pending.callbackAt = callbackAt
                            pending.callbackPosition = dispatchedIntent.target
                            pending.callbackFrameSerial = self.renderedFrameSerial
                            self.pendingSeekResume = pending
                            self.scheduleSeekFrameWatchdog(player: player, seekID: dispatchedIntent.id, playerGeneration: dispatchedIntent.playerGeneration, hard: false)
                        }
                        if self.shouldPlay { self.requestPlayerState(playing: true, expectedPlayer: player, generation: dispatchedIntent.playerGeneration) }
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) result=-2 current=true action=defer-ignored-settle-check")
                        self.scheduleIgnoredSeekSettleRetry(intent: dispatchedIntent, player: player, startedAt: callbackAt)
                    } else if actualMs == -2 {
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) result=-2 current=false action=ignored-superseded-no-retry")
                    } else {
                        let recoveryTarget = self.latestDesiredTarget(fallback: dispatchedIntent.target)
                        let message = "MDK session unsafe seek failure"
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) result=\(actualMs) current=\(isCurrent) action=submit-fatal-health latestTarget=\(String(format: "%.3f", recoveryTarget))")
                        self.submitHealthCandidate(.fatal(generation: dispatchedIntent.playerGeneration, reason: "seek-negative-\(actualMs)"), fallbackPosition: recoveryTarget, message: message)
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

    private func scheduleIgnoredSeekSettleRetry(intent: NativeSeekIntent, player: swift_mdk.Player, startedAt: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + ignoredSeekSettleCheckSeconds) { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: intent.playerGeneration), self.pendingSeekResume?.id == intent.id else {
                return
            }
            let elapsed = Date().timeIntervalSince1970 - startedAt
            if let rendered = self.lastRenderedTimestamp, abs(rendered - intent.target) <= 1.0 {
                DiagnosticsLogger.shared.playback("MDKSeekSettle", "id=\(intent.id) target=\(String(format: "%.3f", intent.target)) elapsedMs=\(Int(elapsed * 1_000)) rendered=\(String(format: "%.3f", rendered)) action=settled-without-retry")
                return
            }
            let nativeSeeking = self.hasStatus(self.lastNativeStatus, bit: 7)
            if nativeSeeking, elapsed < self.ignoredSeekSettleHardLimitSeconds {
                DiagnosticsLogger.shared.playback("MDKSeekSettle", "id=\(intent.id) target=\(String(format: "%.3f", intent.target)) elapsedMs=\(Int(elapsed * 1_000)) raw=0x\(String(self.lastNativeStatus, radix: 16)) action=wait-native-seeking")
                self.scheduleIgnoredSeekSettleRetry(intent: intent, player: player, startedAt: startedAt)
                return
            }
            guard self.activeNativeSeek == nil else {
                DiagnosticsLogger.shared.playback("MDKSeekSettle", "id=\(intent.id) target=\(String(format: "%.3f", intent.target)) elapsedMs=\(Int(elapsed * 1_000)) active=\(self.activeNativeSeek?.id ?? -1) action=cancel-active-newer")
                return
            }
            var retry = intent
            retry.retryCount += 1
            retry.nativeStartedAt = nil
            retry.nativeStartFrameSerial = nil
            DiagnosticsLogger.shared.playback("MDKSeekSettle", "id=\(intent.id) target=\(String(format: "%.3f", intent.target)) elapsedMs=\(Int(elapsed * 1_000)) raw=0x\(String(self.lastNativeStatus, radix: 16)) action=retry-final-ignored")
            self.dispatchNativeSeek(retry, player: player)
        }
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
            let message = "MDK session unsafe premature EOF"
            DiagnosticsLogger.shared.playback("MDKCompat", "position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) status=0x\(String(status, radix: 16)) action=submit-fatal-health unifiedTransport=\(sharedTransportSession != nil)")
            submitHealthCandidate(.fatal(generation: generation, reason: "confirmed-premature-eof"), fallbackPosition: position, message: message)
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
        healthCoordinator.reset(generation: generation)
        prematureEOFRecoveryActive = false
        abnormalMediaRecoveryLevel = 0
        stopPlayerOnly()
        onSnapshot = nil
        onSeekCompleted = nil
    }

    private func submitHealthCandidate(_ candidate: MDKPlaybackHealthCoordinator.Candidate, fallbackPosition: Double, message: String, recheck: (() -> Void)? = nil) {
        let evaluate: (TransportMetricsSnapshot?) -> Void = { [weak self] metrics in
            guard let self, candidate.generation == self.generation else { return }
            if let metrics {
                self.healthCoordinator.noteTransport(generation: candidate.generation, cacheBytes: metrics.cacheBytes, frontierByte: metrics.schedulerFrontierByte, activeRequests: metrics.activeRequestCount, networkBps: metrics.currentDownloadBytesPerSecond, rangeFailures: metrics.rangeFailureCount)
            }
            let verdict = self.healthCoordinator.evaluate(candidate, shouldPlay: self.shouldPlay, buffering: self.lastNativeBuffering)
            switch verdict {
            case let .ignore(reason):
                DiagnosticsLogger.shared.playback("MDKHealth", "candidate=\(String(describing: candidate)) verdict=ignore reason=\(reason) \(self.healthCoordinator.debugState())")
            case let .defer(reason):
                DiagnosticsLogger.shared.playback("MDKHealth", "candidate=\(String(describing: candidate)) verdict=defer reason=\(reason) \(self.healthCoordinator.debugState())")
                recheck?()
            case let .fail(reason):
                DiagnosticsLogger.shared.playback("MDKHealth", "candidate=\(String(describing: candidate)) verdict=fail reason=\(reason) fallback=\(String(format: "%.3f", fallbackPosition)) \(self.healthCoordinator.debugState())")
                self.commitHealthFailure(reason: reason, position: fallbackPosition, failedGeneration: candidate.generation, message: message)
            }
        }

        if case .fatal = candidate {
            DispatchQueue.main.async { evaluate(nil) }
            return
        }
        guard let session = sharedTransportSession else {
            DispatchQueue.main.async { evaluate(nil) }
            return
        }
        Task { [weak self] in
            let metrics = await session.metrics()
            guard self != nil else { return }
            await MainActor.run { evaluate(metrics) }
        }
    }

    private func commitHealthFailure(reason: String, position: Double, failedGeneration: Int, message: String) {
        guard failedGeneration == generation, currentPlayerReference() != nil else { return }
        nativeQuarantineActive = true
        DiagnosticsLogger.shared.playback("MDKHealth", "generation=\(failedGeneration) commit=fallback reason=\(reason) position=\(String(format: "%.3f", position)) authority=health-coordinator")
        quarantineCurrentGeneration(reason: "health-\(reason)", position: position, failedGeneration: failedGeneration, message: message)
    }

    private func quarantineCurrentGeneration(reason: String, position: Double, failedGeneration: Int, message: String) {
        guard failedGeneration == generation, let oldPlayer = currentPlayerReference() else { return }
        let oldRenderer = renderer
        preparingGeneration = nil
        preparedGeneration = -1
        endCandidateSince = nil
        stateTimer?.cancel()
        stateTimer = nil
        renderWatchdogTimer?.cancel()
        renderWatchdogTimer = nil
        renderDispatchLock.lock()
        renderDispatchPending = false
        latestRenderResult = nil
        renderDispatchLock.unlock()
        transportPrepareTask?.cancel()
        transportPrepareTask = nil
        let server = transportHTTPServer
        transportHTTPServer = nil
        server?.stop()
        seekGeneration &+= 1
        pendingSeekResume = nil
        activeNativeSeek = nil
        queuedLatestSeek = nil
        seekBufferingGraceStartedAt = nil
        seekBufferingGraceID = nil
        seekBufferingGraceTarget = nil
        didLogSeekBufferingGraceID = nil
        seekLowLatencyBufferActive = false
        hasRenderedValidFrame = false
        oldRenderer.detach()
        guard takePlayer() === oldPlayer else { return }
        generation &+= 1
        rateGeneration &+= 1
        healthCoordinator.reset(generation: generation)
        nativeQuarantineActive = false
        MDKNativeQuarantineStore.shared.retain(oldPlayer, oldRenderer)
        DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\(failedGeneration) phase=quarantine reason=\(reason) position=\(String(format: "%.3f", position)) action=switch-mpv skipNativeStop=true")
        onSnapshot?(PlayerSnapshot(position: max(0, position), duration: max(lastNativeDuration, source.mediaSource.durationSeconds ?? 0), isPlaying: false, isBuffering: false, errorMessage: message))
    }

    private func activatePreparedPlayer(_ player: swift_mdk.Player, renderer: PlayerMetalLayerRenderer, surfaceSize: CGSize, generation currentGeneration: Int, preparedAtMs: Int64, requestedStart: Double, compatLevel: Int, decoderList: [String], transportMode: String, prepareStartedAt: TimeInterval) {
        guard preparingGeneration == currentGeneration, isCurrentPlayer(player, generation: currentGeneration) else { return }
        preparingGeneration = nil
        preparedGeneration = currentGeneration
        healthCoordinator.beginFirstFrame(generation: currentGeneration, renderSerial: nativeRenderHealth().serial)
        endCandidateSince = nil
        trueHDStartupFallbackArmedAt = CACurrentMediaTime()
        let elapsedMs = (CACurrentMediaTime() - prepareStartedAt) * 1_000
        DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\(currentGeneration) phase=prepared-activate callbackMs=\(String(format: "%.1f", elapsedMs)) preparedAtMs=\(preparedAtMs) rendererBound=false statePoll=false")
        let queue = nativeControlQueue
        queue.async { [weak self, weak player, weak renderer] in
            guard let self, let player, let renderer, self.preparedGeneration == currentGeneration, self.isCurrentPlayer(player, generation: currentGeneration) else { return }
            self.attachCallbacks(to: player, generation: currentGeneration)
            renderer.prepareSurfaceSize(surfaceSize)
            renderer.bind(player)
            renderer.setSurfaceSize(surfaceSize, player: player)
            player.playbackRate = Float(self.playbackRate)
            if self.shouldPlay { player.state = .Playing }
            self.startStateTimer(player: player, generation: currentGeneration, queue: self.nativeControlQueue)
            self.startRenderWatchdog()
            self.scheduleFirstFrameWatchdog(player: player, generation: currentGeneration, startPosition: requestedStart)
            DiagnosticsLogger.shared.playback("MDKPrepare", "preparedAtMs=\(preparedAtMs) requestedStart=\(String(format: "%.3f", requestedStart)) sourceFPS=\(self.sourceFrameRateText) compatLevel=\(compatLevel) videoDecoders=\(decoderList.joined(separator: ",")) transport=\(transportMode) probation=passed rendererBound=true statePoll=true renderBridge=offscreen-texture watchdogQueue=independent")
        }
    }

    private func schedulePrepareWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double, startedAt: TimeInterval) {
        watchdogQueue.asyncAfter(deadline: .now() + prepareWatchdogSeconds) { [weak self, weak player] in
            guard let self, let player else { return }
            self.evaluatePrepareWatchdog(player: player, generation: currentGeneration, startPosition: startPosition, startedAt: startedAt)
        }
    }

    private func evaluatePrepareWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double, startedAt: TimeInterval) {
        guard preparingGeneration == currentGeneration, isCurrentPlayer(player, generation: currentGeneration) else { return }
        submitHealthCandidate(
            .prepareTimeout(generation: currentGeneration),
            fallbackPosition: startPosition,
            message: "MDK prepare made no progress",
            recheck: { [weak self, weak player] in
                guard let self, let player else { return }
                self.watchdogQueue.asyncAfter(deadline: .now() + 1.0) { [weak self, weak player] in
                    guard let self, let player else { return }
                    self.evaluatePrepareWatchdog(player: player, generation: currentGeneration, startPosition: startPosition, startedAt: startedAt)
                }
            }
        )
    }

    private func scheduleFirstFrameWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double) {
        let startSerial = nativeRenderHealth().serial
        let startedAt = CACurrentMediaTime()
        watchdogQueue.asyncAfter(deadline: .now() + firstFrameWatchdogSeconds) { [weak self, weak player] in
            guard let self, let player else { return }
            self.evaluateFirstFrameWatchdog(player: player, generation: currentGeneration, startPosition: startPosition, startSerial: startSerial, startedAt: startedAt)
        }
    }

    private func evaluateFirstFrameWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double, startSerial: UInt64, startedAt: TimeInterval) {
        guard preparedGeneration == currentGeneration, isCurrentPlayer(player, generation: currentGeneration), shouldPlay else { return }
        let renderHealth = nativeRenderHealth()
        guard renderHealth.generation == currentGeneration, renderHealth.serial <= startSerial else { return }
        submitHealthCandidate(
            .firstFrameTimeout(generation: currentGeneration),
            fallbackPosition: max(startPosition, lastRenderedTimestamp ?? lastNativePosition),
            message: "MDK first frame made no progress",
            recheck: { [weak self, weak player] in
                guard let self, let player else { return }
                self.watchdogQueue.asyncAfter(deadline: .now() + 1.0) { [weak self, weak player] in
                    guard let self, let player else { return }
                    self.evaluateFirstFrameWatchdog(player: player, generation: currentGeneration, startPosition: startPosition, startSerial: startSerial, startedAt: startedAt)
                }
            }
        )
    }

    private func startMDKPlayer(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double, generation currentGeneration: Int, transportMode: String) {
        guard currentGeneration == generation else { return }
        let player = swift_mdk.Player()
        installPlayer(player)
        let renderer = self.renderer
        let queue = nativeControlQueue
        let surfaceSize = view.currentPixelSize
        let prepareStartedAt = CACurrentMediaTime()
        schedulePrepareWatchdog(player: player, generation: currentGeneration, startPosition: startPosition, startedAt: prepareStartedAt)
        queue.async { [weak self, weak player, weak renderer] in
            guard let self, let player, let renderer, self.preparingGeneration == currentGeneration, self.isCurrentPlayer(player, generation: currentGeneration) else { return }
            let compatLevel = self.abnormalMediaRecoveryLevel
            let decoderList = compatLevel >= 2 ? ["FFmpeg", "VT"] : ["VT", "FFmpeg"]
            player.videoDecoders = decoderList
            player.playbackRate = Float(self.playbackRate)
            player.setBufferRange(msMin: self.normalBufferMinMs, msMax: Int64(max(3_000, min(30_000, preferredForwardBuffer * 1_000))), drop: false)
            self.applyHTTPHeaders(headers, to: player)
            player.setProperty(name: "keep_open", value: "1")
            player.setProperty(name: "avio.multiple_requests", value: "1")
            player.setProperty(name: "avio.request_size", value: String(avioRequestSizeBytes))
            player.setProperty(name: "avio.short_seek_size", value: String(avioShortSeekSizeBytes))
            DiagnosticsLogger.shared.playback("MDKAVIO", "generation=\(currentGeneration) multipleRequests=1 requestSize=\(avioRequestSizeBytes) shortSeekSize=\(avioShortSeekSizeBytes) reconnect=off-localhost transport=\(transportMode)")
            DiagnosticsLogger.shared.playback("MDKAVIOExperiment", "generation=\(currentGeneration) boundedRequest2MiB=true source=build115-forced shortSeekSize=\(avioShortSeekSizeBytes)")
            if compatLevel >= 2 {
                player.setProperty(name: "avformat.err_detect", value: "ignore_err")
                player.setProperty(name: "avformat.fflags", value: "+discardcorrupt")
            }
            let compatProfile = compatLevel == 0 ? "normal" : (compatLevel == 1 ? "fresh-player" : "software-tolerant")
            DiagnosticsLogger.shared.playback("MDKCompat", "generation=\(currentGeneration) level=\(compatLevel) profile=\(compatProfile) videoDecoders=\(decoderList.joined(separator: ",")) avformatTolerance=\(compatLevel >= 2 ? "ignore_err+discardcorrupt" : "off") globalDemuxTolerance=off")
            player.media = url.absoluteString
            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\(currentGeneration) phase=prepare-dispatch start=\(String(format: "%.3f", startPosition)) rendererBound=false statePoll=false nativeQueue=isolated")
            player.prepare(from: self.milliseconds(startPosition), complete: { [weak self, weak player, weak renderer] preparedAtMs, boost in
                boost = true
                guard let self, let player, let renderer else { return false }
                self.activatePreparedPlayer(player, renderer: renderer, surfaceSize: surfaceSize, generation: currentGeneration, preparedAtMs: preparedAtMs, requestedStart: startPosition, compatLevel: compatLevel, decoderList: decoderList, transportMode: transportMode, prepareStartedAt: prepareStartedAt)
                return true
            })
            DiagnosticsLogger.shared.playback("MDK", "prepare item=\(self.source.itemId) version=\(swift_mdk.version()) transport=\(transportMode) localHost=\(url.host == "127.0.0.1") sharedTransport=\(self.sharedTransportSession != nil ? "active" : "unavailable") headers=\(headers.keys.sorted().joined(separator: ",")) rate=\(String(format: "%.2f", self.playbackRate)) nativeQueue=isolated probation=true")
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
                DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\(self.inputTraceSession) source=\(self.inputTraceSource) event=status position=\(String(format: "%.3f", self.lastNativePosition)) raw=0x\(String(status.rawValue, radix: 16)) frameSerial=\(self.renderedFrameSerial)")
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
        let isPlaying = player.state == .Playing
        let bufferMs = player.buffered()
        recoverTrueHDStartupIfNeeded(player: player, info: info, position: position, rawBuffering: rawBuffering, bufferMs: bufferMs, generation: generation)
        DispatchQueue.main.async { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: generation) else { return }
            self.consumeStateSample(position: position, duration: duration, status: status, rawBuffering: rawBuffering, ended: ended, isPlaying: isPlaying, bufferMs: bufferMs)
        }
    }

    private func recoverTrueHDStartupIfNeeded(player: swift_mdk.Player, info: MediaInfo, position: Double, rawBuffering: Bool, bufferMs: Int64, generation: Int) {
        guard !trueHDStartupFallbackAttempted, let armedAt = trueHDStartupFallbackArmedAt else { return }
        if position > 0.25 {
            trueHDStartupFallbackArmedAt = nil
            return
        }
        guard CACurrentMediaTime() - armedAt >= trueHDStartupFallbackSeconds, shouldPlay, rawBuffering, bufferMs < 250 else { return }
        let health = nativeRenderHealth()
        guard health.generation == generation, health.serial > 0 else { return }
        guard let firstAudio = info.audio.first, (firstAudio.codec.codec ?? "").lowercased() == "truehd" else {
            trueHDStartupFallbackArmedAt = nil
            return
        }
        guard let fallbackIndex = info.audio.firstIndex(where: { ["ac3", "eac3"].contains(($0.codec.codec ?? "").lowercased()) }) else {
            trueHDStartupFallbackArmedAt = nil
            DiagnosticsLogger.shared.playback("MDKAudioStartupFallback", "generation=\(generation) source=truehd action=none reason=no-ac3-compatible-track")
            return
        }
        trueHDStartupFallbackAttempted = true
        trueHDStartupFallbackArmedAt = nil
        let fallback = info.audio[fallbackIndex]
        DiagnosticsLogger.shared.playback("MDKAudioStartupFallback", "generation=\(generation) elapsedMs=\(Int((CACurrentMediaTime() - armedAt) * 1_000)) position=\(String(format: "%.3f", position)) bufferMs=\(bufferMs) renderedSerial=\(health.serial) source=truehd fallbackIndex=\(fallbackIndex) fallbackStream=\(fallback.index) fallbackCodec=\((fallback.codec.codec ?? "unknown").lowercased()) action=switch-audio-track")
        player.activeAudioTracks = [fallbackIndex]
        if shouldPlay { player.state = .Playing }
    }

    private func consumeStateSample(position: Double, duration: Double, status: Int32, rawBuffering: Bool, ended: Bool, isPlaying: Bool, bufferMs: Int64) {
        let now = Date().timeIntervalSince1970
        lastNativePosition = position
        lastNativeDuration = duration
        lastNativeBuffering = rawBuffering
        lastNativeStatus = status
        lastNativeBufferMs = bufferMs
        healthCoordinator.noteNativeSample(generation: generation, position: position, bufferMs: bufferMs)
        let traceSecond = Int(max(0, position).rounded(.down))
        if traceSecond != inputTraceLastSecond {
            inputTraceLastSecond = traceSecond
            DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\(inputTraceSession) source=\(inputTraceSource) event=progress position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) raw=0x\(String(status, radix: 16)) playing=\(isPlaying) buffering=\(rawBuffering) bufferMs=\(bufferMs) frameSerial=\(renderedFrameSerial) renderValue=\(lastRenderedTimestamp.map { String(format: "%.6f", $0) } ?? "nil")")
        }

        let farFromEnd = duration > 0 && position + max(3, duration * 0.005) < duration
        var confirmedEnd = false
        if ended, farFromEnd {
            let seekActive = activeNativeSeek != nil || queuedLatestSeek != nil || pendingSeekResume != nil
            if seekActive || rawBuffering {
                endCandidateSince = nil
            } else if let candidateSince = endCandidateSince {
                let progressed = position > endCandidatePosition + 0.08 || renderedFrameSerial > endCandidateFrameSerial
                if progressed {
                    endCandidateSince = now
                    endCandidatePosition = position
                    endCandidateFrameSerial = renderedFrameSerial
                } else if now - candidateSince >= endConfirmationSeconds {
                    confirmedEnd = true
                    DiagnosticsLogger.shared.playback("MDKEndCandidate", "state=confirmed position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) elapsedMs=\(Int((now - candidateSince) * 1_000)) frameSerial=\(renderedFrameSerial)")
                    if !inputTraceDidLogConfirmedEnd { inputTraceDidLogConfirmedEnd = true; DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\(inputTraceSession) source=\(inputTraceSource) event=eof-confirmed position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) raw=0x\(String(status, radix: 16)) frameSerial=\(renderedFrameSerial) renderValue=\(lastRenderedTimestamp.map { String(format: "%.6f", $0) } ?? "nil")") }
                }
            } else {
                endCandidateSince = now
                endCandidatePosition = position
                endCandidateFrameSerial = renderedFrameSerial
                DiagnosticsLogger.shared.playback("MDKEndCandidate", "state=armed position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) rawStatus=0x\(String(status, radix: 16))")
                DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\(inputTraceSession) source=\(inputTraceSource) event=eof-armed position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) raw=0x\(String(status, radix: 16)) frameSerial=\(renderedFrameSerial)")
            }
        } else if ended {
            confirmedEnd = true
            endCandidateSince = nil
        } else {
            if endCandidateSince != nil {
                DiagnosticsLogger.shared.playback("MDKEndCandidate", "state=cancelled position=\(String(format: "%.3f", position)) reason=raw-end-cleared")
            }
            endCandidateSince = nil
        }
        lastNativeIsPlaying = isPlaying && !confirmedEnd
        lastNativeEnded = confirmedEnd

        if seekLowLatencyBufferActive, activeNativeSeek == nil, queuedLatestSeek == nil, pendingSeekResume == nil, bufferMs >= normalBufferMinMs, let player = currentPlayerReference() {
            seekLowLatencyBufferActive = false
            let currentGeneration = generation
            let queue = nativeControlQueue
            queue.async { [weak self, weak player] in
                guard let self, let player, self.isCurrentPlayer(player, generation: currentGeneration) else { return }
                player.setBufferRange(msMin: self.normalBufferMinMs, msMax: Int64(max(3_000, min(30_000, self.preferredForwardBuffer * 1_000))), drop: false)
                DiagnosticsLogger.shared.playback("MDKSeekBuffer", "phase=restore-normal minMs=\(self.normalBufferMinMs) bufferedMs=\(bufferMs)")
            }
        }

        if confirmedEnd, duration > 0, position + max(3, duration * 0.005) < duration, activeNativeSeek != nil || queuedLatestSeek != nil || pendingSeekResume != nil {
            let recoveryTarget = latestDesiredTarget(fallback: position)
            DiagnosticsLogger.shared.playback("MDKSeekWedge", "reason=premature-eof-during-seek position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) latestTarget=\(String(format: "%.3f", recoveryTarget)) action=submit-fatal-health")
            submitHealthCandidate(.fatal(generation: generation, reason: "premature-eof-during-seek"), fallbackPosition: recoveryTarget, message: "MDK premature EOF during seek")
            return
        }

        var suppressSeekBuffering = false
        if rawBuffering, let graceStartedAt = seekBufferingGraceStartedAt, now - graceStartedAt < seekBufferingUIGraceSeconds {
            suppressSeekBuffering = true
            if didLogSeekBufferingGraceID != seekBufferingGraceID {
                didLogSeekBufferingGraceID = seekBufferingGraceID
                DiagnosticsLogger.shared.playback("MDKBuffering", "id=\(seekBufferingGraceID ?? -1) target=\(String(format: "%.3f", seekBufferingGraceTarget ?? position)) raw=true ui=false reason=seek-settle-window graceMs=\(Int(seekBufferingUIGraceSeconds * 1_000))")
            }
        }
        let buffering = rawBuffering && !suppressSeekBuffering
        let forwardBuffered = seconds(bufferMs)
        let bufferedEnd = duration > 0 ? min(duration, position + forwardBuffered) : position + forwardBuffered
        onSnapshot?(PlayerSnapshot(position: position, renderedPosition: lastRenderedTimestamp, duration: duration, bufferedRanges: bufferedEnd > position ? [position...bufferedEnd] : [], isPlaying: isPlaying && !confirmedEnd, isBuffering: buffering, waitingReason: buffering ? "MDK 等待媒体数据" : nil, errorMessage: hasStatus(status, bit: 31) ? "MDK media status invalid" : nil, didReachEnd: confirmedEnd))

        if var pending = pendingSeekResume, !pending.didLogClockAdvance, let callbackPosition = pending.callbackPosition, abs(position - callbackPosition) > 0.08 {
            let resumeMs = (now - pending.requestedAt) * 1_000
            let afterCallbackMs = pending.callbackAt.map { (now - $0) * 1_000 }
            pending.didLogClockAdvance = true
            pendingSeekResume = pending
            DiagnosticsLogger.shared.playback("MDKSeekHealth", "id=\(pending.id) target=\(String(format: "%.3f", pending.target)) callbackPosition=\(String(format: "%.3f", callbackPosition)) firstClockAdvance=\(String(format: "%.3f", position)) resumeMs=\(String(format: "%.1f", resumeMs)) afterCallbackMs=\(afterCallbackMs.map { String(format: "%.1f", $0) } ?? "pending") playing=\(isPlaying) rawBuffering=\(rawBuffering) uiBuffering=\(buffering) bufferMs=\(bufferMs) nativeOutstanding=\(nativeSeekOutstandingCount) awaitingRenderedFrame=true unifiedTransport=\(sharedTransportSession != nil)")
        }
    }

    private func scheduleActiveNativeSeekFastWatchdog(player: swift_mdk.Player, intent: NativeSeekIntent) {
        guard intent.nativeStartedAt != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + activeNativeSeekFastWatchdogSeconds) { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: intent.playerGeneration), self.activeNativeSeek?.id == intent.id else { return }
            self.submitHealthCandidate(.nativeSeekTimeout(generation: intent.playerGeneration, seekID: intent.id, hard: false), fallbackPosition: self.latestDesiredTarget(fallback: intent.target), message: "MDK native seek soft probe")
        }
    }

    private func scheduleActiveNativeSeekWatchdog(player: swift_mdk.Player, intent: NativeSeekIntent, hard: Bool) {
        guard intent.nativeStartedAt != nil else { return }
        let delay = hard ? activeNativeSeekHardWatchdogSeconds - activeNativeSeekWatchdogSeconds : activeNativeSeekWatchdogSeconds
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.1, delay)) { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: intent.playerGeneration), self.activeNativeSeek?.id == intent.id else { return }
            self.submitHealthCandidate(
                .nativeSeekTimeout(generation: intent.playerGeneration, seekID: intent.id, hard: hard),
                fallbackPosition: self.latestDesiredTarget(fallback: intent.target),
                message: "MDK native seek made no progress",
                recheck: { [weak self, weak player] in
                    guard let self, let player else { return }
                    if hard {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self, weak player] in
                            guard let self, let player, self.isCurrentPlayer(player, generation: intent.playerGeneration), self.activeNativeSeek?.id == intent.id else { return }
                            self.submitHealthCandidate(.nativeSeekTimeout(generation: intent.playerGeneration, seekID: intent.id, hard: true), fallbackPosition: self.latestDesiredTarget(fallback: intent.target), message: "MDK native seek made no progress", recheck: nil)
                        }
                    } else {
                        self.scheduleActiveNativeSeekWatchdog(player: player, intent: intent, hard: true)
                    }
                }
            )
        }
    }

    private func scheduleSeekFrameWatchdog(player: swift_mdk.Player, seekID: Int, playerGeneration: Int, hard: Bool) {
        let delay = hard ? seekFrameHardWatchdogSeconds - seekFrameWatchdogSeconds : seekFrameWatchdogSeconds
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.1, delay)) { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: playerGeneration), let pending = self.pendingSeekResume, pending.id == seekID, pending.callbackAt != nil else { return }
            self.submitHealthCandidate(
                .seekFrameTimeout(generation: playerGeneration, seekID: seekID, hard: hard),
                fallbackPosition: self.latestDesiredTarget(fallback: pending.target),
                message: "MDK seek callback had no matching rendered frame",
                recheck: { [weak self, weak player] in
                    guard let self, let player else { return }
                    if hard {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self, weak player] in
                            guard let self, let player, self.isCurrentPlayer(player, generation: playerGeneration), let pending = self.pendingSeekResume, pending.id == seekID else { return }
                            self.submitHealthCandidate(.seekFrameTimeout(generation: playerGeneration, seekID: seekID, hard: true), fallbackPosition: self.latestDesiredTarget(fallback: pending.target), message: "MDK seek callback had no matching rendered frame", recheck: nil)
                        }
                    } else {
                        self.scheduleSeekFrameWatchdog(player: player, seekID: seekID, playerGeneration: playerGeneration, hard: true)
                    }
                }
            )
        }
    }

    private func latestDesiredTarget(fallback: Double) -> Double {
        max(0, queuedLatestSeek?.target ?? pendingSeekResume?.target ?? activeNativeSeek?.target ?? fallback)
    }

    private func recoverWedgedSeek(reason: String, fallbackTarget: Double, playerGeneration: Int) {
        guard playerGeneration == generation, player != nil else { return }
        let recoveryTarget = latestDesiredTarget(fallback: fallbackTarget)
        DiagnosticsLogger.shared.playback("MDKSeekWedge", "reason=\(reason) generation=\(playerGeneration) active=\(activeNativeSeek?.id ?? -1) queued=\(queuedLatestSeek?.id ?? -1) latestTarget=\(String(format: "%.3f", recoveryTarget)) action=submit-fatal-health")
        submitHealthCandidate(.fatal(generation: playerGeneration, reason: "seek-wedge-\(reason)"), fallbackPosition: recoveryTarget, message: "MDK session unsafe seek recovery")
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
        healthCoordinator.noteRenderedFrame(generation: generation, serial: renderedFrameSerial, position: renderResult)
        if renderedFrameSerial == 1 || renderedFrameSerial % 30 == 0 { DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\(inputTraceSession) source=\(inputTraceSource) event=render frameSerial=\(renderedFrameSerial) position=\(String(format: "%.3f", lastNativePosition)) renderValue=\(String(format: "%.6f", renderResult))") }
        guard let pending = pendingSeekResume, let callbackAt = pending.callbackAt, let callbackFrameSerial = pending.callbackFrameSerial, renderedFrameSerial > callbackFrameSerial else { return }
        let expectedLanding = pending.callbackPosition ?? pending.target
        guard abs(renderResult - expectedLanding) <= 1.0 else {
            DiagnosticsLogger.shared.playback("MDKSeekFrame", "id=\(pending.id) target=\(String(format: "%.3f", pending.target)) callbackLanding=\(String(format: "%.3f", expectedLanding)) renderTimestamp=\(String(format: "%.6f", renderResult)) action=discard-superseded-frame")
            return
        }
        let now = Date().timeIntervalSince1970
        let playerPosition: Double? = currentPlayerReference() == nil ? nil : lastNativePosition
        let callbackLatency = (callbackAt - pending.requestedAt) * 1_000
        let totalLatency = (now - pending.requestedAt) * 1_000
        let afterCallback = (now - callbackAt) * 1_000
        DiagnosticsLogger.shared.playback("MDKSeekFrame", "id=\(pending.id) target=\(String(format: "%.3f", pending.target)) renderTimestamp=\(String(format: "%.6f", renderResult)) renderPosition=\(playerPosition.map { String(format: "%.3f", $0) } ?? "unknown") totalMs=\(String(format: "%.1f", totalLatency)) afterCallbackMs=\(String(format: "%.1f", afterCallback)) frameSerial=\(renderedFrameSerial) action=visual-seek-complete")
        DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\(inputTraceSession) source=\(inputTraceSource) event=seek-first-frame seekID=\(pending.id) target=\(String(format: "%.3f", pending.target)) position=\(playerPosition.map { String(format: "%.3f", $0) } ?? "unknown") renderValue=\(String(format: "%.6f", renderResult)) totalMs=\(String(format: "%.1f", totalLatency)) afterCallbackMs=\(String(format: "%.1f", afterCallback)) frameSerial=\(renderedFrameSerial) raw=0x\(String(lastNativeStatus, radix: 16))")
        onSeekCompleted?(SeekResult(requestedAt: pending.requestedAt, target: pending.target, actualPosition: renderResult, bufferHit: callbackLatency < 150, completionLatencyMs: totalLatency, measurement: "MDK first rendered frame after latest seek callback; actual=render-timestamp"))
        healthCoordinator.completeSeek(generation: generation, seekID: pending.id)
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
        if inputTraceSession != "unassigned" { DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\(inputTraceSession) source=\(inputTraceSource) event=stop position=\(String(format: "%.3f", lastNativePosition)) raw=0x\(String(lastNativeStatus, radix: 16)) frameSerial=\(renderedFrameSerial) renderValue=\(lastRenderedTimestamp.map { String(format: "%.6f", $0) } ?? "nil")") }
        preparingGeneration = nil
        preparedGeneration = -1
        endCandidateSince = nil
        stateTimer?.cancel()
        stateTimer = nil
        renderWatchdogTimer?.cancel()
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
        seekLowLatencyBufferActive = false
        let oldRenderer = renderer
        oldRenderer.detach()
        guard let oldPlayer = takePlayer() else { nativeQuarantineActive = false; return }
        if nativeQuarantineActive {
            nativeQuarantineActive = false
            MDKNativeQuarantineStore.shared.retain(oldPlayer, oldRenderer)
            DiagnosticsLogger.shared.playback("MDKTeardown", "phase=ui-detached generation=\(generation) activeSeek=\(activeSeekID ?? -1) action=quarantine-retain-skip-native-stop mainResponsive=true")
            return
        }
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