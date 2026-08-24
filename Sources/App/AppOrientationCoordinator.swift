import Foundation
import UIKit

final class OnePlayerAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppOrientationCoordinator.shared.supportedMask
    }
}

final class AppOrientationCoordinator {
    static let shared = AppOrientationCoordinator()

    private(set) var supportedMask: UIInterfaceOrientationMask = .portrait
    private var playerModeActive = false
    private var pendingPlayerOrientation: UIInterfaceOrientation?
    private var backgroundPlayerOrientation: UIInterfaceOrientation?
    private var foregroundRestorePending = false
    private var pictureInPictureRestoreHoldActive = false
    private var lifecycleObservers: [NSObjectProtocol] = []

    var pictureInPictureRestoreTargetOrientation: UIInterfaceOrientation? { backgroundPlayerOrientation }

    private init() {
        lifecycleObservers.append(NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.captureAndLockPlayerOrientation() })
        lifecycleObservers.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in self?.holdBackgroundPlayerPresentation() })
        lifecycleObservers.append(NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in self?.preparePlayerOrientationBeforeForeground() })
        lifecycleObservers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.armForegroundPresentationRelease() })
        lifecycleObservers.append(NotificationCenter.default.addObserver(forName: .onePlayerSurfacePresentationGateReleased, object: nil, queue: .main) { [weak self] _ in self?.completeForegroundRestoreIfNeeded() })
    }

    func beginPlayerPresentation(source: ResolvedPlaybackSource) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !playerModeActive else { return }
        playerModeActive = true
        backgroundPlayerOrientation = nil
        foregroundRestorePending = false
        pictureInPictureRestoreHoldActive = false
        let target = preferredPlayerOrientation(for: source)
        pendingPlayerOrientation = target
        supportedMask = [.portrait, .landscapeLeft, .landscapeRight]
        invalidateSupportedOrientations()
        DiagnosticsLogger.shared.playback("AppOrientation", "player presentation armed target=\(target?.rawValue ?? 0) mask=\(supportedMask.rawValue); rotation deferred until player is visible")
    }

    func playerOrientationDidSettle() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard playerModeActive else { return }
        pendingPlayerOrientation = nil
        if let actual = activeWindowScene()?.interfaceOrientation, actual.isPortrait || actual.isLandscape { backgroundPlayerOrientation = actual }
        if foregroundRestorePending || PlayerSurfacePresentationGate.shared.isHolding {
            DiagnosticsLogger.shared.playback("AppOrientation", "player orientation settled while presentation held remembered=\(backgroundPlayerOrientation?.rawValue ?? 0) mask=\(supportedMask.rawValue)")
            return
        }
        supportedMask = [.portrait, .landscapeLeft, .landscapeRight]
        invalidateSupportedOrientations()
        DiagnosticsLogger.shared.playback("AppOrientation", "player orientation unlocked mask=\(supportedMask.rawValue) remembered=\(backgroundPlayerOrientation?.rawValue ?? 0)")
    }

    func beginPictureInPictureRestoreOrientationHold() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard playerModeActive else { return }
        let actual = activeWindowScene()?.interfaceOrientation
        let target = backgroundPlayerOrientation ?? actual
        guard let target, target.isPortrait || target.isLandscape else {
            DiagnosticsLogger.shared.playback("AppOrientation", "pip restore hold skipped target=unavailable")
            return
        }
        backgroundPlayerOrientation = target
        foregroundRestorePending = true
        pictureInPictureRestoreHoldActive = true
        supportedMask = orientationMask(for: target)
        invalidateSupportedOrientations()
        DiagnosticsLogger.shared.playback("AppOrientation", "pip restore hold begin target=\(target.rawValue) actual=\(actual?.rawValue ?? 0) lockedMask=\(supportedMask.rawValue) presentationHeld=\(PlayerSurfacePresentationGate.shared.isHolding)")
    }

    func preparePictureInPictureRestoreDestination() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard playerModeActive, let target = backgroundPlayerOrientation ?? activeWindowScene()?.interfaceOrientation, target.isPortrait || target.isLandscape else { return }
        backgroundPlayerOrientation = target
        foregroundRestorePending = true
        pictureInPictureRestoreHoldActive = true
        supportedMask = orientationMask(for: target)
        invalidateSupportedOrientations()
        request(target, reason: "pip-restore-destination")
        let size = activeWindowScene()?.windows.first(where: { $0.isKeyWindow })?.bounds.size ?? .zero
        DiagnosticsLogger.shared.playback("AppOrientation", "pip restore destination prepare target=\(target.rawValue) window=\(Int(size.width))x\(Int(size.height)) mask=\(supportedMask.rawValue)")
    }

    func endPictureInPictureRestoreOrientationHold() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard pictureInPictureRestoreHoldActive else { return }
        pictureInPictureRestoreHoldActive = false
        DiagnosticsLogger.shared.playback("AppOrientation", "pip restore hold end foregroundPending=\(foregroundRestorePending) presentationHeld=\(PlayerSurfacePresentationGate.shared.isHolding)")
        if foregroundRestorePending, !PlayerSurfacePresentationGate.shared.isHolding { completeForegroundRestoreIfNeeded() }
    }

    func restoreMainInterfaceOrientation() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard playerModeActive || supportedMask != .portrait else { return }
        playerModeActive = false
        pendingPlayerOrientation = nil
        backgroundPlayerOrientation = nil
        foregroundRestorePending = false
        pictureInPictureRestoreHoldActive = false
        PlayerSurfacePresentationGate.shared.reset(reason: "player-dismiss")
        supportedMask = .portrait
        invalidateSupportedOrientations()
        request(.portrait, reason: "player-dismiss")
    }

    func preferredPlayerOrientation(for source: ResolvedPlaybackSource) -> UIInterfaceOrientation? {
        let raw = UserDefaults.standard.string(forKey: PlayerPreferenceKeys.orientationPolicy) ?? PlaybackOrientationPolicy.adaptive.rawValue
        let policy = PlaybackOrientationPolicy(rawValue: raw) ?? .adaptive
        switch policy {
        case .landscape:
            return .landscapeRight
        case .portrait:
            return .portrait
        case .adaptive:
            guard let ratio = source.mediaSource.mediaStreams?.first(where: { $0.type?.caseInsensitiveCompare("Video") == .orderedSame })?.displayAspectRatio else { return nil }
            if ratio > 1.02 { return .landscapeRight }
            if ratio < 0.98 { return .portrait }
            return nil
        }
    }

    private func captureAndLockPlayerOrientation() {
        guard playerModeActive, let actual = activeWindowScene()?.interfaceOrientation, actual.isPortrait || actual.isLandscape else { return }
        backgroundPlayerOrientation = actual
        supportedMask = orientationMask(for: actual)
        invalidateSupportedOrientations()
        DiagnosticsLogger.shared.playback("AppOrientation", "inactive capture target=\(actual.rawValue) lockedMask=\(supportedMask.rawValue)")
    }

    private func holdBackgroundPlayerPresentation() {
        guard playerModeActive, let target = backgroundPlayerOrientation else { return }
        foregroundRestorePending = true
        supportedMask = orientationMask(for: target)
        PlayerSurfacePresentationGate.shared.hold(targetOrientation: target, reason: "background-entered")
        DiagnosticsLogger.shared.playback("AppOrientation", "background entered target=\(target.rawValue) lockedMask=\(supportedMask.rawValue) presentationHeld=true")
    }

    private func preparePlayerOrientationBeforeForeground() {
        guard playerModeActive, foregroundRestorePending, let target = backgroundPlayerOrientation else { return }
        supportedMask = orientationMask(for: target)
        invalidateSupportedOrientations()
        let actual = activeWindowScene()?.interfaceOrientation
        if pictureInPictureRestoreHoldActive {
            DiagnosticsLogger.shared.playback("AppOrientation", "foreground prepare target=\(target.rawValue) actual=\(actual?.rawValue ?? 0) lockedMask=\(supportedMask.rawValue) presentationHeld=\(PlayerSurfacePresentationGate.shared.isHolding) pipRestoreHold=true geometryRequest=deferred-to-restore-callback")
            return
        }
        DiagnosticsLogger.shared.playback("AppOrientation", "foreground prepare target=\(target.rawValue) actual=\(actual?.rawValue ?? 0) lockedMask=\(supportedMask.rawValue) presentationHeld=\(PlayerSurfacePresentationGate.shared.isHolding) pipRestoreHold=false")
        request(target, reason: "foreground-prepare")
    }

    private func armForegroundPresentationRelease() {
        guard playerModeActive, let target = backgroundPlayerOrientation else { return }
        if pictureInPictureRestoreHoldActive {
            supportedMask = orientationMask(for: target)
            invalidateSupportedOrientations()
            let actual = activeWindowScene()?.interfaceOrientation
            DiagnosticsLogger.shared.playback("AppOrientation", "foreground active held for pip restore target=\(target.rawValue) actual=\(actual?.rawValue ?? 0) lockedMask=\(supportedMask.rawValue) presentationHeld=\(PlayerSurfacePresentationGate.shared.isHolding) geometryRequest=deferred-to-restore-callback")
            return
        }
        if !foregroundRestorePending || !PlayerSurfacePresentationGate.shared.isHolding {
            foregroundRestorePending = false
            supportedMask = [.portrait, .landscapeLeft, .landscapeRight]
            invalidateSupportedOrientations()
            DiagnosticsLogger.shared.playback("AppOrientation", "active without background transition target=\(target.rawValue) unlockedMask=\(supportedMask.rawValue)")
            return
        }
        supportedMask = orientationMask(for: target)
        invalidateSupportedOrientations()
        PlayerSurfacePresentationGate.shared.refresh(targetOrientation: target, reason: "foreground-active")
        let actual = activeWindowScene()?.interfaceOrientation
        DiagnosticsLogger.shared.playback("AppOrientation", "foreground active target=\(target.rawValue) actual=\(actual?.rawValue ?? 0) lockedMask=\(supportedMask.rawValue) presentationHeld=true")
        if actual != target { request(target, reason: "foreground-active-retry") }
    }

    private func completeForegroundRestoreIfNeeded() {
        guard playerModeActive, foregroundRestorePending else { return }
        if pictureInPictureRestoreHoldActive {
            DiagnosticsLogger.shared.playback("AppOrientation", "foreground presentation release deferred reason=pip-restore-system-animation mask=\(supportedMask.rawValue)")
            return
        }
        foregroundRestorePending = false
        if let actual = activeWindowScene()?.interfaceOrientation, actual.isPortrait || actual.isLandscape { backgroundPlayerOrientation = actual }
        supportedMask = [.portrait, .landscapeLeft, .landscapeRight]
        invalidateSupportedOrientations()
        DiagnosticsLogger.shared.playback("AppOrientation", "foreground presentation settled actual=\(backgroundPlayerOrientation?.rawValue ?? 0) unlockedMask=\(supportedMask.rawValue)")
    }

    private func request(_ target: UIInterfaceOrientation, reason: String) {
        guard let scene = activeWindowScene() else {
            DiagnosticsLogger.shared.playback("AppOrientation", "request skipped reason=\(reason) scene=unavailable")
            return
        }
        let mask = orientationMask(for: target)
        if #available(iOS 16.0, *) {
            invalidateSupportedOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
                DiagnosticsLogger.shared.playback("AppOrientation", "request failed reason=\(reason) target=\(target.rawValue) error=\(error.localizedDescription)")
            }
        } else {
            UIDevice.current.setValue(target.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
        DiagnosticsLogger.shared.playback("AppOrientation", "request reason=\(reason) target=\(target.rawValue) mask=\(mask.rawValue) actual=\(scene.interfaceOrientation.rawValue)")
    }

    private func invalidateSupportedOrientations() {
        guard #available(iOS 16.0, *) else { return }
        guard let root = activeWindowScene()?.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        invalidateSupportedOrientations(for: root)
    }

    @available(iOS 16.0, *)
    private func invalidateSupportedOrientations(for controller: UIViewController) {
        controller.setNeedsUpdateOfSupportedInterfaceOrientations()
        controller.children.forEach { invalidateSupportedOrientations(for: $0) }
        if let presented = controller.presentedViewController { invalidateSupportedOrientations(for: presented) }
    }

    private func orientationMask(for orientation: UIInterfaceOrientation) -> UIInterfaceOrientationMask {
        switch orientation {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return .portrait
        }
    }

    private func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first(where: { $0.activationState == .foregroundInactive })
    }
}
