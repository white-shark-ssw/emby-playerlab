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
    private weak var seekLandingProvider: PlayerPiPSeekLandingProviding?
    private var inlineRendererSuspended = false
    private var rendererSuspending = false
    private var activeSession: UnifiedMediaTransportSession?
    private var controller: AVPictureInPictureController?
    private var possibleObservation: NSKeyValueObservation?
    private var displayLayer: AVSampleBufferDisplayLayer?
    private var sourceHostView: PlayerPiPSourceHostView?
    private var pipeline: PlayerPiPSamplePipeline?
    private var controlTimebase: CMTimebase?
    private var startTimeout: DispatchWorkItem?
    private var startPoll: DispatchWorkItem?
    private var seekFallbackWorkItem: DispatchWorkItem?
    private var firstVisibleSampleEnqueued = false
    private var sourceSurfaceRevealed = false
    private var activeGeneration: UInt64 = 0
    private var pendingSkipGeneration: UInt64?
    private var pendingSkipCompletion: (@Sendable () -> Void)?
    private var pendingSeekStartedPosition: Double?
    private var logicalPiPPosition: Double = 0
    private var pipWantsPlayback = true
    private var foregroundObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?
    private var pendingForegroundRestore: (() -> Void)?
    private var homeRequested = false
    private var restoreRequested = false
    private var systemPiPStopped = false
    private var rendererRestoreInProgress = false
    private var rendererRestoreReady = false
    private var rendererRestoreActualPosition: Double?
    private var rendererRestoreAttempt = 0
    private var pendingSeekAuthoritativePosition: Double?
    private var pendingSeekLandingHostTime: CFTimeInterval?
    private let homeCoordinator = PlayerPiPHomeCoordinator()

    override init() {
        super.init()
        foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleForegroundActive() }
        }
        backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleBackgroundEntered() }
        }
    }

    deinit {
        if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
        if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
    }

    func toggle(using playbackController: PlayerController) {
        if controller?.isPictureInPictureActive == true { state = .stopping; controller?.stopPictureInPicture(); return }
        guard state == .idle else { DiagnosticsLogger.shared.playback("PiPSession", "toggle ignored state=\(state.rawValue)"); return }
        prepare(using: playbackController)
    }

    func stopAndDetach() {
        pendingSkipCompletion?(); pendingSkipCompletion = nil; pendingSkipGeneration = nil
        seekFallbackWorkItem?.cancel(); seekFallbackWorkItem = nil
        if controller?.isPictureInPictureActive == true { state = .stopping; controller?.stopPictureInPicture(); return }
        restoreInlineRendererWhenForeground(reason: "detach", targetPosition: logicalPiPPosition) { [weak self] _, _ in self?.reset(reason: "detach") }
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
        inlineRenderer = (playbackController.engine as? PlayerPiPInlineRendererControlling) ?? (sourceView as? PlayerPiPInlineRendererControlling)
        if let provider = playbackController.engine as? PlayerPiPSeekLandingProviding {
            seekLandingProvider = provider
            provider.pictureInPictureSeekLandingHandler = { [weak self] result in DispatchQueue.main.async { self?.handleEngineSeekLanding(result) } }
        }
        activeSession = session

        let host = PlayerPiPSourceHostView(frame: sourceView.frame)
        host.autoresizingMask = sourceView.autoresizingMask
        host.alpha = 0
        if let parent = sourceView.superview { parent.insertSubview(host, aboveSubview: sourceView) } else { sourceView.addSubview(host) }
        sourceHostView = host

        let layer = host.displayLayer
        layer.videoGravity = .resizeAspect
        // iOS: preventsAutomaticBackgroundingDuringVideoPlayback = false is unavailable; rely on AVKit lifecycle.
        var timebase: CMTimebase?
        let status = CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        guard status == noErr, let timebase else {
            DiagnosticsLogger.shared.playback("PiPSession", "prepare failed reason=timebase status=\(status)")
            reset(reason: "timebase-failed")
            return
        }

        let position = max(0, playbackController.snapshot.position)
        logicalPiPPosition = position
        pipWantsPlayback = playbackController.playbackControlIsPlaying
        CMTimebaseSetTime(timebase, time: CMTime(seconds: position, preferredTimescale: 60000))
        CMTimebaseSetRate(timebase, rate: pipWantsPlayback ? 1 : 0)
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
        sourceSurfaceRevealed = false
        let pipeline = PlayerPiPSamplePipeline(session: session, startPosition: position)
        self.pipeline = pipeline
        pipeline.onReady = { info in DispatchQueue.main.async { DiagnosticsLogger.shared.playback("PiPSession", "pipeline ready \(info)") } }
        pipeline.onFailure = { [weak self] reason in DispatchQueue.main.async { self?.handlePipelineFailure(reason) } }
        pipeline.onSample = { [weak self] envelope in DispatchQueue.main.async { self?.enqueue(envelope) } }
        pipeline.setPaused(!pipWantsPlayback)
        activeGeneration = pipeline.start()
        scheduleStartTimeout()
        DiagnosticsLogger.shared.playback("PiPSession", "prepared engine=\(playbackController.engineKind.title) position=\(String(format: "%.3f", position)) generation=\(activeGeneration) possible=\(systemController.isPictureInPicturePossible) sourceSurface=visible-inline-handoff renderer=\(inlineRenderer == nil ? "none" : "engine-or-surface")")
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
        logicalPiPPosition = envelope.pts

        if !firstVisibleSampleEnqueued {
            firstVisibleSampleEnqueued = true
            if let timebase = controlTimebase { CMTimebaseSetTime(timebase, time: CMTime(seconds: envelope.pts, preferredTimescale: 60000)) }
            revealSourceSurfaceIfNeeded()
            DiagnosticsLogger.shared.playback("PiPSession", "first-visible-sample pts=\(String(format: "%.3f", envelope.pts)) generation=\(envelope.generation) key=\(envelope.keyframe) sourceSurface=revealed")
            pollStart(attempt: 0)
        }

        if pendingSkipGeneration == envelope.generation {
            let completion = pendingSkipCompletion
            pendingSkipCompletion = nil
            pendingSkipGeneration = nil
            pendingSeekStartedPosition = nil
            if let timebase = controlTimebase {
                let elapsed = pendingSeekLandingHostTime.map { pipWantsPlayback ? max(0, CACurrentMediaTime() - $0) : 0 } ?? 0
                let alignedClock = pendingSeekAuthoritativePosition.map { $0 + elapsed } ?? envelope.pts
                CMTimebaseSetTime(timebase, time: CMTime(seconds: alignedClock, preferredTimescale: 60000))
                CMTimebaseSetRate(timebase, rate: pipWantsPlayback ? 1 : 0)
                logicalPiPPosition = alignedClock
                DiagnosticsLogger.shared.playback("PiPSession", "seek clock-rebase samplePts=\(String(format: "%.3f", envelope.pts)) authoritative=\(pendingSeekAuthoritativePosition.map { String(format: "%.3f", $0) } ?? "unknown") elapsed=\(String(format: "%.3f", elapsed)) clock=\(String(format: "%.3f", alignedClock))")
            }
            pendingSeekAuthoritativePosition = nil
            pendingSeekLandingHostTime = nil
            pipeline?.setPaused(!pipWantsPlayback)
            controller?.invalidatePlaybackState()
            DiagnosticsLogger.shared.playback("PiPSession", "seek-visible authoritativePts=\(String(format: "%.3f", envelope.pts)) generation=\(envelope.generation) requestedPlaying=\(pipWantsPlayback)")
            completion?()
        }
    }

    private func revealSourceSurfaceIfNeeded() {
        guard !sourceSurfaceRevealed, let host = sourceHostView else { return }
        sourceSurfaceRevealed = true
        UIView.performWithoutAnimation { host.alpha = 1; host.layoutIfNeeded() }
    }

    private func observePossible(_ systemController: AVPictureInPictureController) {
        possibleObservation = systemController.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] controller, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.onPossibleChanged?(controller.isPictureInPicturePossible || AVPictureInPictureController.isPictureInPictureSupported())
                DiagnosticsLogger.shared.playback("PiPSession", "possible=\(controller.isPictureInPicturePossible) state=\(self.state.rawValue) firstVisible=\(self.firstVisibleSampleEnqueued) sourceSurface=\(self.sourceSurfaceRevealed)")
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
        guard state == .preparingSource, firstVisibleSampleEnqueued, sourceSurfaceRevealed, let controller, let displayLayer else { return }
        guard controller.isPictureInPicturePossible, displayLayer.status != .failed else { return }
        startPoll?.cancel(); startPoll = nil
        state = .startingSystem
        DiagnosticsLogger.shared.playback("PiPSession", "system-start begin sourceSurface=visible-native-transition homePolicy=didStart-immediate rendererSuspendPolicy=didEnterBackground")
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

    private func requestHomeAfterSystemStart() {
        guard !homeRequested else { return }
        homeRequested = true
        let requested = homeCoordinator.requestHome()
        DiagnosticsLogger.shared.playback("PiPSession", "home-request issued=\(requested) state=\(state.rawValue) policy=didStart-immediate rendererStillInline=true")
    }

    private func handleBackgroundEntered() {
        guard controller?.isPictureInPictureActive == true, state == .active || state == .restoring else { return }
        guard !inlineRendererSuspended, !rendererSuspending, let inlineRenderer else { return }
        rendererSuspending = true
        DiagnosticsLogger.shared.playback("PiPSession", "inline-renderer suspend begin phase=didEnterBackground sourceOwnedByAVKit=\(displayLayer?.superlayer !== sourceHostView?.layer)")
        inlineRenderer.suspendInlineRendererForPictureInPicture { [weak self] success in
            guard let self else { return }
            self.rendererSuspending = false
            self.inlineRendererSuspended = success
            DiagnosticsLogger.shared.playback("PiPSession", "inline-renderer suspend success=\(success) phase=didEnterBackground")
            if UIApplication.shared.applicationState == .active { self.handleForegroundActive() }
        }
    }

    private func handlePipelineFailure(_ reason: String) {
        DiagnosticsLogger.shared.playback("PiPSession", "pipeline failed reason=\(reason) state=\(state.rawValue)")
        if state == .active {
            state = .stopping
            controller?.stopPictureInPicture()
        } else if state != .restoring && state != .stopping {
            failAndRestore(reason: "pipeline-failed")
        }
    }

    private func failAndRestore(reason: String) {
        pendingSkipCompletion?(); pendingSkipCompletion = nil; pendingSkipGeneration = nil
        seekFallbackWorkItem?.cancel(); seekFallbackWorkItem = nil
        restoreInlineRendererWhenForeground(reason: reason, targetPosition: logicalPiPPosition) { [weak self] _, _ in self?.reset(reason: reason) }
    }

    private func restoreInlineRendererWhenForeground(reason: String, targetPosition: Double, completion: @escaping (Bool, Double?) -> Void) {
        guard !rendererSuspending else {
            pendingForegroundRestore = { [weak self] in self?.restoreInlineRendererWhenForeground(reason: reason, targetPosition: targetPosition, completion: completion) }
            DiagnosticsLogger.shared.playback("PiPSession", "renderer restore deferred reason=\(reason) wait=suspend-finish")
            return
        }
        guard inlineRendererSuspended else { completion(true, playbackController?.snapshot.position); return }
        guard UIApplication.shared.applicationState == .active else {
            pendingForegroundRestore = { [weak self] in self?.restoreInlineRendererWhenForeground(reason: reason, targetPosition: targetPosition, completion: completion) }
            DiagnosticsLogger.shared.playback("PiPSession", "renderer restore deferred reason=\(reason) appState=\(UIApplication.shared.applicationState.rawValue) wait=didBecomeActive")
            return
        }
        guard let inlineRenderer else { inlineRendererSuspended = false; completion(false, nil); return }
        DiagnosticsLogger.shared.playback("PiPSession", "inline-renderer restore begin reason=\(reason) target=\(String(format: "%.3f", targetPosition)) handoff=await-fresh-frame")
        inlineRenderer.resumeInlineRendererAfterPictureInPicture(targetPosition: targetPosition) { [weak self] success, actualPosition in
            guard let self else { completion(success, actualPosition); return }
            if success { self.inlineRendererSuspended = false }
            DiagnosticsLogger.shared.playback("PiPSession", "inline-renderer fresh-frame ready=\(success) reason=\(reason) target=\(String(format: "%.3f", targetPosition)) actual=\(actualPosition.map { String(format: "%.3f", $0) } ?? "unknown")")
            completion(success, actualPosition)
        }
    }



    private func beginRestoreHandoffIfPossible() {
        guard restoreRequested, !rendererRestoreReady, !rendererRestoreInProgress else { finishRestoreHandoffIfReady(); return }
        let target = currentPiPClockPosition()
        logicalPiPPosition = target
        rendererRestoreInProgress = true
        rendererRestoreAttempt += 1
        let attempt = rendererRestoreAttempt
        DiagnosticsLogger.shared.playback("PiPSession", "restore-handoff begin attempt=\(attempt) target=\(String(format: "%.3f", target)) appState=\(UIApplication.shared.applicationState.rawValue)")
        restoreInlineRendererWhenForeground(reason: "restore-ui", targetPosition: target) { [weak self] success, actualPosition in
            guard let self else { return }
            self.rendererRestoreInProgress = false
            self.rendererRestoreActualPosition = actualPosition
            if success {
                self.rendererRestoreReady = true
                self.finishRestoreHandoffIfReady()
                return
            }
            guard self.restoreRequested, self.rendererRestoreAttempt < 2 else {
                DiagnosticsLogger.shared.playback("PiPSession", "restore-handoff failed attempts=\(self.rendererRestoreAttempt) action=keep-samplebuffer-cover")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in self?.beginRestoreHandoffIfPossible() }
        }
    }

    private func finishRestoreHandoffIfReady() {
        guard restoreRequested, systemPiPStopped, rendererRestoreReady else { return }
        restoreRequested = false
        pipeline?.stop()
        let actual = rendererRestoreActualPosition
        DiagnosticsLogger.shared.playback("PiPSession", "restore-handoff visual-release actual=\(actual.map { String(format: "%.3f", $0) } ?? "unknown") action=fade-samplebuffer-cover")
        guard let host = sourceHostView, host.alpha > 0.001 else { reset(reason: "restore-handoff-complete"); return }
        UIView.animate(withDuration: 0.12, delay: 0, options: [.beginFromCurrentState, .curveEaseOut, .allowUserInteraction]) {
            host.alpha = 0
        } completion: { [weak self] _ in
            Task { @MainActor in self?.reset(reason: "restore-handoff-complete") }
        }
    }

    private func currentPiPClockPosition() -> Double {
        if let timebase = controlTimebase {
            let value = CMTimeGetSeconds(CMTimebaseGetTime(timebase))
            if value.isFinite, value >= 0 { return value }
        }
        return max(0, logicalPiPPosition)
    }

    private func handleForegroundActive() {
        let pending = pendingForegroundRestore
        pendingForegroundRestore = nil
        pending?()
        if restoreRequested { beginRestoreHandoffIfPossible() }
    }

    private func reset(reason: String) {
        startTimeout?.cancel(); startTimeout = nil
        startPoll?.cancel(); startPoll = nil
        seekFallbackWorkItem?.cancel(); seekFallbackWorkItem = nil
        pendingSkipCompletion?(); pendingSkipCompletion = nil; pendingSkipGeneration = nil
        pendingSeekStartedPosition = nil
        pendingSeekAuthoritativePosition = nil
        pendingSeekLandingHostTime = nil
        pendingForegroundRestore = nil
        restoreRequested = false
        systemPiPStopped = false
        rendererRestoreInProgress = false
        rendererRestoreReady = false
        rendererRestoreActualPosition = nil
        rendererRestoreAttempt = 0
        possibleObservation = nil
        if let seekLandingProvider { seekLandingProvider.pictureInPictureSeekLandingHandler = nil }
        seekLandingProvider = nil
        pipeline?.stop(); pipeline = nil
        displayLayer?.flushAndRemoveImage(); displayLayer?.controlTimebase = nil
        displayLayer = nil; controlTimebase = nil
        sourceHostView?.removeFromSuperview(); sourceHostView = nil
        controller?.delegate = nil; controller = nil
        activeSession = nil; playbackController = nil; inlineRenderer = nil
        firstVisibleSampleEnqueued = false; sourceSurfaceRevealed = false; activeGeneration = 0
        logicalPiPPosition = 0
        pipWantsPlayback = true
        inlineRendererSuspended = false
        rendererSuspending = false
        homeRequested = false
        state = .idle
        onActiveChanged?(false)
        onPossibleChanged?(AVPictureInPictureController.isPictureInPictureSupported())
        DiagnosticsLogger.shared.playback("PiPSession", "reset reason=\(reason)")
    }

    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DiagnosticsLogger.shared.playback("PiPSession", "system-will-start appState=\(UIApplication.shared.applicationState.rawValue) sourceSurface=visible controlsExpectedHidden=true")
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        startTimeout?.cancel(); startTimeout = nil
        state = .active
        onActiveChanged?(true)
        DiagnosticsLogger.shared.playback("PiPSession", "system-started engine=\(playbackController?.engineKind.title ?? "unknown") appState=\(UIApplication.shared.applicationState.rawValue) sourceLayerOwnedByHost=\(displayLayer?.superlayer === sourceHostView?.layer)")
        requestHomeAfterSystemStart()
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        let previousState = state
        let position = currentPiPClockPosition()
        logicalPiPPosition = position
        systemPiPStopped = true
        DiagnosticsLogger.shared.playback("PiPSession", "system-stopped position=\(String(format: "%.3f", position)) appState=\(UIApplication.shared.applicationState.rawValue) previousState=\(previousState.rawValue) restoreRequested=\(restoreRequested)")
        if restoreRequested || previousState == .restoring {
            state = .restoring
            beginRestoreHandoffIfPossible()
            finishRestoreHandoffIfReady()
            return
        }
        state = .stopping
        pipeline?.stop()
        restoreInlineRendererWhenForeground(reason: "system-stopped", targetPosition: position) { [weak self] _, _ in self?.reset(reason: "system-stopped") }
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        state = .restoring
        restoreRequested = true
        systemPiPStopped = false
        rendererRestoreReady = false
        rendererRestoreActualPosition = nil
        rendererRestoreAttempt = 0
        let target = currentPiPClockPosition()
        logicalPiPPosition = target
        DiagnosticsLogger.shared.playback("PiPSession", "restore-ui requested appState=\(UIApplication.shared.applicationState.rawValue) target=\(String(format: "%.3f", target)) policy=system-first-cover-until-fresh-frame")
        completionHandler(true)
        beginRestoreHandoffIfPossible()
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        DiagnosticsLogger.shared.playback("PiPSession", "system-start failed error=\(error.localizedDescription)")
        failAndRestore(reason: "system-start-failed")
    }

    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        guard let playbackController else { return .invalid }
        return CMTimeRange(start: .zero, duration: CMTime(seconds: max(0.001, playbackController.effectiveDuration), preferredTimescale: 60000))
    }

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool { !pipWantsPlayback }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        guard let playbackController else { return }
        pipWantsPlayback = playing
        if playbackController.playbackControlIsPlaying != playing { playbackController.togglePlayPause() }
        pipeline?.setPaused(pendingSkipCompletion != nil ? true : !playing)
        if pendingSkipGeneration == nil, pendingSkipCompletion == nil, let timebase = controlTimebase { CMTimebaseSetRate(timebase, rate: playing ? 1 : 0) }
        pictureInPictureController.invalidatePlaybackState()
        DiagnosticsLogger.shared.playback("PiPSession", "set-playing=\(playing) logicalPosition=\(String(format: "%.3f", logicalPiPPosition)) pendingSeek=\(pendingSkipCompletion != nil)")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        DiagnosticsLogger.shared.playback("PiPSession", "render-size=\(newRenderSize.width)x\(newRenderSize.height)")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping @Sendable () -> Void) {
        guard let playbackController, let pipeline, controlTimebase != nil else { completionHandler(); return }
        let delta = CMTimeGetSeconds(skipInterval)
        guard delta.isFinite else { completionHandler(); return }

        pendingSkipCompletion?()
        pendingSkipCompletion = completionHandler
        pendingSkipGeneration = nil
        pendingSeekStartedPosition = playbackController.snapshot.position
        pendingSeekAuthoritativePosition = nil
        pendingSeekLandingHostTime = nil
        seekFallbackWorkItem?.cancel(); seekFallbackWorkItem = nil
        if let timebase = controlTimebase { CMTimebaseSetRate(timebase, rate: 0) }
        pipeline.setPaused(true)
        displayLayer?.flush()
        playbackController.seek(by: delta)
        pictureInPictureController.invalidatePlaybackState()
        DiagnosticsLogger.shared.playback("PiPSession", "seek requested delta=\(String(format: "%.3f", delta)) engineStart=\(String(format: "%.3f", playbackController.snapshot.position)) policy=wait-authoritative-engine-landing pipelineHeld=true")
        if seekLandingProvider == nil { scheduleFallbackSeekLanding(attempt: 0) }
    }

    private func handleEngineSeekLanding(_ result: SeekResult) {
        guard pendingSkipCompletion != nil, let pipeline else { return }
        seekFallbackWorkItem?.cancel(); seekFallbackWorkItem = nil
        let authoritative = max(0, result.actualPosition ?? result.target)
        pendingSeekAuthoritativePosition = authoritative
        pendingSeekLandingHostTime = CACurrentMediaTime()
        displayLayer?.flush()
        activeGeneration = pipeline.seek(to: authoritative)
        pendingSkipGeneration = activeGeneration
        logicalPiPPosition = authoritative
        DiagnosticsLogger.shared.playback("PiPSession", "seek engine-landed requested=\(String(format: "%.3f", result.target)) actual=\(String(format: "%.3f", authoritative)) completionMs=\(String(format: "%.1f", result.completionLatencyMs)) generation=\(activeGeneration) action=align-sample-pipeline")
    }

    private func scheduleFallbackSeekLanding(attempt: Int) {
        seekFallbackWorkItem?.cancel()
        guard pendingSkipCompletion != nil, let playbackController, let start = pendingSeekStartedPosition else { return }
        let current = playbackController.snapshot.position
        let moved = abs(current - start) > 0.25 && !playbackController.snapshot.isBuffering
        if moved || attempt >= 30 {
            let authoritative = max(0, current)
            pendingSeekAuthoritativePosition = authoritative
            pendingSeekLandingHostTime = CACurrentMediaTime()
            if let pipeline {
                displayLayer?.flush()
                activeGeneration = pipeline.seek(to: authoritative)
                pendingSkipGeneration = activeGeneration
                logicalPiPPosition = authoritative
                DiagnosticsLogger.shared.playback("PiPSession", "seek fallback-landed actual=\(String(format: "%.3f", authoritative)) attempts=\(attempt) generation=\(activeGeneration)")
            } else { pendingSkipCompletion?(); pendingSkipCompletion = nil }
            return
        }
        let work = DispatchWorkItem { [weak self] in self?.scheduleFallbackSeekLanding(attempt: attempt + 1) }
        seekFallbackWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: work)
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
    private let placeholderImageView = UIImageView(image: UIImage(systemName: "pip"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isUserInteractionEnabled = false
        clipsToBounds = true
        placeholderImageView.tintColor = UIColor.white.withAlphaComponent(0.55)
        placeholderImageView.contentMode = .scaleAspectFit
        addSubview(placeholderImageView)
        layer.addSublayer(displayLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let iconSide = min(max(min(bounds.width, bounds.height) * 0.18, 56), 110)
        placeholderImageView.frame = CGRect(x: bounds.midX - iconSide * 0.5, y: bounds.midY - iconSide * 0.5, width: iconSide, height: iconSide)
        guard displayLayer.superlayer === layer else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true); displayLayer.frame = bounds; displayLayer.contentsScale = window?.screen.nativeScale ?? UIScreen.main.nativeScale; CATransaction.commit()
    }
}
