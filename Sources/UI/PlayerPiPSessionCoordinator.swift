import AVFoundation
import AVKit
import CoreMedia
import UIKit

@MainActor
final class PlayerPiPSessionCoordinator: NSObject, @preconcurrency AVPictureInPictureControllerDelegate, @preconcurrency AVPictureInPictureSampleBufferPlaybackDelegate {
    enum State: String { case idle, preparingSource, startingSystem, active, restoring, stopping }

    var onPossibleChanged: ((Bool) -> Void)?
    var onActiveChanged: ((Bool) -> Void)?

    private(set) var state: State = .idle
    private weak var playbackController: PlayerController?
    private weak var inlineRenderer: PlayerPiPInlineRendererControlling?
    private var inlineRendererSuspended = false
    private var activeSession: UnifiedMediaTransportSession?
    private var controller: AVPictureInPictureController?
    private var possibleObservation: NSKeyValueObservation?
    private var displayLayer: AVSampleBufferDisplayLayer?
    private var sourceHostView: PlayerPiPSourceHostView?
    private var pipeline: PlayerPiPSamplePipeline?
    private var controlTimebase: CMTimebase?
    private var startTimeout: DispatchWorkItem?
    private var startPoll: DispatchWorkItem?
    private var firstVisibleSampleEnqueued = false
    private var activeGeneration: UInt64 = 0
    private var pendingSkipGeneration: UInt64?
    private var pendingSkipCompletion: (@Sendable () -> Void)?
    private var foregroundObserver: NSObjectProtocol?
    private var pendingForegroundRestore: (() -> Void)?
    private let homeCoordinator = PlayerPiPHomeCoordinator()

    override init() {
        super.init()
        foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleForegroundActive() }
        }
    }

    deinit { if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) } }

    func toggle(using playbackController: PlayerController) {
        if controller?.isPictureInPictureActive == true { state = .stopping; controller?.stopPictureInPicture(); return }
        guard state == .idle else { DiagnosticsLogger.shared.playback("PiPSession", "toggle ignored state=\(state.rawValue)"); return }
        prepare(using: playbackController)
    }

    func stopAndDetach() {
        pendingSkipCompletion?(); pendingSkipCompletion = nil; pendingSkipGeneration = nil
        if controller?.isPictureInPictureActive == true { state = .stopping; controller?.stopPictureInPicture(); return }
        restoreInlineRendererWhenForeground(reason: "detach") { [weak self] in self?.reset(reason: "detach") }
    }

    private func prepare(using playbackController: PlayerController) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { onPossibleChanged?(false); return }
        guard let session = PlaybackTransportSessionRegistry.shared.session(itemId: playbackController.source.itemId) else {
            DiagnosticsLogger.shared.playback("PiPSession", "prepare failed reason=no-active-unified-session item=\(playbackController.source.itemId)")
            return
        }
        guard let sourceView = visiblePlaybackSurface() else {
            DiagnosticsLogger.shared.playback("PiPSession", "prepare failed reason=no-visible-playback-surface")
            return
        }

        reset(reason: "prepare-new")
        state = .preparingSource
        self.playbackController = playbackController
        inlineRenderer = sourceView as? PlayerPiPInlineRendererControlling
        activeSession = session

        let host = PlayerPiPSourceHostView(frame: sourceView.frame)
        host.autoresizingMask = sourceView.autoresizingMask
        if let parent = sourceView.superview { parent.insertSubview(host, belowSubview: sourceView) } else { sourceView.addSubview(host) }
        sourceHostView = host

        let layer = host.displayLayer
        layer.videoGravity = .resizeAspect
        var timebase: CMTimebase?
        let status = CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        guard status == noErr, let timebase else { DiagnosticsLogger.shared.playback("PiPSession", "prepare failed reason=timebase status=\(status)"); reset(reason: "timebase-failed"); return }
        let position = max(0, playbackController.snapshot.position)
        CMTimebaseSetTime(timebase, time: CMTime(seconds: position, preferredTimescale: 60000))
        CMTimebaseSetRate(timebase, rate: playbackController.playbackControlIsPlaying ? 1 : 0)
        layer.controlTimebase = timebase
        controlTimebase = timebase
        displayLayer = layer

        let contentSource = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: layer, playbackDelegate: self)
        let systemController = AVPictureInPictureController(contentSource: contentSource)
        systemController.delegate = self
        systemController.requiresLinearPlayback = false
        controller = systemController
        observePossible(systemController)

        firstVisibleSampleEnqueued = false
        let pipeline = PlayerPiPSamplePipeline(session: session, startPosition: position)
        self.pipeline = pipeline
        pipeline.onReady = { info in DispatchQueue.main.async { DiagnosticsLogger.shared.playback("PiPSession", "pipeline ready \(info)") } }
        pipeline.onFailure = { [weak self] reason in DispatchQueue.main.async { self?.handlePipelineFailure(reason) } }
        pipeline.onSample = { [weak self] envelope in DispatchQueue.main.async { self?.enqueue(envelope) } }
        pipeline.setPaused(!playbackController.playbackControlIsPlaying)
        activeGeneration = pipeline.start()
        scheduleStartTimeout()
        DiagnosticsLogger.shared.playback("PiPSession", "prepared engine=\(playbackController.engineKind.title) position=\(String(format: "%.3f", position)) generation=\(activeGeneration) possible=\(systemController.isPictureInPicturePossible) renderer=\(inlineRenderer == nil ? "none" : "surface")")
    }

    private func enqueue(_ envelope: PlayerPiPSamplePipeline.SampleEnvelope) {
        guard envelope.generation == activeGeneration else { return }
        guard let displayLayer, displayLayer.status != .failed else {
            if let error = displayLayer?.error { DiagnosticsLogger.shared.playback("PiPSession", "display-layer failed error=\(error.localizedDescription)") }
            if state != .active && state != .restoring { failAndRestore(reason: "display-layer-failed") }
            return
        }
        displayLayer.enqueue(envelope.buffer)
        guard envelope.displayable else { return }

        if !firstVisibleSampleEnqueued {
            firstVisibleSampleEnqueued = true
            DiagnosticsLogger.shared.playback("PiPSession", "first-visible-sample pts=\(String(format: "%.3f", envelope.pts)) generation=\(envelope.generation) key=\(envelope.keyframe)")
            pollStart(attempt: 0)
        }
        if pendingSkipGeneration == envelope.generation {
            let completion = pendingSkipCompletion
            pendingSkipCompletion = nil
            pendingSkipGeneration = nil
            if let timebase = controlTimebase {
                CMTimebaseSetTime(timebase, time: CMTime(seconds: envelope.pts, preferredTimescale: 60000))
                CMTimebaseSetRate(timebase, rate: playbackController?.playbackControlIsPlaying == true ? 1 : 0)
            }
            controller?.invalidatePlaybackState()
            DiagnosticsLogger.shared.playback("PiPSession", "seek-visible targetPts=\(String(format: "%.3f", envelope.pts)) generation=\(envelope.generation) rateRestored=\(playbackController?.playbackControlIsPlaying == true)")
            completion?()
        }
    }

    private func observePossible(_ systemController: AVPictureInPictureController) {
        possibleObservation = systemController.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] controller, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.onPossibleChanged?(controller.isPictureInPicturePossible || AVPictureInPictureController.isPictureInPictureSupported())
                DiagnosticsLogger.shared.playback("PiPSession", "possible=\(controller.isPictureInPicturePossible) state=\(self.state.rawValue) firstVisible=\(self.firstVisibleSampleEnqueued)")
                self.startIfReady()
            }
        }
    }

    private func pollStart(attempt: Int) {
        startPoll?.cancel()
        guard state == .preparingSource else { return }
        startIfReady()
        guard state == .preparingSource, attempt < 80 else { return }
        let work = DispatchWorkItem { [weak self] in self?.pollStart(attempt: attempt + 1) }
        startPoll = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    private func startIfReady() {
        guard state == .preparingSource, firstVisibleSampleEnqueued, let controller, let displayLayer else { return }
        guard controller.isPictureInPicturePossible, displayLayer.status != .failed else { return }
        startPoll?.cancel(); startPoll = nil
        state = .startingSystem
        DiagnosticsLogger.shared.playback("PiPSession", "system-start begin homePolicy=willStart")
        controller.startPictureInPicture()
    }

    private func scheduleStartTimeout() {
        startTimeout?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.state == .preparingSource || self.state == .startingSystem else { return }
            DiagnosticsLogger.shared.playback("PiPSession", "start timeout state=\(self.state.rawValue) possible=\(self.controller?.isPictureInPicturePossible ?? false) firstVisible=\(self.firstVisibleSampleEnqueued)")
            self.failAndRestore(reason: "start-timeout")
        }
        startTimeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: work)
    }

    private func requestHomeAfterRendererSuspend() {
        let requestHome = { [weak self] in
            guard let self else { return }
            let requested = self.homeCoordinator.requestHome()
            DiagnosticsLogger.shared.playback("PiPSession", "home-request issued=\(requested) state=\(self.state.rawValue)")
        }
        guard !inlineRendererSuspended, let inlineRenderer else { requestHome(); return }
        inlineRenderer.suspendInlineRendererForPictureInPicture { [weak self] success in
            guard let self else { return }
            self.inlineRendererSuspended = success
            DiagnosticsLogger.shared.playback("PiPSession", "inline-renderer suspend success=\(success) phase=system-will-start")
            guard success else { return }
            requestHome()
        }
    }

    private func handlePipelineFailure(_ reason: String) {
        DiagnosticsLogger.shared.playback("PiPSession", "pipeline failed reason=\(reason) state=\(state.rawValue)")
        if state == .active {
            state = .stopping
            controller?.stopPictureInPicture()
        } else if state != .restoring && state != .stopping { failAndRestore(reason: "pipeline-failed") }
    }

    private func failAndRestore(reason: String) {
        pendingSkipCompletion?(); pendingSkipCompletion = nil; pendingSkipGeneration = nil
        restoreInlineRendererWhenForeground(reason: reason) { [weak self] in self?.reset(reason: reason) }
    }

    private func restoreInlineRendererWhenForeground(reason: String, completion: @escaping () -> Void) {
        guard inlineRendererSuspended else { completion(); return }
        guard UIApplication.shared.applicationState != .background else {
            pendingForegroundRestore = { [weak self] in self?.restoreInlineRendererWhenForeground(reason: reason, completion: completion) }
            DiagnosticsLogger.shared.playback("PiPSession", "renderer restore deferred reason=\(reason) appState=background")
            return
        }
        guard let inlineRenderer else { inlineRendererSuspended = false; completion(); return }
        inlineRenderer.resumeInlineRendererAfterPictureInPicture { [weak self] success in
            guard let self else { completion(); return }
            self.inlineRendererSuspended = false
            DiagnosticsLogger.shared.playback("PiPSession", "inline-renderer restore success=\(success) reason=\(reason)")
            completion()
        }
    }

    private func handleForegroundActive() {
        let pending = pendingForegroundRestore
        pendingForegroundRestore = nil
        pending?()
    }

    private func reset(reason: String) {
        startTimeout?.cancel(); startTimeout = nil
        startPoll?.cancel(); startPoll = nil
        pendingSkipCompletion?(); pendingSkipCompletion = nil; pendingSkipGeneration = nil
        pendingForegroundRestore = nil
        possibleObservation = nil
        pipeline?.stop(); pipeline = nil
        displayLayer?.flushAndRemoveImage(); displayLayer?.controlTimebase = nil
        displayLayer = nil; controlTimebase = nil
        sourceHostView?.removeFromSuperview(); sourceHostView = nil
        controller?.delegate = nil; controller = nil
        activeSession = nil; playbackController = nil; inlineRenderer = nil
        firstVisibleSampleEnqueued = false; activeGeneration = 0
        inlineRendererSuspended = false
        state = .idle
        onActiveChanged?(false)
        onPossibleChanged?(AVPictureInPictureController.isPictureInPictureSupported())
        DiagnosticsLogger.shared.playback("PiPSession", "reset reason=\(reason)")
    }

    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DiagnosticsLogger.shared.playback("PiPSession", "system-will-start appState=\(UIApplication.shared.applicationState.rawValue)")
        requestHomeAfterRendererSuspend()
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        startTimeout?.cancel(); startTimeout = nil
        state = .active
        onActiveChanged?(true)
        DiagnosticsLogger.shared.playback("PiPSession", "system-started engine=\(playbackController?.engineKind.title ?? "unknown") appState=\(UIApplication.shared.applicationState.rawValue)")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DiagnosticsLogger.shared.playback("PiPSession", "system-stopped position=\(String(format: "%.3f", playbackController?.snapshot.position ?? 0)) appState=\(UIApplication.shared.applicationState.rawValue) previousState=\(state.rawValue)")
        state = .stopping
        pipeline?.stop()
        restoreInlineRendererWhenForeground(reason: "system-stopped") { [weak self] in self?.reset(reason: "system-stopped") }
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        state = .restoring
        DiagnosticsLogger.shared.playback("PiPSession", "restore-ui requested appState=\(UIApplication.shared.applicationState.rawValue) policy=system-first")
        completionHandler(true)
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        DiagnosticsLogger.shared.playback("PiPSession", "system-start failed error=\(error.localizedDescription)")
        failAndRestore(reason: "system-start-failed")
    }

    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        guard let playbackController else { return .invalid }
        return CMTimeRange(start: .zero, duration: CMTime(seconds: max(0.001, playbackController.effectiveDuration), preferredTimescale: 60000))
    }

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool { !(playbackController?.playbackControlIsPlaying ?? false) }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        guard let playbackController else { return }
        if playbackController.playbackControlIsPlaying != playing { playbackController.togglePlayPause() }
        pipeline?.setPaused(!playing)
        if let timebase = controlTimebase {
            CMTimebaseSetTime(timebase, time: CMTime(seconds: playbackController.snapshot.position, preferredTimescale: 60000))
            CMTimebaseSetRate(timebase, rate: playing ? 1 : 0)
        }
        pictureInPictureController.invalidatePlaybackState()
        DiagnosticsLogger.shared.playback("PiPSession", "set-playing=\(playing) position=\(String(format: "%.3f", playbackController.snapshot.position))")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        DiagnosticsLogger.shared.playback("PiPSession", "render-size=\(newRenderSize.width)x\(newRenderSize.height)")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping @Sendable () -> Void) {
        guard let playbackController, let pipeline, let displayLayer, let timebase = controlTimebase else { completionHandler(); return }
        let delta = CMTimeGetSeconds(skipInterval)
        guard delta.isFinite else { completionHandler(); return }
        let target = min(max(0, playbackController.snapshot.position + delta), max(playbackController.effectiveDuration, 0))

        pendingSkipCompletion?()
        displayLayer.flushAndRemoveImage()
        CMTimebaseSetTime(timebase, time: CMTime(seconds: target, preferredTimescale: 60000))
        CMTimebaseSetRate(timebase, rate: 0)
        playbackController.seek(by: delta)
        activeGeneration = pipeline.seek(to: target)
        pendingSkipGeneration = activeGeneration
        pendingSkipCompletion = completionHandler
        pictureInPictureController.invalidatePlaybackState()
        DiagnosticsLogger.shared.playback("PiPSession", "seek requested delta=\(String(format: "%.3f", delta)) target=\(String(format: "%.3f", target)) generation=\(activeGeneration) pipeline=persistent")
    }

    func pictureInPictureControllerShouldProhibitBackgroundAudioPlayback(_ pictureInPictureController: AVPictureInPictureController) -> Bool { false }

    private func visiblePlaybackSurface() -> UIView? {
        guard let window = activeKeyWindow() else { return nil }
        if let surface: MPVSurfaceUIView = findVisibleSubview(of: MPVSurfaceUIView.self, in: window) { return surface }
        if let surface: KSAVIOSurfaceUIView = findVisibleSubview(of: KSAVIOSurfaceUIView.self, in: window) { return surface }
        if let surface: PlayerSurfaceUIView = findVisibleSubview(of: PlayerSurfaceUIView.self, in: window) { return surface }
        return nil
    }

    private func activeKeyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first(where: { $0.activationState == .foregroundInactive })
        return scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first(where: { !$0.isHidden })
    }

    private func findVisibleSubview<T: UIView>(of type: T.Type, in root: UIView) -> T? {
        if let match = root as? T, match.window != nil, !match.isHidden, match.alpha > 0.01, match.bounds.width > 1, match.bounds.height > 1 { return match }
        for child in root.subviews { if let match: T = findVisibleSubview(of: type, in: child) { return match } }
        return nil
    }
}

private final class PlayerPiPSourceHostView: UIView {
    let displayLayer = AVSampleBufferDisplayLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isUserInteractionEnabled = false
        clipsToBounds = true
        layer.addSublayer(displayLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin(); CATransaction.setDisableActions(true); displayLayer.frame = bounds; displayLayer.contentsScale = window?.screen.nativeScale ?? UIScreen.main.nativeScale; CATransaction.commit()
    }
}
