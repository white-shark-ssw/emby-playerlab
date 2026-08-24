from pathlib import Path

def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    if old not in text:
        raise SystemExit(f"missing patch anchor in {path}: {old[:100]!r}")
    path.write_text(text.replace(old, new, 1))

pip = Path("Sources/UI/PlayerPiPSessionCoordinator.swift")
orientation = Path("Sources/App/AppOrientationCoordinator.swift")
identity = Path("Sources/Core/AppIdentity.swift")

replace_once(pip, """    private var pendingSeekAuthoritativePosition: Double?
    private var pendingSeekLandingHostTime: CFTimeInterval?
    private let homeCoordinator = PlayerPiPHomeCoordinator()
""", """    private var pendingSeekAuthoritativePosition: Double?
    private var pendingSeekLandingHostTime: CFTimeInterval?
    private var deferredSystemPauseWorkItem: DispatchWorkItem?
    private var pendingRestoreUICompletion: ((Bool) -> Void)?
    private var restoreDestinationPoll: DispatchWorkItem?
    private var restoreDestinationStableSamples = 0
    private var lastRestoreDestinationWindowSize: CGSize?
    private let homeCoordinator = PlayerPiPHomeCoordinator()
""")

replace_once(pip, """        state = .active
        onActiveChanged?(true)
        DiagnosticsLogger.shared.playback("PiPSession", "system-started engine=\\(playbackController?.engineKind.title ?? \"unknown\") appState=\\(UIApplication.shared.applicationState.rawValue) sourceLayerOwnedByHost=\\(displayLayer?.superlayer === sourceHostView?.layer)")
        requestHomeAfterSystemStart()
""", """        state = .active
        onActiveChanged?(true)
        AppOrientationCoordinator.shared.beginPictureInPictureRestoreOrientationHold()
        DiagnosticsLogger.shared.playback("PiPSession", "system-started engine=\\(playbackController?.engineKind.title ?? \"unknown\") appState=\\(UIApplication.shared.applicationState.rawValue) sourceLayerOwnedByHost=\\(displayLayer?.superlayer === sourceHostView?.layer) orientationHold=armed-before-home")
        requestHomeAfterSystemStart()
""")

replace_once(pip, """    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        state = .restoring
        restoreRequested = true
        systemPiPStopped = false
        rendererRestoreReady = false
        rendererRestoreActualPosition = nil
        rendererRestoreAttempt = 0
        let target = currentPiPClockPosition()
        logicalPiPPosition = target
        AppOrientationCoordinator.shared.beginPictureInPictureRestoreOrientationHold()
        DiagnosticsLogger.shared.playback("PiPSession", "restore-ui requested appState=\\(UIApplication.shared.applicationState.rawValue) target=\\(String(format: \"%.3f\", target)) policy=system-first-cover-until-fresh-frame orientationHold=until-system-didStop")
        completionHandler(true)
        beginRestoreHandoffIfPossible()
    }
""", """    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
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
        DiagnosticsLogger.shared.playback("PiPSession", "restore-ui requested appState=\\(UIApplication.shared.applicationState.rawValue) target=\\(String(format: \"%.3f\", target)) policy=wait-final-destination-geometry-before-system-expand orientationHold=armed-before-foreground")
        pollRestoreDestinationGeometry(attempt: 0)
        beginRestoreHandoffIfPossible()
    }
""")

replace_once(pip, """    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        guard let playbackController else { return }
        pipWantsPlayback = playing
        if playbackController.playbackControlIsPlaying != playing { playbackController.togglePlayPause() }
        let aligningPipeline = pendingSkipGeneration != nil
        pipeline?.setPaused(aligningPipeline ? true : !playing)
        if !aligningPipeline, let timebase = controlTimebase { CMTimebaseSetRate(timebase, rate: playing ? 1 : 0) }
        pictureInPictureController.invalidatePlaybackState()
        DiagnosticsLogger.shared.playback("PiPSession", "set-playing=\\(playing) logicalPosition=\\(String(format: \"%.3f\", logicalPiPPosition)) pendingSeek=\\(pendingSkipCompletion != nil) aligningPipeline=\\(aligningPipeline)")
    }
""", """    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        if playing {
            deferredSystemPauseWorkItem?.cancel(); deferredSystemPauseWorkItem = nil
            applyPiPPlayingState(true, controller: pictureInPictureController, reason: "system-play")
            return
        }
        guard pipWantsPlayback else {
            applyPiPPlayingState(false, controller: pictureInPictureController, reason: "system-pause-already-paused")
            return
        }
        deferredSystemPauseWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self, weak pictureInPictureController] in
            guard let self, let pictureInPictureController else { return }
            self.deferredSystemPauseWorkItem = nil
            self.applyPiPPlayingState(false, controller: pictureInPictureController, reason: "system-pause-committed")
        }
        deferredSystemPauseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: work)
        DiagnosticsLogger.shared.playback("PiPSession", "set-playing=false deferredMs=30 logicalPosition=\\(String(format: \"%.3f\", logicalPiPPosition)) classification=allow-immediate-skip-to-cancel")
    }

    private func applyPiPPlayingState(_ playing: Bool, controller pictureInPictureController: AVPictureInPictureController, reason: String) {
        guard let playbackController else { return }
        pipWantsPlayback = playing
        if playbackController.playbackControlIsPlaying != playing { playbackController.togglePlayPause() }
        let aligningPipeline = pendingSkipGeneration != nil
        pipeline?.setPaused(aligningPipeline ? true : !playing)
        if !aligningPipeline, let timebase = controlTimebase { CMTimebaseSetRate(timebase, rate: playing ? 1 : 0) }
        pictureInPictureController.invalidatePlaybackState()
        DiagnosticsLogger.shared.playback("PiPSession", "set-playing=\\(playing) reason=\\(reason) logicalPosition=\\(String(format: \"%.3f\", logicalPiPPosition)) pendingSeek=\\(pendingSkipCompletion != nil) aligningPipeline=\\(aligningPipeline)")
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
        if let targetOrientation {
            orientationReady = targetOrientation.isLandscape ? windowSize.width > windowSize.height : windowSize.height > windowSize.width
        } else {
            orientationReady = windowHasArea
        }
        let hostOrientationReady: Bool
        if let targetOrientation {
            hostOrientationReady = targetOrientation.isLandscape ? hostSize.width > hostSize.height : hostSize.height > hostSize.width
        } else {
            hostOrientationReady = hostHasArea
        }
        let windowStable = lastRestoreDestinationWindowSize.map { abs($0.width - windowSize.width) < 0.5 && abs($0.height - windowSize.height) < 0.5 } ?? false
        if UIApplication.shared.applicationState == .active, windowHasArea, hostHasArea, orientationReady, hostOrientationReady, windowStable {
            restoreDestinationStableSamples += 1
        } else {
            restoreDestinationStableSamples = 0
        }
        lastRestoreDestinationWindowSize = windowSize

        if restoreDestinationStableSamples >= 2 {
            finishRestoreUICompletion(reason: "final-geometry-stable", windowSize: windowSize, hostSize: hostSize)
            return
        }
        if attempt >= 75 {
            finishRestoreUICompletion(reason: "geometry-timeout-fallback", windowSize: windowSize, hostSize: hostSize)
            return
        }
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
        DiagnosticsLogger.shared.playback("PiPSession", "restore-ui destination-ready reason=\\(reason) window=\\(Int(windowSize.width))x\\(Int(windowSize.height)) host=\\(Int(hostSize.width))x\\(Int(hostSize.height)) action=system-expand-once")
        completion?(true)
    }
""")

replace_once(pip, """        let previousWasAligning = pendingSkipGeneration != nil
        pendingSkipCompletion?()
""", """        let previousWasAligning = pendingSkipGeneration != nil
        let suppressedTransientPause = deferredSystemPauseWorkItem != nil
        deferredSystemPauseWorkItem?.cancel(); deferredSystemPauseWorkItem = nil
        if suppressedTransientPause { DiagnosticsLogger.shared.playback("PiPSession", "system-pause suppressed reason=skip-callback-arrived playing=\\(pipWantsPlayback)") }
        pendingSkipCompletion?()
""")

replace_once(pip, """        seekFallbackWorkItem?.cancel(); seekFallbackWorkItem = nil
        pendingSkipCompletion?(); pendingSkipCompletion = nil; pendingSkipGeneration = nil
""", """        seekFallbackWorkItem?.cancel(); seekFallbackWorkItem = nil
        deferredSystemPauseWorkItem?.cancel(); deferredSystemPauseWorkItem = nil
        restoreDestinationPoll?.cancel(); restoreDestinationPoll = nil
        pendingRestoreUICompletion?(false); pendingRestoreUICompletion = nil
        restoreDestinationStableSamples = 0
        lastRestoreDestinationWindowSize = nil
        pendingSkipCompletion?(); pendingSkipCompletion = nil; pendingSkipGeneration = nil
""")

replace_once(orientation, """    private var pictureInPictureRestoreHoldActive = false
    private var lifecycleObservers: [NSObjectProtocol] = []

    private init() {
""", """    private var pictureInPictureRestoreHoldActive = false
    private var lifecycleObservers: [NSObjectProtocol] = []

    var pictureInPictureRestoreTargetOrientation: UIInterfaceOrientation? { backgroundPlayerOrientation }

    private init() {
""")

replace_once(orientation, """    func endPictureInPictureRestoreOrientationHold() {
""", """    func preparePictureInPictureRestoreDestination() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard playerModeActive, let target = backgroundPlayerOrientation ?? activeWindowScene()?.interfaceOrientation, target.isPortrait || target.isLandscape else { return }
        backgroundPlayerOrientation = target
        foregroundRestorePending = true
        pictureInPictureRestoreHoldActive = true
        supportedMask = orientationMask(for: target)
        invalidateSupportedOrientations()
        request(target, reason: "pip-restore-destination")
        let size = activeWindowScene()?.windows.first(where: { $0.isKeyWindow })?.bounds.size ?? .zero
        DiagnosticsLogger.shared.playback("AppOrientation", "pip restore destination prepare target=\\(target.rawValue) window=\\(Int(size.width))x\\(Int(size.height)) mask=\\(supportedMask.rawValue)")
    }

    func endPictureInPictureRestoreOrientationHold() {
""")

replace_once(orientation, """    private func preparePlayerOrientationBeforeForeground() {
        guard playerModeActive, foregroundRestorePending, let target = backgroundPlayerOrientation else { return }
        supportedMask = orientationMask(for: target)
        invalidateSupportedOrientations()
        let actual = activeWindowScene()?.interfaceOrientation
        DiagnosticsLogger.shared.playback("AppOrientation", "foreground prepare target=\\(target.rawValue) actual=\\(actual?.rawValue ?? 0) lockedMask=\\(supportedMask.rawValue) presentationHeld=\\(PlayerSurfacePresentationGate.shared.isHolding) pipRestoreHold=\\(pictureInPictureRestoreHoldActive)")
        request(target, reason: "foreground-prepare")
    }
""", """    private func preparePlayerOrientationBeforeForeground() {
        guard playerModeActive, foregroundRestorePending, let target = backgroundPlayerOrientation else { return }
        supportedMask = orientationMask(for: target)
        invalidateSupportedOrientations()
        let actual = activeWindowScene()?.interfaceOrientation
        if pictureInPictureRestoreHoldActive {
            DiagnosticsLogger.shared.playback("AppOrientation", "foreground prepare target=\\(target.rawValue) actual=\\(actual?.rawValue ?? 0) lockedMask=\\(supportedMask.rawValue) presentationHeld=\\(PlayerSurfacePresentationGate.shared.isHolding) pipRestoreHold=true geometryRequest=deferred-to-restore-callback")
            return
        }
        DiagnosticsLogger.shared.playback("AppOrientation", "foreground prepare target=\\(target.rawValue) actual=\\(actual?.rawValue ?? 0) lockedMask=\\(supportedMask.rawValue) presentationHeld=\\(PlayerSurfacePresentationGate.shared.isHolding) pipRestoreHold=false")
        request(target, reason: "foreground-prepare")
    }
""")

replace_once(orientation, """        if pictureInPictureRestoreHoldActive {
            supportedMask = orientationMask(for: target)
            invalidateSupportedOrientations()
            let actual = activeWindowScene()?.interfaceOrientation
            DiagnosticsLogger.shared.playback("AppOrientation", "foreground active held for pip restore target=\\(target.rawValue) actual=\\(actual?.rawValue ?? 0) lockedMask=\\(supportedMask.rawValue) presentationHeld=\\(PlayerSurfacePresentationGate.shared.isHolding)")
            if actual != target { request(target, reason: "foreground-active-pip-restore") }
            return
        }
""", """        if pictureInPictureRestoreHoldActive {
            supportedMask = orientationMask(for: target)
            invalidateSupportedOrientations()
            let actual = activeWindowScene()?.interfaceOrientation
            DiagnosticsLogger.shared.playback("AppOrientation", "foreground active held for pip restore target=\\(target.rawValue) actual=\\(actual?.rawValue ?? 0) lockedMask=\\(supportedMask.rawValue) presentationHeld=\\(PlayerSurfacePresentationGate.shared.isHolding) geometryRequest=deferred-to-restore-callback")
            return
        }
""")

replace_once(identity, 'static let sourceVersion = "0.13.94"', 'static let sourceVersion = "0.13.95"')
replace_once(identity, '?? "0.13.94"', '?? "0.13.95"')

Path("docs/changelog/CHANGELOG_v0_13_95_build162.md").write_text("""# OnePlayer 0.13.95 Build162

- PiP skip classifies AVKit's transient `setPlaying(false)` callback before `skipByInterval` and suppresses that synthetic pause when the skip callback arrives immediately, so MPV audio and the SampleBuffer visual timeline keep moving while the authoritative MPV seek lands.
- Genuine PiP pause remains supported: an unmatched pause callback commits after a 30 ms classification window; already-paused PiP seeks stay paused.
- PiP return arms the orientation hold before Home/background handoff instead of waiting for the restore callback.
- AVKit restore completion is delayed until the player window and PiP source host have reached the final target orientation and stable geometry for consecutive frames; only then is the system asked to expand PiP back into the inline destination.
- The restore path logs final window/host geometry and retains a bounded fallback so an abnormal orientation transition cannot strand system PiP.
- Build161 volume/brightness 1% deduplication remains unchanged.
- MPV native seek remains `absolute+keyframes`; UnifiedTransport, cache and STRM -> 302 -> 115 direct transport are unchanged.
- Deployment Target remains iOS 15.0; iOS 17.0 remains supported.
""")
