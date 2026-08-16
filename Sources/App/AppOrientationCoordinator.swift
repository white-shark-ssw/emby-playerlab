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
    private var lifecycleObservers: [NSObjectProtocol] = []

    private init() {
        lifecycleObservers.append(NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.capturePlayerOrientationForBackground() })
        lifecycleObservers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.restorePlayerOrientationAfterForeground() })
    }

    func beginPlayerPresentation(source: ResolvedPlaybackSource) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !playerModeActive else { return }
        playerModeActive = true
        backgroundPlayerOrientation = nil
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
        supportedMask = [.portrait, .landscapeLeft, .landscapeRight]
        invalidateSupportedOrientations()
        DiagnosticsLogger.shared.playback("AppOrientation", "player orientation unlocked mask=\(supportedMask.rawValue) remembered=\(backgroundPlayerOrientation?.rawValue ?? 0)")
    }

    func restoreMainInterfaceOrientation() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard playerModeActive || supportedMask != .portrait else { return }
        playerModeActive = false
        pendingPlayerOrientation = nil
        backgroundPlayerOrientation = nil
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

    private func capturePlayerOrientationForBackground() {
        guard playerModeActive, let actual = activeWindowScene()?.interfaceOrientation, actual.isPortrait || actual.isLandscape else { return }
        backgroundPlayerOrientation = actual
        DiagnosticsLogger.shared.playback("AppOrientation", "background capture target=\(actual.rawValue)")
    }

    private func restorePlayerOrientationAfterForeground() {
        guard playerModeActive, let target = backgroundPlayerOrientation else { return }
        supportedMask = [.portrait, .landscapeLeft, .landscapeRight]
        invalidateSupportedOrientations()
        let actual = activeWindowScene()?.interfaceOrientation
        DiagnosticsLogger.shared.playback("AppOrientation", "foreground restore target=\(target.rawValue) actual=\(actual?.rawValue ?? 0)")
        request(target, reason: "foreground-restore")
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
