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

    private init() {}

    func beginPlayerPresentation(source: ResolvedPlaybackSource) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !playerModeActive else { return }
        playerModeActive = true
        let target = preferredPlayerOrientation(for: source)
        pendingPlayerOrientation = target
        supportedMask = target.map { orientationMask(for: $0) } ?? [.portrait, .landscapeLeft, .landscapeRight]
        invalidateSupportedOrientations()
        if let target { request(target, reason: "pre-presentation") }
        DiagnosticsLogger.shared.playback("AppOrientation", "player presentation prepared target=\(target?.rawValue ?? 0) mask=\(supportedMask.rawValue)")
    }

    func playerOrientationDidSettle() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard playerModeActive else { return }
        pendingPlayerOrientation = nil
        supportedMask = [.portrait, .landscapeLeft, .landscapeRight]
        invalidateSupportedOrientations()
        DiagnosticsLogger.shared.playback("AppOrientation", "player orientation unlocked mask=\(supportedMask.rawValue)")
    }

    func restoreMainInterfaceOrientation() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard playerModeActive || supportedMask != .portrait else { return }
        playerModeActive = false
        pendingPlayerOrientation = nil
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
