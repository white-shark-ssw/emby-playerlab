import AVFoundation
import AVKit
import CoreMedia
import UIKit

@MainActor
final class PlayerPiPSessionCoordinator: NSObject, @preconcurrency AVPictureInPictureControllerDelegate, @preconcurrency AVPictureInPictureSampleBufferPlaybackDelegate {
    var onPossibleChanged: ((Bool) -> Void)?
    var onActiveChanged: ((Bool) -> Void)?

    private struct PiPClock {
        var anchorPosition: Double = 0
        var anchorHostTime: CFTimeInterval = CACurrentMediaTime()
        var rate: Double = 1

        mutating func reset(position: Double, playing: Bool, now: CFTimeInterval = CACurrentMediaTime()) {
            anchorPosition = max(0, position)
            anchorHostTime = now
            rate = playing ? 1 : 0
        }

        mutating func setPlaying(_ playing: Bool, now: CFTimeInterval = CACurrentMediaTime()) {
            let current = position(at: now)
            anchorPosition = current
            anchorHostTime = now
            rate = playing ? 1 : 0
        }

        func position(at now: CFTimeInterval = CACurrentMediaTime()) -> Double { max(0, anchorPosition + max(0, now - anchorHostTime) * rate) }
    }

    private final class SeekStagingContext {
        let token: UInt64
        let predictedTarget: Double
        let pipeline: PlayerPiPSamplePipeline
        var generation: UInt64 = 1
        var samples: [PlayerPiPSamplePipeline.SampleEnvelope] = []
        var firstDisplayablePTS: Double?
        var pausedAfterPreroll = false
        var optimisticCommitEnabled = false
        var committedSpeculatively = false
        var speculativePTS: Double?

        init(token: UInt64, predictedTarget: Double, pipeline: PlayerPiPSamplePipeline) {
            self.token = token
            self.predictedTarget = predictedTarget
            self.pipeline = pipeline
        }
    }

    private(set) var behavior = PlayerPiPBehaviorState()
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
    private var standbyPipeline: PlayerPiPSamplePipeline?
    private var activeGeneration: UInt64 = 0
    private var controlTimebase: CMTimebase?
    private var clock = PiPClock()
    private var startTimeout: DispatchWorkItem?
    private var startPoll: DispatchWorkItem?
    private var pendingSystemPauseWorkItem: DispatchWorkItem?
    private var seekFallbackWorkItem: DispatchWorkItem?
    private var seekSettleWorkItem: DispatchWorkItem?
    private var seekToken: UInt64 = 0
    private var activeSeekToken: UInt64?
    private var activeSeekRequestedTarget: Double?
    private var activeSeekStartedPosition: Double?
    private var activeSeekLandingHostTime: CFTimeInterval?
    private var fallbackSeekGeneration: UInt64?
    private var fallbackSeekSamples: [PlayerPiPSamplePipeline.SampleEnvelope] = []
    private var stagingContext: SeekStagingContext?
    private var firstVisibleSampleEnqueued = false
    private var sourceSurfaceRevealed = false
    private var foregroundObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?
    private var pendingForegroundRendererRestore: (() -> Void)?
    private var homeRequested = false
    private var returnRendererReady = false
    private var returnRendererRestoreInProgress = false
    private var returnActualPosition: Double?
    private var returnPollWorkItem: DispatchWorkItem?
    private var pendingRestoreUICompletion: ((Bool) -> Void)?
    private var manualForegroundReturn = false
    private var returnSystemStopped = false
    private var returnSurfaceReplayRequested = false
    private var returnPostStopRetryCount = 0
    private var returnHandoffDisplayLink: CADisplayLink?
    private let homeCoordinator = PlayerPiPHomeCoordinator()

    override init() {
        super.init()
        foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.handleForegroundActive() } }
        backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.handleBackgroundEntered() } }
    }

    deinit {
        if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
        if let backgroundObserver { NotificationCenter.default.removeObserver(backgroundObserver) }
    }

    func toggle(using playbackController: PlayerController) {
        if controller?.isPictureInPictureActive == true {
            beginReturnToPlayer(reason: "app-toggle", systemCompletion: nil, manualForeground: true)
            return
        }
        guard behavior.presentation == .idle else {
            DiagnosticsLogger.shared.playback("PiPState", "toggle ignored presentation=\(behavior.presentation.rawValue) exit=\(behavior.exitIntent.rawValue)")
            return
        }
        prepare(using: playbackController)
    }

    func stopAndDetach() {
        behavior.exitIntent = .detach
        pendingSystemPauseWorkItem?.cancel(); pendingSystemPauseWorkItem = nil
        cancelSeekTransaction(reason: "detach")
        pendingRestoreUICompletion?(false); pendingRestoreUICompletion = nil
        returnPollWorkItem?.cancel(); returnPollWorkItem = nil
        if controller?.isPictureInPictureActive == true {
            behavior.presentation = .closing
            controller?.stopPictureInPicture()
            return
        }
        reset(reason: "detach")
    }

    private func prepare(using playbackController: PlayerController) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { onPossibleChanged?(false); return }
        guard let session = PlaybackTransportSessionRegistry.shared.session(itemId: playbackController.source.itemId) else {
            DiagnosticsLogger.shared.playback("PiPState", "prepare failed reason=no-active-unified-session item=\(playbackController.source.itemId)")
            return
        }
        guard let sourceView = visiblePlaybackSurface() else {
            DiagnosticsLogger.shared.playback("PiPState", "prepare failed reason=no-visible-playback-surface")
            return
        }

        reset(reason: "prepare-new")
        self.playbackController = playbackController
        activeSession = session
        behavior.beginSession(isPlaying: playbackController.playbackControlIsPlaying)
        clock.reset(position: playbackController.snapshot.position, playing: behavior.playback == .playing)
        inlineRenderer = (playbackController.engine as? PlayerPiPInlineRendererControlling) ?? (sourceView as? PlayerPiPInlineRendererControlling)
        if let provider = playbackController.engine as? PlayerPiPSeekLandingProviding {
            seekLandingProvider = provider
            provider.pictureInPictureSeekDispatchHandler = { [weak self] info in DispatchQueue.main.async { self?.handleEngineSeekDispatch(info) } }
            provider.pictureInPictureSeekLandingHandler = { [weak self] result in DispatchQueue.main.async { self?.handleEngineSeekLanding(result) } }
        }

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
            DiagnosticsLogger.shared.playback("PiPState", "prepare failed reason=timebase status=\(status)")
            reset(reason: "timebase-failed")
            return
        }
        syncTimebase(timebase, to: clock.position(), playing: behavior.playback == .playing)
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
        let activePipeline = PlayerPiPSamplePipeline(session: session, startPosition: clock.position())
        pipeline = activePipeline
        bindActivePipeline(activePipeline)
        activePipeline.setPaused(behavior.playback != .playing)
        activeGeneration = activePipeline.start()
        prepareStandbyPipelineIfNeeded(startPosition: clock.position())
        scheduleStartTimeout()
        DiagnosticsLogger.shared.playback("PiPState", "session prepared playback=\(behavior.playback.rawValue) presentation=\(behavior.presentation.rawValue) position=\(String(format: "%.3f", clock.position())) generation=\(activeGeneration) renderer=\(inlineRenderer == nil ? "none" : "engine-or-surface")")
    }

    private func bindActivePipeline(_ activePipeline: PlayerPiPSamplePipeline) {
        activePipeline.onReady = { info in DispatchQueue.main.async { DiagnosticsLogger.shared.playback("PiPPipeline", "active ready \(info)") } }
        activePipeline.onFailure = { [weak self, weak activePipeline] reason in DispatchQueue.main.async {
            guard let self, self.pipeline === activePipeline else { return }
            self.handlePipelineFailure(reason)
        } }
        activePipeline.onSample = { [weak self, weak activePipeline] envelope in DispatchQueue.main.async {
            guard let self, let activePipeline, self.pipeline === activePipeline else { return }
            self.handleActivePipelineSample(envelope)
        } }
    }

    private func prepareStandbyPipelineIfNeeded(startPosition: Double) {
        guard standbyPipeline == nil, let session = activeSession else { return }
        let standby = PlayerPiPSamplePipeline(session: session, startPosition: max(0, startPosition))
        standbyPipeline = standby
        standby.setPaused(true)
        standby.onReady = { info in DispatchQueue.main.async { DiagnosticsLogger.shared.playback("PiPPipeline", "standby ready \(info)") } }
        standby.onFailure = { [weak self, weak standby] reason in DispatchQueue.main.async {
            guard let self, let standby, self.standbyPipeline === standby else { return }
            DiagnosticsLogger.shared.playback("PiPPipeline", "standby failed reason=\(reason) action=drop-standby")
            self.standbyPipeline = nil
        } }
        standby.onSample = { _ in }
        _ = standby.start()
        DiagnosticsLogger.shared.playback("PiPPipeline", "standby warm start position=\(String(format: "%.3f", startPosition)) persistentDemux=true")
    }

    private func handleActivePipelineSample(_ envelope: PlayerPiPSamplePipeline.SampleEnvelope) {
        guard let displayLayer, displayLayer.status != .failed else { handleDisplayLayerFailure(); return }

        if let fallbackGeneration = fallbackSeekGeneration, envelope.generation == fallbackGeneration {
            fallbackSeekSamples.append(envelope)
            if fallbackSeekSamples.count > 80 { fallbackSeekSamples.removeFirst(fallbackSeekSamples.count - 80) }
            if envelope.displayable { commitSeekVisual(using: fallbackSeekSamples, authoritative: currentAuthoritativeSeekPosition() ?? envelope.pts, promotedPipeline: nil, token: activeSeekToken, source: "active-fallback") }
            return
        }

        guard envelope.generation == activeGeneration else { return }
        displayLayer.enqueue(envelope.buffer)
        guard envelope.displayable else { return }
        sourceHostView?.markVideoAvailable()
        if !firstVisibleSampleEnqueued {
            firstVisibleSampleEnqueued = true
            clock.reset(position: envelope.pts, playing: behavior.playback == .playing)
            syncTimebaseToClock()
            revealSourceSurfaceIfNeeded()
            DiagnosticsLogger.shared.playback("PiPState", "first-visible-sample pts=\(String(format: "%.3f", envelope.pts)) generation=\(envelope.generation) key=\(envelope.keyframe)")
            pollStart(attempt: 0)
        }
    }

    private func handleDisplayLayerFailure() {
        if let error = displayLayer?.error { DiagnosticsLogger.shared.playback("PiPState", "display-layer failed error=\(error.localizedDescription)") }
        handlePipelineFailure("display-layer-failed")
    }

    private func revealSourceSurfaceIfNeeded() {
        guard !sourceSurfaceRevealed, let host = sourceHostView else { return }
        sourceSurfaceRevealed = true
        UIView.performWithoutAnimation { host.alpha = 1; host.layoutIfNeeded() }
    }

    private func observePossible(_ systemController: AVPictureInPictureController) {
        possibleObservation = systemController.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] controller, _ in DispatchQueue.main.async {
            guard let self else { return }
            self.onPossibleChanged?(controller.isPictureInPicturePossible || AVPictureInPictureController.isPictureInPictureSupported())
            self.startIfReady()
        } }
    }

    private func pollStart(attempt: Int) {
        startPoll?.cancel()
        guard behavior.presentation == .preparing else { return }
        startIfReady()
        guard behavior.presentation == .preparing, attempt < 80 else { return }
        let work = DispatchWorkItem { [weak self] in self?.pollStart(attempt: attempt + 1) }
        startPoll = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    private func startIfReady() {
        guard behavior.presentation == .preparing, firstVisibleSampleEnqueued, sourceSurfaceRevealed, let controller, let displayLayer else { return }
        guard controller.isPictureInPicturePossible, displayLayer.status != .failed else { return }
        startPoll?.cancel(); startPoll = nil
        behavior.presentation = .starting
        DiagnosticsLogger.shared.playback("PiPState", "system-start begin playback=\(behavior.playback.rawValue) sourceSurface=visible")
        controller.startPictureInPicture()
    }

    private func scheduleStartTimeout() {
        startTimeout?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.behavior.presentation == .preparing || self.behavior.presentation == .starting else { return }
            self.failAndRecover(reason: "start-timeout")
        }
        startTimeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: work)
    }

    private func requestHomeAfterSystemStart() {
        guard !homeRequested else { return }
        homeRequested = true
        let requested = homeCoordinator.requestHome()
        DiagnosticsLogger.shared.playback("PiPState", "home-request issued=\(requested) policy=after-video-track-suspend rendererSuspended=\(inlineRendererSuspended)")
    }

    private func prepareRendererForHomeAfterSystemStart() {
        guard !homeRequested else { return }
        guard !inlineRendererSuspended, !rendererSuspending, let inlineRenderer else { requestHomeAfterSystemStart(); return }
        rendererSuspending = true
        DiagnosticsLogger.shared.playback("PiPState", "video-track suspend begin phase=pre-home playback=\(behavior.playback.rawValue)")
        inlineRenderer.suspendInlineRendererForPictureInPicture { [weak self] success in
            guard let self else { return }
            self.rendererSuspending = false
            self.inlineRendererSuspended = success
            DiagnosticsLogger.shared.playback("PiPState", "video-track suspend success=\(success) phase=pre-home action=\(success ? "request-home" : "cancel-pip")")
            if success { self.requestHomeAfterSystemStart() }
            else {
                self.behavior.exitIntent = .failureFallback
                self.behavior.presentation = .recovering
                self.controller?.stopPictureInPicture()
            }
        }
    }

    private func handleBackgroundEntered() {
        guard controller?.isPictureInPictureActive == true, behavior.presentation == .active || behavior.presentation == .returning else { return }
        guard !inlineRendererSuspended, !rendererSuspending, let inlineRenderer else { return }
        rendererSuspending = true
        DiagnosticsLogger.shared.playback("PiPState", "renderer suspend begin phase=didEnterBackground")
        inlineRenderer.suspendInlineRendererForPictureInPicture { [weak self] success in
            guard let self else { return }
            self.rendererSuspending = false
            self.inlineRendererSuspended = success
            DiagnosticsLogger.shared.playback("PiPState", "renderer suspend success=\(success)")
            if UIApplication.shared.applicationState == .active { self.handleForegroundActive() }
        }
    }

    private func handleForegroundActive() {
        let pendingRestore = pendingForegroundRendererRestore
        pendingForegroundRendererRestore = nil
        pendingRestore?()

        if behavior.presentation == .backgroundPaused, behavior.exitIntent == .pauseAndSuspend {
            DiagnosticsLogger.shared.playback("PiPState", "foreground restore detected intent=pauseAndSuspend playback=paused")
            beginPausedForegroundRestore()
            return
        }

        guard controller?.isPictureInPictureActive == true, behavior.presentation == .active, behavior.exitIntent == .none, homeRequested else { return }
        DiagnosticsLogger.shared.playback("PiPState", "foreground return detected intent=returnToPlayer")
        beginReturnToPlayer(reason: "app-foreground", systemCompletion: nil, manualForeground: true)
    }

    private func restoreInlineRendererWhenForeground(targetPosition: Double, completion: @escaping (Bool, Double?) -> Void) {
        guard !rendererSuspending else {
            pendingForegroundRendererRestore = { [weak self] in self?.restoreInlineRendererWhenForeground(targetPosition: targetPosition, completion: completion) }
            return
        }
        guard UIApplication.shared.applicationState == .active else {
            pendingForegroundRendererRestore = { [weak self] in self?.restoreInlineRendererWhenForeground(targetPosition: targetPosition, completion: completion) }
            return
        }
        guard let inlineRenderer else { inlineRendererSuspended = false; completion(false, nil); return }
        inlineRenderer.resumeInlineRendererAfterPictureInPicture(targetPosition: targetPosition) { [weak self] success, actualPosition in
            guard let self else { completion(success, actualPosition); return }
            self.inlineRendererSuspended = !success
            completion(success, actualPosition)
        }
    }

    private func beginReturnToPlayer(reason: String, systemCompletion: ((Bool) -> Void)?, manualForeground: Bool) {
        guard behavior.playback != .stopped else { systemCompletion?(false); return }
        if behavior.exitIntent == .pauseAndSuspend || behavior.exitIntent == .detach { systemCompletion?(false); return }
        if behavior.exitIntent == .returnToPlayer, behavior.presentation == .returning {
            manualForegroundReturn = manualForegroundReturn || manualForeground
            if let systemCompletion {
                pendingRestoreUICompletion?(false)
                pendingRestoreUICompletion = systemCompletion
            }
            DiagnosticsLogger.shared.playback("PiPState", "return join existing reason=\(reason) manual=\(manualForegroundReturn) systemCompletion=\(systemCompletion != nil) rendererReady=\(returnRendererReady)")
            if !returnRendererReady, !returnRendererRestoreInProgress { beginReturnRendererRestore(targetPosition: playbackController?.snapshot.position ?? clock.position()) }
            pollReturnBarrier(attempt: 0)
            return
        }
        behavior.exitIntent = .returnToPlayer
        behavior.presentation = .returning
        manualForegroundReturn = manualForeground
        if let systemCompletion {
            pendingRestoreUICompletion?(false)
            pendingRestoreUICompletion = systemCompletion
        }
        returnRendererReady = false
        returnRendererRestoreInProgress = false
        returnActualPosition = nil
        returnSystemStopped = false
        returnSurfaceReplayRequested = false
        returnPostStopRetryCount = 0
        pendingSystemPauseWorkItem?.cancel(); pendingSystemPauseWorkItem = nil
        AppOrientationCoordinator.shared.beginPictureInPictureRestoreOrientationHold()
        AppOrientationCoordinator.shared.preparePictureInPictureRestoreDestination()
        let target = playbackController?.snapshot.position ?? clock.position()
        DiagnosticsLogger.shared.playback("PiPState", "return begin reason=\(reason) target=\(String(format: "%.3f", target)) authority=mpv-snapshot manual=\(manualForeground) systemCompletion=\(systemCompletion != nil)")
        pollReturnBarrier(attempt: 0)
    }

    private func beginReturnRendererRestore(targetPosition: Double) {
        guard !returnRendererReady, !returnRendererRestoreInProgress else { return }
        returnRendererRestoreInProgress = true
        restoreInlineRendererWhenForeground(targetPosition: targetPosition) { [weak self] success, actualPosition in
            guard let self else { return }
            self.returnRendererRestoreInProgress = false
            self.returnRendererReady = success
            self.returnActualPosition = actualPosition
            if success {
                if self.behavior.exitIntent == .pauseAndSuspend {
                    AppOrientationCoordinator.shared.armPictureInPicturePresentationRelease()
                } else if self.behavior.exitIntent == .returnToPlayer {
                    if self.returnSystemStopped { self.scheduleReturnVisualHandoffAfterSystemStop() }
                    else { DiagnosticsLogger.shared.playback("PiPState", "return renderer ready before system stop action=hold-bridge-until-didStop") }
                }
            }
            let releaseState = success ? (self.behavior.exitIntent == .pauseAndSuspend ? "armed-paused-restore" : (self.returnSystemStopped ? "awaiting-next-vsync" : "awaiting-system-stop")) : "held"
            DiagnosticsLogger.shared.playback("PiPState", "return renderer-ready=\(success) target=\(String(format: "%.3f", targetPosition)) actual=\(actualPosition.map { String(format: "%.3f", $0) } ?? "unknown") presentationRelease=\(releaseState)")
            if !success { self.failReturnBarrier(reason: "renderer-not-ready") }
        }
    }

    private func pollReturnBarrier(attempt: Int) {
        returnPollWorkItem?.cancel(); returnPollWorkItem = nil
        guard behavior.presentation == .returning, behavior.exitIntent == .returnToPlayer || behavior.exitIntent == .pauseAndSuspend else { return }
        let window = activeKeyWindow()
        let windowSize = window?.bounds.size ?? .zero
        let hostSize = sourceHostView?.bounds.size ?? .zero
        let targetOrientation = AppOrientationCoordinator.shared.pictureInPictureRestoreTargetOrientation
        let orientationReady: Bool
        if let targetOrientation { orientationReady = targetOrientation.isLandscape ? windowSize.width > windowSize.height : windowSize.height > windowSize.width }
        else { orientationReady = windowSize.width > 1 && windowSize.height > 1 }
        let hostReady = behavior.exitIntent == .pauseAndSuspend || (hostSize.width > 1 && hostSize.height > 1)
        let gateReleased = !PlayerSurfacePresentationGate.shared.isHolding
        let appReady = UIApplication.shared.applicationState == .active

        if appReady, orientationReady, hostReady, !returnSurfaceReplayRequested {
            returnSurfaceReplayRequested = true
            AppOrientationCoordinator.shared.replayPictureInPictureSurface()
            let target = playbackController?.snapshot.position ?? clock.position()
            DiagnosticsLogger.shared.playback("PiPState", "return surface replay requested target=\(String(format: "%.3f", target)) authority=mpv-snapshot window=\(Int(windowSize.width))x\(Int(windowSize.height))")
            beginReturnRendererRestore(targetPosition: target)
        }

        let ready = appReady && orientationReady && hostReady && gateReleased && returnRendererReady
        if ready {
            DiagnosticsLogger.shared.playback("PiPState", "return barrier ready renderer=true gateReleased=true systemStopped=\(returnSystemStopped) exit=\(behavior.exitIntent.rawValue) window=\(Int(windowSize.width))x\(Int(windowSize.height)) host=\(Int(hostSize.width))x\(Int(hostSize.height))")
            if behavior.exitIntent == .pauseAndSuspend {
                completePausedForegroundRestore()
            } else if returnSystemStopped {
                completeReturnAfterSystemStop()
            } else if let completion = pendingRestoreUICompletion {
                pendingRestoreUICompletion = nil
                completion(true)
            } else if manualForegroundReturn, controller?.isPictureInPictureActive == true {
                manualForegroundReturn = false
                controller?.stopPictureInPicture()
            }
            return
        }
        if attempt >= 180 {
            DiagnosticsLogger.shared.playback("PiPState", "return barrier timeout renderer=\(returnRendererReady) gateReleased=\(gateReleased) appReady=\(appReady) orientationReady=\(orientationReady) systemStopped=\(returnSystemStopped) exit=\(behavior.exitIntent.rawValue)")
            failReturnBarrier(reason: "barrier-timeout")
            return
        }
        let work = DispatchWorkItem { [weak self] in self?.pollReturnBarrier(attempt: attempt + 1) }
        returnPollWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016, execute: work)
    }

    private func failReturnBarrier(reason: String) {
        returnPollWorkItem?.cancel(); returnPollWorkItem = nil
        if behavior.exitIntent == .pauseAndSuspend {
            guard returnPostStopRetryCount < 3 else {
                DiagnosticsLogger.shared.playback("PiPState", "paused foreground restore exhausted reason=\(reason) retries=\(returnPostStopRetryCount) action=release-cover-keep-paused")
                PlayerSurfacePresentationGate.shared.reset(reason: "pip-paused-restore-exhausted")
                AppOrientationCoordinator.shared.endPictureInPictureRestoreOrientationHold()
                reset(reason: "pause-and-suspend-restore-exhausted", preserveOrientationHold: true)
                return
            }
            returnPostStopRetryCount += 1
            DiagnosticsLogger.shared.playback("PiPState", "paused foreground restore retry=\(returnPostStopRetryCount) reason=\(reason) action=replay-surface")
            returnSurfaceReplayRequested = false
            returnRendererReady = false
            returnRendererRestoreInProgress = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in self?.pollReturnBarrier(attempt: 0) }
            return
        }
        if returnSystemStopped {
            guard returnPostStopRetryCount < 2 else {
                DiagnosticsLogger.shared.playback("PiPState", "return post-stop renderer unresolved reason=\(reason) retries=\(returnPostStopRetryCount) action=keep-source-host-bridge")
                return
            }
            returnPostStopRetryCount += 1
            returnSurfaceReplayRequested = false
            returnRendererReady = false
            returnRendererRestoreInProgress = false
            DiagnosticsLogger.shared.playback("PiPState", "return post-stop retry=\(returnPostStopRetryCount) reason=\(reason) sourceHost=kept")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in self?.pollReturnBarrier(attempt: 0) }
            return
        }
        pendingRestoreUICompletion?(false); pendingRestoreUICompletion = nil
        manualForegroundReturn = false
        returnRendererReady = false
        returnRendererRestoreInProgress = false
        returnActualPosition = nil
        if controller?.isPictureInPictureActive == true {
            behavior.presentation = .active
            behavior.exitIntent = .none
            DiagnosticsLogger.shared.playback("PiPState", "return cancelled reason=\(reason) action=keep-pip")
        }
    }

    private func scheduleReturnVisualHandoffAfterSystemStop() {
        guard behavior.exitIntent == .returnToPlayer, returnSystemStopped, returnRendererReady, returnHandoffDisplayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(handleReturnHandoffDisplayLink(_:)))
        returnHandoffDisplayLink = link
        link.add(to: .main, forMode: .common)
        DiagnosticsLogger.shared.playback("PiPState", "return final handoff scheduled trigger=next-display-link sourceHost=kept presentationHeld=\(PlayerSurfacePresentationGate.shared.isHolding)")
    }

    @objc private func handleReturnHandoffDisplayLink(_ link: CADisplayLink) {
        link.invalidate()
        if returnHandoffDisplayLink === link { returnHandoffDisplayLink = nil }
        guard behavior.exitIntent == .returnToPlayer, returnSystemStopped, returnRendererReady else { return }
        if let host = sourceHostView, host.alpha > 0.001 { UIView.performWithoutAnimation { host.alpha = 0 } }
        DiagnosticsLogger.shared.playback("PiPState", "return final handoff display-link fired sourceHost=hidden action=arm-presentation-release")
        AppOrientationCoordinator.shared.armPictureInPicturePresentationRelease()
        pollReturnBarrier(attempt: 0)
    }

    private func completeReturnAfterSystemStop() {
        guard behavior.exitIntent == .returnToPlayer else { return }
        guard returnRendererReady, !PlayerSurfacePresentationGate.shared.isHolding else {
            DiagnosticsLogger.shared.playback("PiPState", "return completion deferred rendererReady=\(returnRendererReady) presentationHeld=\(PlayerSurfacePresentationGate.shared.isHolding) sourceHost=kept")
            return
        }
        returnPollWorkItem?.cancel(); returnPollWorkItem = nil
        pendingRestoreUICompletion?(true)
        pendingRestoreUICompletion = nil
        pipeline?.stop()
        standbyPipeline?.stop()
        sourceHostView?.removeFromSuperview()
        sourceHostView = nil
        AppOrientationCoordinator.shared.endPictureInPictureRestoreOrientationHold()
        DiagnosticsLogger.shared.playback("PiPState", "return complete rendererActual=\(returnActualPosition.map { String(format: "%.3f", $0) } ?? "unknown") sourceHost=removed")
        reset(reason: "return-complete", preserveOrientationHold: true)
    }

    private func pauseAndSuspendFromPiP(reason: String) {
        guard behavior.exitIntent != .pauseAndSuspend else { return }
        behavior.exitIntent = .pauseAndSuspend
        behavior.presentation = .closing
        pendingSystemPauseWorkItem?.cancel(); pendingSystemPauseWorkItem = nil
        cancelSeekTransaction(reason: "pause-and-suspend")
        if behavior.playback != .paused { applyPlaybackState(.paused, reason: "pip-close") }
        pipeline?.setPaused(true)
        standbyPipeline?.setPaused(true)
        clock.setPlaying(false)
        syncTimebaseToClock()
        DiagnosticsLogger.shared.playback("PiPState", "pause-and-suspend committed reason=\(reason) playback=paused playerSession=preserved embyStopped=false")
    }

    private func finalizePauseAndSuspendAfterSystemStop() {
        pipeline?.stop(); pipeline = nil
        standbyPipeline?.stop(); standbyPipeline = nil
        displayLayer?.flushAndRemoveImage(); displayLayer?.controlTimebase = nil
        displayLayer = nil; controlTimebase = nil
        sourceHostView?.removeFromSuperview(); sourceHostView = nil
        possibleObservation = nil
        controller?.delegate = nil; controller = nil
        if let seekLandingProvider {
            seekLandingProvider.pictureInPictureSeekDispatchHandler = nil
            seekLandingProvider.pictureInPictureSeekLandingHandler = nil
        }
        seekLandingProvider = nil
        behavior.presentation = .backgroundPaused
        onPossibleChanged?(AVPictureInPictureController.isPictureInPictureSupported())
        DiagnosticsLogger.shared.playback("PiPState", "pause-and-suspend system-stopped appState=\(UIApplication.shared.applicationState.rawValue) playback=paused rendererSuspended=\(inlineRendererSuspended) playerSession=preserved")
    }

    private func beginPausedForegroundRestore() {
        guard behavior.exitIntent == .pauseAndSuspend, behavior.presentation == .backgroundPaused else { return }
        behavior.presentation = .returning
        returnRendererReady = false
        returnRendererRestoreInProgress = false
        returnActualPosition = nil
        returnSystemStopped = true
        returnSurfaceReplayRequested = false
        returnPostStopRetryCount = 0
        AppOrientationCoordinator.shared.preparePictureInPictureRestoreDestination()
        DiagnosticsLogger.shared.playback("PiPState", "paused foreground restore begin target=\(String(format: "%.3f", playbackController?.snapshot.position ?? 0)) authority=mpv-snapshot playback=paused")
        pollReturnBarrier(attempt: 0)
    }

    private func completePausedForegroundRestore() {
        guard behavior.exitIntent == .pauseAndSuspend, returnRendererReady, !PlayerSurfacePresentationGate.shared.isHolding else { return }
        AppOrientationCoordinator.shared.endPictureInPictureRestoreOrientationHold()
        DiagnosticsLogger.shared.playback("PiPState", "paused foreground restore complete actual=\(returnActualPosition.map { String(format: "%.3f", $0) } ?? "unknown") playback=paused playerScreen=preserved")
        reset(reason: "pause-and-suspend-foreground-restored", preserveOrientationHold: true)
    }

    private func handlePipelineFailure(_ reason: String) {
        DiagnosticsLogger.shared.playback("PiPState", "pipeline failed reason=\(reason) presentation=\(behavior.presentation.rawValue)")
        if behavior.presentation == .active {
            behavior.exitIntent = .failureFallback
            behavior.presentation = .recovering
            if behavior.playback == .playing { applyPlaybackState(.paused, reason: "pipeline-failure") }
            controller?.stopPictureInPicture()
        } else if behavior.presentation == .preparing || behavior.presentation == .starting {
            failAndRecover(reason: reason)
        }
    }

    private func failAndRecover(reason: String) {
        behavior.exitIntent = .failureFallback
        pendingRestoreUICompletion?(false); pendingRestoreUICompletion = nil
        if controller?.isPictureInPictureActive == true { behavior.presentation = .recovering; controller?.stopPictureInPicture(); return }
        reset(reason: "failure-\(reason)")
    }

    private func beginFailureFallbackAfterStop() {
        guard behavior.exitIntent == .failureFallback else { return }
        let target = playbackController?.snapshot.position ?? clock.position()
        restoreInlineRendererWhenForeground(targetPosition: target) { [weak self] _, _ in self?.reset(reason: "failure-fallback") }
    }

    private func applyPlaybackState(_ requested: PlayerPiPBehaviorState.PlaybackState, reason: String) {
        guard requested != .stopped, behavior.playback != .stopped, let playbackController else { return }
        behavior.playback = requested
        let shouldPlay = requested == .playing
        clock.setPlaying(shouldPlay)
        if playbackController.playbackControlIsPlaying != shouldPlay { playbackController.togglePlayPause() }
        pipeline?.setPaused(shouldPlay ? false : true)
        stagingContext?.pipeline.setPaused(true)
        syncTimebaseToClock()
        controller?.invalidatePlaybackState()
        DiagnosticsLogger.shared.playback("PiPState", "playback state=\(requested.rawValue) reason=\(reason) clock=\(String(format: "%.3f", clock.position())) seekActive=\(behavior.seek.isActive)")
    }

    private func syncTimebase(_ timebase: CMTimebase, to position: Double, playing: Bool) {
        CMTimebaseSetTime(timebase, time: CMTime(seconds: max(0, position), preferredTimescale: 60000))
        CMTimebaseSetRate(timebase, rate: playing ? 1 : 0)
    }

    private func syncTimebaseToClock() {
        guard let timebase = controlTimebase else { return }
        syncTimebase(timebase, to: clock.position(), playing: behavior.playback == .playing)
    }

    private func beginSeek(delta: Double) {
        guard let playbackController else { return }
        cancelSeekTransaction(reason: "superseded")
        pendingSystemPauseWorkItem?.cancel(); pendingSystemPauseWorkItem = nil
        seekToken &+= 1
        let token = seekToken
        activeSeekToken = token
        activeSeekStartedPosition = playbackController.snapshot.position
        playbackController.seek(by: delta)
        activeSeekRequestedTarget = playbackController.displayedPosition
        behavior.seek = .waitingForLanding(token: token, suppressPauseUntil: CACurrentMediaTime() + 0.04)
        DiagnosticsLogger.shared.playback("PiPSeek", "begin token=\(token) delta=\(String(format: "%.3f", delta)) engineStart=\(String(format: "%.3f", activeSeekStartedPosition ?? 0)) requested=\(activeSeekRequestedTarget.map { String(format: "%.3f", $0) } ?? "unknown") policy=visual-continues")
        if seekLandingProvider == nil { scheduleFallbackSeekLanding(token: token, attempt: 0) }
    }

    private func handleEngineSeekDispatch(_ info: PlayerPiPSeekDispatchInfo) {
        guard case .waitingForLanding(let token, _) = behavior.seek, token == activeSeekToken, activeSession != nil else { return }
        if let requested = activeSeekRequestedTarget, abs(requested - info.requestedTarget) > 0.6 {
            DiagnosticsLogger.shared.playback("PiPSeek", "dispatch ignored token=\(token) requestedMismatch local=\(String(format: "%.3f", requested)) engine=\(String(format: "%.3f", info.requestedTarget))")
            return
        }
        let predicted = max(0, info.stagingTarget)
        prepareStandbyPipelineIfNeeded(startPosition: predicted)
        guard let stagingPipeline = standbyPipeline else {
            DiagnosticsLogger.shared.playback("PiPSeek", "staging unavailable token=\(token) action=authoritative-fallback")
            return
        }
        let context = SeekStagingContext(token: token, predictedTarget: predicted, pipeline: stagingPipeline)
        context.optimisticCommitEnabled = info.previousKeyframe != nil || abs(info.dispatchTarget - info.requestedTarget) > 0.001
        stagingContext = context
        stagingPipeline.onReady = { _ in }
        stagingPipeline.onFailure = { [weak self, weak context] reason in DispatchQueue.main.async {
            guard let self, let context, self.stagingContext === context else { return }
            DiagnosticsLogger.shared.playback("PiPSeek", "staging failed token=\(context.token) reason=\(reason)")
            if self.standbyPipeline === context.pipeline { self.standbyPipeline = nil }
            self.stagingContext = nil
        } }
        stagingPipeline.onSample = { [weak self, weak context] envelope in DispatchQueue.main.async {
            guard let self, let context, self.stagingContext === context, context.token == self.activeSeekToken else { return }
            context.samples.append(envelope)
            if context.samples.count > 90 { context.samples.removeFirst(context.samples.count - 90) }
            if envelope.displayable, context.firstDisplayablePTS == nil { context.firstDisplayablePTS = envelope.pts }
            if let first = context.firstDisplayablePTS, envelope.displayable, envelope.pts - first >= 0.45, !context.pausedAfterPreroll {
                context.pausedAfterPreroll = true
                context.pipeline.setPaused(true)
            }
            if case .waitingForLanding(let waitingToken, _) = self.behavior.seek, waitingToken == context.token { self.attemptOptimisticSeekCommit(context: context) }
            if case .waitingForVisualCommit(let waitingToken, let authoritative) = self.behavior.seek, waitingToken == context.token { self.attemptStagedSeekCommit(context: context, authoritative: authoritative) }
        } }
        context.generation = stagingPipeline.seek(to: predicted)
        stagingPipeline.setPaused(true)
        DiagnosticsLogger.shared.playback("PiPSeek", "staging begin token=\(token) seekID=\(info.seekID) requested=\(String(format: "%.3f", info.requestedTarget)) dispatch=\(String(format: "%.3f", info.dispatchTarget)) previous=\(info.previousKeyframe.map { String(format: "%.3f", $0) } ?? "none") predicted=\(String(format: "%.3f", predicted)) persistentStandby=true generation=\(context.generation) optimistic=\(context.optimisticCommitEnabled)")
    }

    @discardableResult
    private func attemptOptimisticSeekCommit(context: SeekStagingContext) -> Bool {
        guard context.optimisticCommitEnabled, !context.committedSpeculatively, stagingContext === context, context.token == activeSeekToken, let displayLayer, let first = context.firstDisplayablePTS else { return false }
        let samples = context.samples.filter { $0.generation == context.generation }
        guard !samples.isEmpty, samples.contains(where: { $0.displayable }) else { return false }

        displayLayer.flush()
        samples.forEach { displayLayer.enqueue($0.buffer) }
        clock.reset(position: first, playing: behavior.playback == .playing)
        syncTimebaseToClock()

        let previousActive = pipeline
        previousActive?.setPaused(true)
        pipeline = context.pipeline
        standbyPipeline = previousActive
        activeGeneration = context.generation
        bindActivePipeline(context.pipeline)
        context.pipeline.setPaused(behavior.playback != .playing)
        context.committedSpeculatively = true
        context.speculativePTS = first
        controller?.invalidatePlaybackState()
        DiagnosticsLogger.shared.playback("PiPSeek", "optimistic visual commit token=\(context.token) predicted=\(String(format: "%.3f", context.predictedTarget)) first=\(String(format: "%.3f", first)) bufferedSamples=\(samples.count) authority=pending-mpv-landing switch=early")
        return true
    }

    private func handleEngineSeekLanding(_ result: SeekResult) {
        guard case .waitingForLanding(let token, _) = behavior.seek, token == activeSeekToken else { return }
        seekFallbackWorkItem?.cancel(); seekFallbackWorkItem = nil
        let authoritative = max(0, result.actualPosition ?? result.target)
        activeSeekLandingHostTime = CACurrentMediaTime()
        if let context = stagingContext, context.token == token, context.committedSpeculatively, let speculative = context.speculativePTS {
            let delta = speculative - authoritative
            DiagnosticsLogger.shared.playback("PiPSeek", "landing validate token=\(token) requested=\(String(format: "%.3f", result.target)) actual=\(String(format: "%.3f", authoritative)) speculative=\(String(format: "%.3f", speculative)) delta=\(String(format: "%.3f", delta)) completionMs=\(String(format: "%.1f", result.completionLatencyMs))")
            if abs(delta) <= 0.45 {
                clock.reset(position: authoritative, playing: behavior.playback == .playing)
                syncTimebaseToClock()
                stagingContext = nil
                finishSeekSettlement(token: token, authoritative: authoritative, source: "optimistic-validated")
                return
            }
            stagingContext = nil
            behavior.seek = .waitingForVisualCommit(token: token, authoritative: authoritative)
            beginActivePipelineFallbackSeek(token: token, authoritative: authoritative)
            return
        }

        behavior.seek = .waitingForVisualCommit(token: token, authoritative: authoritative)
        DiagnosticsLogger.shared.playback("PiPSeek", "landing token=\(token) requested=\(String(format: "%.3f", result.target)) actual=\(String(format: "%.3f", authoritative)) completionMs=\(String(format: "%.1f", result.completionLatencyMs)) action=await-ready-visual")
        if let context = stagingContext, context.token == token, attemptStagedSeekCommit(context: context, authoritative: authoritative) { return }
        beginActivePipelineFallbackSeek(token: token, authoritative: authoritative)
    }

    @discardableResult
    private func attemptStagedSeekCommit(context: SeekStagingContext, authoritative: Double) -> Bool {
        guard stagingContext === context, context.token == activeSeekToken, let first = context.firstDisplayablePTS else { return false }
        guard abs(first - authoritative) <= 0.45 else {
            DiagnosticsLogger.shared.playback("PiPSeek", "staging reject token=\(context.token) predictedFirst=\(String(format: "%.3f", first)) authoritative=\(String(format: "%.3f", authoritative)) delta=\(String(format: "%.3f", first - authoritative))")
            context.pipeline.setPaused(true); stagingContext = nil
            return false
        }
        let samples = context.samples
        guard samples.contains(where: { $0.displayable }) else { return false }
        commitSeekVisual(using: samples, authoritative: authoritative, promotedPipeline: context.pipeline, token: context.token, source: "speculative-staging")
        return true
    }

    private func beginActivePipelineFallbackSeek(token: UInt64, authoritative: Double) {
        guard token == activeSeekToken, let pipeline else { return }
        fallbackSeekSamples.removeAll(keepingCapacity: true)
        fallbackSeekGeneration = pipeline.seek(to: authoritative)
        DiagnosticsLogger.shared.playback("PiPSeek", "fallback preroll token=\(token) authoritative=\(String(format: "%.3f", authoritative)) generation=\(fallbackSeekGeneration ?? 0) policy=keep-old-display-queued-until-new-sample-ready")
    }

    private func commitSeekVisual(using samples: [PlayerPiPSamplePipeline.SampleEnvelope], authoritative: Double, promotedPipeline: PlayerPiPSamplePipeline?, token: UInt64?, source: String) {
        guard let token, token == activeSeekToken, let displayLayer else { return }
        let validSamples = samples.filter { promotedPipeline != nil ? $0.generation == stagingContext?.generation : $0.generation == fallbackSeekGeneration }
        guard !validSamples.isEmpty, validSamples.contains(where: { $0.displayable }) else { return }
        let landingHost = activeSeekLandingHostTime ?? CACurrentMediaTime()
        let elapsed = behavior.playback == .playing ? max(0, CACurrentMediaTime() - landingHost) : 0
        let newClockPosition = authoritative + elapsed

        displayLayer.flush()
        validSamples.forEach { displayLayer.enqueue($0.buffer) }
        clock.reset(position: newClockPosition, playing: behavior.playback == .playing)
        syncTimebaseToClock()

        if let promotedPipeline {
            let previousActive = pipeline
            previousActive?.setPaused(true)
            pipeline = promotedPipeline
            standbyPipeline = previousActive
            activeGeneration = stagingContext?.generation ?? 1
            bindActivePipeline(promotedPipeline)
            promotedPipeline.setPaused(behavior.playback != .playing)
            stagingContext = nil
            DiagnosticsLogger.shared.playback("PiPPipeline", "roles swapped activeGeneration=\(activeGeneration) standbyPersistent=\(standbyPipeline != nil)")
        } else {
            if let fallbackSeekGeneration { activeGeneration = fallbackSeekGeneration }
            fallbackSeekGeneration = nil
            fallbackSeekSamples.removeAll(keepingCapacity: true)
            pipeline?.setPaused(behavior.playback != .playing)
        }

        DiagnosticsLogger.shared.playback("PiPSeek", "visual commit token=\(token) source=\(source) authoritative=\(String(format: "%.3f", authoritative)) clock=\(String(format: "%.3f", newClockPosition)) bufferedSamples=\(validSamples.count) switch=atomic")
        finishSeekSettlement(token: token, authoritative: authoritative, source: source)
    }

    private func finishSeekSettlement(token: UInt64, authoritative: Double, source: String) {
        let settleUntil = CACurrentMediaTime() + 0.12
        behavior.seek = .settling(token: token, until: settleUntil)
        controller?.invalidatePlaybackState()
        seekSettleWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, case .settling(let currentToken, _) = self.behavior.seek, currentToken == token else { return }
            self.behavior.seek = .idle
            self.activeSeekToken = nil
            self.activeSeekRequestedTarget = nil
            self.activeSeekStartedPosition = nil
            self.activeSeekLandingHostTime = nil
            self.controller?.invalidatePlaybackState()
            DiagnosticsLogger.shared.playback("PiPSeek", "settled token=\(token) authoritative=\(String(format: "%.3f", authoritative)) source=\(source)")
        }
        seekSettleWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func currentAuthoritativeSeekPosition() -> Double? {
        if case .waitingForVisualCommit(_, let authoritative) = behavior.seek { return authoritative }
        return nil
    }

    private func scheduleFallbackSeekLanding(token: UInt64, attempt: Int) {
        seekFallbackWorkItem?.cancel()
        guard token == activeSeekToken, let playbackController, let start = activeSeekStartedPosition else { return }
        let current = playbackController.snapshot.position
        let moved = abs(current - start) > 0.25 && !playbackController.snapshot.isBuffering
        if moved || attempt >= 30 {
            let result = SeekResult(requestedAt: CACurrentMediaTime(), target: activeSeekRequestedTarget ?? current, actualPosition: current, bufferHit: false, completionLatencyMs: Double(attempt) * 20, measurement: "PiP fallback snapshot landing")
            handleEngineSeekLanding(result)
            return
        }
        let work = DispatchWorkItem { [weak self] in self?.scheduleFallbackSeekLanding(token: token, attempt: attempt + 1) }
        seekFallbackWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: work)
    }

    private func cancelSeekTransaction(reason: String) {
        seekFallbackWorkItem?.cancel(); seekFallbackWorkItem = nil
        seekSettleWorkItem?.cancel(); seekSettleWorkItem = nil
        if let stagingContext, !stagingContext.committedSpeculatively { stagingContext.pipeline.setPaused(true) }
        stagingContext = nil
        fallbackSeekGeneration = nil
        fallbackSeekSamples.removeAll(keepingCapacity: false)
        activeSeekToken = nil
        activeSeekRequestedTarget = nil
        activeSeekStartedPosition = nil
        activeSeekLandingHostTime = nil
        if behavior.seek.isActive { DiagnosticsLogger.shared.playback("PiPSeek", "cancel reason=\(reason)") }
        behavior.seek = .idle
    }

    private func reset(reason: String, preserveOrientationHold: Bool = false) {
        if !preserveOrientationHold { AppOrientationCoordinator.shared.endPictureInPictureRestoreOrientationHold() }
        startTimeout?.cancel(); startTimeout = nil
        startPoll?.cancel(); startPoll = nil
        pendingSystemPauseWorkItem?.cancel(); pendingSystemPauseWorkItem = nil
        returnPollWorkItem?.cancel(); returnPollWorkItem = nil
        returnHandoffDisplayLink?.invalidate(); returnHandoffDisplayLink = nil
        pendingRestoreUICompletion?(false); pendingRestoreUICompletion = nil
        pendingForegroundRendererRestore = nil
        cancelSeekTransaction(reason: "reset")
        possibleObservation = nil
        if let seekLandingProvider {
            seekLandingProvider.pictureInPictureSeekDispatchHandler = nil
            seekLandingProvider.pictureInPictureSeekLandingHandler = nil
        }
        seekLandingProvider = nil
        pipeline?.stop(); pipeline = nil
        standbyPipeline?.stop(); standbyPipeline = nil
        displayLayer?.flushAndRemoveImage(); displayLayer?.controlTimebase = nil
        displayLayer = nil; controlTimebase = nil
        sourceHostView?.removeFromSuperview(); sourceHostView = nil
        controller?.delegate = nil; controller = nil
        activeSession = nil; playbackController = nil; inlineRenderer = nil
        activeGeneration = 0
        firstVisibleSampleEnqueued = false; sourceSurfaceRevealed = false
        inlineRendererSuspended = false; rendererSuspending = false
        homeRequested = false
        returnRendererReady = false; returnRendererRestoreInProgress = false; returnActualPosition = nil
        returnSystemStopped = false; returnSurfaceReplayRequested = false; returnPostStopRetryCount = 0
        manualForegroundReturn = false
        behavior.reset()
        clock = PiPClock()
        onActiveChanged?(false)
        onPossibleChanged?(AVPictureInPictureController.isPictureInPictureSupported())
        DiagnosticsLogger.shared.playback("PiPState", "reset reason=\(reason)")
    }

    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DiagnosticsLogger.shared.playback("PiPState", "system-will-start playback=\(behavior.playback.rawValue)")
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        startTimeout?.cancel(); startTimeout = nil
        behavior.presentation = .active
        behavior.exitIntent = .none
        onActiveChanged?(true)
        AppOrientationCoordinator.shared.beginPictureInPictureRestoreOrientationHold()
        DiagnosticsLogger.shared.playback("PiPState", "system-started playback=\(behavior.playback.rawValue) orientationHold=true")
        prepareRendererForHomeAfterSystemStart()
    }

    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pendingSystemPauseWorkItem?.cancel(); pendingSystemPauseWorkItem = nil
        if behavior.exitIntent == .none { pauseAndSuspendFromPiP(reason: "system-close-without-restore") }
        DiagnosticsLogger.shared.playback("PiPState", "system-will-stop exit=\(behavior.exitIntent.rawValue) presentation=\(behavior.presentation.rawValue) playback=\(behavior.playback.rawValue)")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DiagnosticsLogger.shared.playback("PiPState", "system-stopped exit=\(behavior.exitIntent.rawValue) presentation=\(behavior.presentation.rawValue) playback=\(behavior.playback.rawValue)")
        onActiveChanged?(false)
        switch behavior.exitIntent {
        case .returnToPlayer:
            returnSystemStopped = true
            if returnRendererReady {
                DiagnosticsLogger.shared.playback("PiPState", "system-stopped rendererReady=true action=next-vsync-final-handoff sourceHost=kept")
                scheduleReturnVisualHandoffAfterSystemStop()
            } else {
                DiagnosticsLogger.shared.playback("PiPState", "system-stopped before renderer handoff sourceHost=kept rendererReady=false presentationHeld=\(PlayerSurfacePresentationGate.shared.isHolding)")
                pollReturnBarrier(attempt: 0)
            }
        case .pauseAndSuspend:
            finalizePauseAndSuspendAfterSystemStop()
        case .failureFallback:
            AppOrientationCoordinator.shared.endPictureInPictureRestoreOrientationHold()
            beginFailureFallbackAfterStop()
        case .detach:
            reset(reason: "detach-stopped")
        case .none:
            pauseAndSuspendFromPiP(reason: "did-stop-without-intent")
            finalizePauseAndSuspendAfterSystemStop()
        }
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        beginReturnToPlayer(reason: "system-restore-control", systemCompletion: completionHandler, manualForeground: false)
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        DiagnosticsLogger.shared.playback("PiPState", "system-start failed error=\(error.localizedDescription)")
        failAndRecover(reason: "system-start-failed")
    }

    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        guard let playbackController else { return .invalid }
        return CMTimeRange(start: .zero, duration: CMTime(seconds: max(0.001, playbackController.effectiveDuration), preferredTimescale: 60000))
    }

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool { behavior.playback != .playing }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        guard behavior.presentation == .active || behavior.presentation == .returning else { return }
        guard behavior.exitIntent == .none || behavior.exitIntent == .returnToPlayer else { return }
        if playing {
            pendingSystemPauseWorkItem?.cancel(); pendingSystemPauseWorkItem = nil
            applyPlaybackState(.playing, reason: "system-play")
            return
        }
        let now = CACurrentMediaTime()
        if behavior.seek.suppressesSystemPause(at: now) {
            DiagnosticsLogger.shared.playback("PiPState", "system-pause ignored reason=seek-transaction seek=\(String(describing: behavior.seek))")
            return
        }
        guard behavior.presentation == .active, behavior.exitIntent == .none else {
            DiagnosticsLogger.shared.playback("PiPState", "system-pause ignored reason=presentation-transition presentation=\(behavior.presentation.rawValue) exit=\(behavior.exitIntent.rawValue)")
            return
        }
        pendingSystemPauseWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.behavior.presentation == .active, self.behavior.exitIntent == .none, !self.behavior.seek.suppressesSystemPause(at: CACurrentMediaTime()) else { return }
            self.pendingSystemPauseWorkItem = nil
            self.applyPlaybackState(.paused, reason: "system-pause")
        }
        pendingSystemPauseWorkItem = work
        DispatchQueue.main.async(execute: work)
        DiagnosticsLogger.shared.playback("PiPState", "system-pause arbitration=next-main-turn")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        DiagnosticsLogger.shared.playback("PiPState", "render-size=\(newRenderSize.width)x\(newRenderSize.height) presentation=\(behavior.presentation.rawValue)")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping @Sendable () -> Void) {
        let delta = CMTimeGetSeconds(skipInterval)
        guard delta.isFinite, behavior.presentation == .active, behavior.exitIntent == .none, behavior.playback != .stopped else { completionHandler(); return }
        pendingSystemPauseWorkItem?.cancel(); pendingSystemPauseWorkItem = nil
        beginSeek(delta: delta)
        completionHandler()
        pictureInPictureController.invalidatePlaybackState()
        DiagnosticsLogger.shared.playback("PiPSeek", "system completion immediate delta=\(String(format: "%.3f", delta))")
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
