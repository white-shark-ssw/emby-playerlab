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
    private var deferredSystemPauseWorkItem: DispatchWorkItem?
    private var seekPauseSuppressionActive = false
    private var seekPauseEchoSuppressionUntil: CFTimeInterval = 0
    private var systemStopInProgress = false
    private var lastSystemPauseCommittedAt: CFTimeInterval?
    private var lastSystemPauseWasPlaying = false
    private var lastDisplayableSampleBuffer: CMSampleBuffer?
    private var systemStoppedRestoreAttempt = 0
    private var pendingRestoreUICompletion: ((Bool) -> Void)?
    private var restoreDestinationPoll: DispatchWorkItem?
    private var restoreDestinationStableSamples = 0
    private var lastRestoreDestinationWindowSize: CGSize?
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
        lastDisplayableSampleBuffer = envelope.buffer
        sourceHostView?.markVideoAvailable()
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
            seekPauseSuppressionActive = false
            if pipWantsPlayback { seekPauseEchoSuppressionUntil = CACurrentMediaTime() + 0.12 }
            DiagnosticsLogger.shared.playback("PiPSession", "seek-visible authoritativePts=\(String(format: "%.3f", envelope.pts)) generation=\(envelope.generation) requestedPlaying=\(pipWantsPlayback) pauseEchoSuppressionMs=\(pipWantsPlayback ? 120 : 0)")
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

    private func beginSystemStoppedHandoff(targetPosition: Double) {
        systemStoppedRestoreAttempt += 1
        let attempt = systemStoppedRestoreAttempt
        DiagnosticsLogger.shared.playback("PiPSession", "closed-pip handoff begin attempt=\(attempt) target=\(String(format: "%.3f", targetPosition)) appState=\(UIApplication.shared.applicationState.rawValue) cover=samplebuffer-live")
        restoreInlineRendererWhenForeground(reason: "system-stopped", targetPosition: targetPosition) { [weak self] success, actualPosition in
            guard let self else { return }
            if success {
                self.pipeline?.stop()
                DiagnosticsLogger.shared.playback("PiPSession", "closed-pip handoff renderer-ready=true actual=\(actualPosition.map { String(format: "%.3f", $0) } ?? "unknown") action=fade-live-samplebuffer-cover")
                guard let host = self.sourceHostView, host.alpha > 0.001 else { self.reset(reason: "system-stopped"); return }
                UIView.animate(withDuration: 0.12, delay: 0, options: [.beginFromCurrentState, .curveEaseOut, .allowUserInteraction]) {
                    host.alpha = 0
                } completion: { [weak self] _ in
                    Task { @MainActor in self?.reset(reason: "system-stopped") }
                }
                return
            }
            guard self.systemStoppedRestoreAttempt < 3 else {
                DiagnosticsLogger.shared.playback("PiPSession", "closed-pip handoff renderer-ready=false attempts=\(self.systemStoppedRestoreAttempt) action=forced-release-frozen-cover")
                self.pipeline?.stop()
                guard let host = self.sourceHostView, host.alpha > 0.001 else { self.reset(reason: "system-stopped-timeout"); return }
                UIView.animate(withDuration: 0.12, delay: 0, options: [.beginFromCurrentState, .curveEaseOut, .allowUserInteraction]) { host.alpha = 0 } completion: { [weak self] _ in
                    Task { @MainActor in self?.reset(reason: "system-stopped-timeout") }
                }
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in self?.beginSystemStoppedHandoff(targetPosition: targetPosition) }
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
        AppOrientationCoordinator.shared.endPictureInPictureRestoreOrientationHold()
        startTimeout?.cancel(); startTimeout = nil
        startPoll?.cancel(); startPoll = nil
        seekFallbackWorkItem?.cancel(); seekFallbackWorkItem = nil
        deferredSystemPauseWorkItem?.cancel(); deferredSystemPauseWorkItem = nil
        seekPauseSuppressionActive = false
        seekPauseEchoSuppressionUntil = 0
        systemStopInProgress = false
        lastSystemPauseCommittedAt = nil
        lastSystemPauseWasPlaying = false
        lastDisplayableSampleBuffer = nil
        systemStoppedRestoreAttempt = 0
        restoreDestinationPoll?.cancel(); restoreDestinationPoll = nil
        pendingRestoreUICompletion?(false); pendingRestoreUICompletion = nil
        restoreDestinationStableSamples = 0
        lastRestoreDestinationWindowSize = nil
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
        AppOrientationCoordinator.shared.beginPictureInPictureRestoreOrientationHold()
        DiagnosticsLogger.shared.playback("PiPSession", "system-started engine=\(playbackController?.engineKind.title ?? "unknown") appState=\(UIApplication.shared.applicationState.rawValue) sourceLayerOwnedByHost=\(displayLayer?.superlayer === sourceHostView?.layer) orientationHold=armed-before-home")
        requestHomeAfterSystemStart()
    }

    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        systemStopInProgress = true
        deferredSystemPauseWorkItem?.cancel(); deferredSystemPauseWorkItem = nil
        sourceHostView?.showFallbackFrame(from: lastDisplayableSampleBuffer)
        let now = CACurrentMediaTime()
        let rollbackPause = lastSystemPauseWasPlaying && lastSystemPauseCommittedAt.map { now - $0 <= 0.35 } == true
        if rollbackPause, !pipWantsPlayback { applyPiPPlayingState(true, controller: pictureInPictureController, reason: "system-stop-rollback-transient-pause") }
        DiagnosticsLogger.shared.playback("PiPSession", "system-will-stop appState=\(UIApplication.shared.applicationState.rawValue) restoreRequested=\(restoreRequested) rollbackTransientPause=\(rollbackPause) fallbackFrame=\(sourceHostView?.hasFallbackFrame == true)")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        let previousState = state
        let position = currentPiPClockPosition()
        logicalPiPPosition = position
        systemPiPStopped = true
        DiagnosticsLogger.shared.playback("PiPSession", "system-stopped position=\(String(format: "%.3f", position)) appState=\(UIApplication.shared.applicationState.rawValue) previousState=\(previousState.rawValue) restoreRequested=\(restoreRequested)")
        if restoreRequested || previousState == .restoring {
            AppOrientationCoordinator.shared.endPictureInPictureRestoreOrientationHold()
            state = .restoring
            beginRestoreHandoffIfPossible()
            finishRestoreHandoffIfReady()
            return
        }
        state = .stopping
        AppOrientationCoordinator.shared.endPictureInPictureRestoreOrientationHold()
        systemStoppedRestoreAttempt = 0
        sourceHostView?.showFallbackFrame(from: lastDisplayableSampleBuffer)
        pipeline?.setPaused(!pipWantsPlayback)
        if let timebase = controlTimebase { CMTimebaseSetRate(timebase, rate: pipWantsPlayback ? 1 : 0) }
        let enginePosition = playbackController?.snapshot.position ?? position
        let authoritativeTarget = enginePosition.isFinite && enginePosition >= 0 ? enginePosition : position
        DiagnosticsLogger.shared.playback("PiPSession", "system-stopped direct-return path=closed-pip cover=frozen-last-frame orientationHold=released pipClock=\(String(format: "%.3f", position)) engineAuthority=\(String(format: "%.3f", authoritativeTarget)) playing=\(pipWantsPlayback)")
        beginSystemStoppedHandoff(targetPosition: authoritativeTarget)
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
        AppOrientationCoordinator.shared.beginPictureInPictureRestoreOrientationHold()
        AppOrientationCoordinator.shared.preparePictureInPictureRestoreDestination()
        pendingRestoreUICompletion = completionHandler
        restoreDestinationStableSamples = 0
        lastRestoreDestinationWindowSize = nil
        DiagnosticsLogger.shared.playback("PiPSession", "restore-ui requested appState=\(UIApplication.shared.applicationState.rawValue) target=\(String(format: "%.3f", target)) policy=wait-final-destination-geometry-before-system-expand orientationHold=armed-before-foreground")
        pollRestoreDestinationGeometry(attempt: 0)
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
        if playing {
            deferredSystemPauseWorkItem?.cancel(); deferredSystemPauseWorkItem = nil
            lastSystemPauseCommittedAt = nil
            lastSystemPauseWasPlaying = false
            applyPiPPlayingState(true, controller: pictureInPictureController, reason: "system-play")
            return
        }
        guard pipWantsPlayback else {
            applyPiPPlayingState(false, controller: pictureInPictureController, reason: "system-pause-already-paused")
            return
        }
        if systemStopInProgress {
            DiagnosticsLogger.shared.playback("PiPSession", "set-playing=false suppressed reason=system-stop-in-progress")
            return
        }
        let now = CACurrentMediaTime()
        if seekPauseSuppressionActive || pendingSkipCompletion != nil || pendingSkipGeneration != nil || now < seekPauseEchoSuppressionUntil {
            DiagnosticsLogger.shared.playback("PiPSession", "set-playing=false suppressed reason=seek-transaction active=\(seekPauseSuppressionActive) pending=\(pendingSkipCompletion != nil || pendingSkipGeneration != nil) echoRemainingMs=\(Int(max(0, seekPauseEchoSuppressionUntil - now) * 1000))")
            return
        }
        deferredSystemPauseWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self, weak pictureInPictureController] in
            guard let self, let pictureInPictureController else { return }
            self.deferredSystemPauseWorkItem = nil
            let current = CACurrentMediaTime()
            guard !self.seekPauseSuppressionActive, self.pendingSkipCompletion == nil, self.pendingSkipGeneration == nil, current >= self.seekPauseEchoSuppressionUntil else {
                DiagnosticsLogger.shared.playback("PiPSession", "set-playing=false suppressed reason=seek-transaction-became-active")
                return
            }
            self.lastSystemPauseWasPlaying = self.pipWantsPlayback
            self.lastSystemPauseCommittedAt = CACurrentMediaTime()
            self.applyPiPPlayingState(false, controller: pictureInPictureController, reason: "system-pause-committed")
        }
        deferredSystemPauseWorkItem = work
        DispatchQueue.main.async(execute: work)
        DiagnosticsLogger.shared.playback("PiPSession", "set-playing=false deferred=next-main-turn logicalPosition=\(String(format: "%.3f", logicalPiPPosition)) classification=wait-for-synchronous-skip")
    }

    private func applyPiPPlayingState(_ playing: Bool, controller pictureInPictureController: AVPictureInPictureController, reason: String) {
        guard let playbackController else { return }
        pipWantsPlayback = playing
        if playbackController.playbackControlIsPlaying != playing { playbackController.togglePlayPause() }
        let aligningPipeline = pendingSkipGeneration != nil
        pipeline?.setPaused(aligningPipeline ? true : !playing)
        if !aligningPipeline, let timebase = controlTimebase { CMTimebaseSetRate(timebase, rate: playing ? 1 : 0) }
        pictureInPictureController.invalidatePlaybackState()
        DiagnosticsLogger.shared.playback("PiPSession", "set-playing=\(playing) reason=\(reason) logicalPosition=\(String(format: "%.3f", logicalPiPPosition)) pendingSeek=\(pendingSkipCompletion != nil) aligningPipeline=\(aligningPipeline)")
    }

    private func pollRestoreDestinationGeometry(attempt: Int) {
        restoreDestinationPoll?.cancel(); restoreDestinationPoll = nil
        guard pendingRestoreUICompletion != nil, restoreRequested else { return }
        let window = sourceHostView?.window ?? activeKeyWindow()
        let windowSize = window?.bounds.size ?? .zero
        let hostSize = sourceHostView?.bounds.size ?? .zero
        let targetOrientation = AppOrientationCoordinator.shared.pictureInPictureRestoreTargetOrientation
        let windowHasArea = windowSize.width > 1 && windowSize.height > 1
        let hostHasArea = hostSize.width > 1 && hostSize.height > 1
        let orientationReady: Bool
        if let targetOrientation { orientationReady = targetOrientation.isLandscape ? windowSize.width > windowSize.height : windowSize.height > windowSize.width }
        else { orientationReady = windowHasArea }
        let hostOrientationReady: Bool
        if let targetOrientation { hostOrientationReady = targetOrientation.isLandscape ? hostSize.width > hostSize.height : hostSize.height > hostSize.width }
        else { hostOrientationReady = hostHasArea }
        let windowStable = lastRestoreDestinationWindowSize.map { abs($0.width - windowSize.width) < 0.5 && abs($0.height - windowSize.height) < 0.5 } ?? false
        if UIApplication.shared.applicationState == .active, windowHasArea, hostHasArea, orientationReady, hostOrientationReady, windowStable { restoreDestinationStableSamples += 1 }
        else { restoreDestinationStableSamples = 0 }
        lastRestoreDestinationWindowSize = windowSize

        if restoreDestinationStableSamples >= 2 { finishRestoreUICompletion(reason: "final-geometry-stable", windowSize: windowSize, hostSize: hostSize); return }
        if attempt >= 75 { finishRestoreUICompletion(reason: "geometry-timeout-fallback", windowSize: windowSize, hostSize: hostSize); return }
        let work = DispatchWorkItem { [weak self] in self?.pollRestoreDestinationGeometry(attempt: attempt + 1) }
        restoreDestinationPoll = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016, execute: work)
    }

    private func finishRestoreUICompletion(reason: String, windowSize: CGSize, hostSize: CGSize) {
        restoreDestinationPoll?.cancel(); restoreDestinationPoll = nil
        restoreDestinationStableSamples = 0
        lastRestoreDestinationWindowSize = nil
        let completion = pendingRestoreUICompletion
        pendingRestoreUICompletion = nil
        DiagnosticsLogger.shared.playback("PiPSession", "restore-ui destination-ready reason=\(reason) window=\(Int(windowSize.width))x\(Int(windowSize.height)) host=\(Int(hostSize.width))x\(Int(hostSize.height)) action=system-expand-once")
        completion?(true)
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        DiagnosticsLogger.shared.playback("PiPSession", "render-size=\(newRenderSize.width)x\(newRenderSize.height)")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping @Sendable () -> Void) {
        guard let playbackController, let pipeline, controlTimebase != nil else { completionHandler(); return }
        let delta = CMTimeGetSeconds(skipInterval)
        guard delta.isFinite else { completionHandler(); return }

        let previousWasAligning = pendingSkipGeneration != nil
        let suppressedTransientPause = deferredSystemPauseWorkItem != nil
        deferredSystemPauseWorkItem?.cancel(); deferredSystemPauseWorkItem = nil
        seekPauseSuppressionActive = pipWantsPlayback
        seekPauseEchoSuppressionUntil = 0
        if suppressedTransientPause { DiagnosticsLogger.shared.playback("PiPSession", "system-pause suppressed reason=skip-callback-arrived playing=\(pipWantsPlayback) policy=seek-transaction") }
        pendingSkipCompletion?()
        pendingSkipCompletion = {}
        pendingSkipGeneration = nil
        pendingSeekStartedPosition = playbackController.snapshot.position
        pendingSeekAuthoritativePosition = nil
        pendingSeekLandingHostTime = nil
        seekFallbackWorkItem?.cancel(); seekFallbackWorkItem = nil
        if previousWasAligning {
            pipeline.setPaused(!pipWantsPlayback)
            if let timebase = controlTimebase { CMTimebaseSetRate(timebase, rate: pipWantsPlayback ? 1 : 0) }
        }
        playbackController.seek(by: delta)
        completionHandler()
        pictureInPictureController.invalidatePlaybackState()
        DiagnosticsLogger.shared.playback("PiPSession", "seek requested delta=\(String(format: "%.3f", delta)) engineStart=\(String(format: "%.3f", playbackController.snapshot.position)) policy=seek-transaction-visual-continues systemCompletion=immediate-after-command previousAligning=\(previousWasAligning)")
        if seekLandingProvider == nil { scheduleFallbackSeekLanding(attempt: 0) }
    }

    private func handleEngineSeekLanding(_ result: SeekResult) {
        guard pendingSkipCompletion != nil, let pipeline else { return }
        seekFallbackWorkItem?.cancel(); seekFallbackWorkItem = nil
        let authoritative = max(0, result.actualPosition ?? result.target)
        pendingSeekAuthoritativePosition = authoritative
        pendingSeekLandingHostTime = CACurrentMediaTime()
        if let timebase = controlTimebase { CMTimebaseSetRate(timebase, rate: 0) }
        pipeline.setPaused(true)
        displayLayer?.flush()
        activeGeneration = pipeline.seek(to: authoritative)
        pendingSkipGeneration = activeGeneration
        logicalPiPPosition = authoritative
        DiagnosticsLogger.shared.playback("PiPSession", "seek engine-landed requested=\(String(format: "%.3f", result.target)) actual=\(String(format: "%.3f", authoritative)) completionMs=\(String(format: "%.1f", result.completionLatencyMs)) generation=\(activeGeneration) action=short-freeze-align-sample-pipeline")
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
                if let timebase = controlTimebase { CMTimebaseSetRate(timebase, rate: 0) }
                pipeline.setPaused(true)
                displayLayer?.flush()
                activeGeneration = pipeline.seek(to: authoritative)
                pendingSkipGeneration = activeGeneration
                logicalPiPPosition = authoritative
                DiagnosticsLogger.shared.playback("PiPSession", "seek fallback-landed actual=\(String(format: "%.3f", authoritative)) attempts=\(attempt) generation=\(activeGeneration) action=short-freeze-align-sample-pipeline")
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
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: { $0.isKeyWindow })
    }

    private func findVisibleSubview<T: UIView>(of type: T.Type, in root: UIView) -> T? {
        if let value = root as? T, !value.isHidden, value.alpha > 0.01, value.window != nil { return value }
        for child in root.subviews.reversed() { if let value = findVisibleSubview(of: type, in: child) { return value } }
        return nil
    }
}