import Foundation
import UIKit

final class OnePlayerAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppOrientationCoordinator.shared.supportedMask
    }
}

@MainActor
final class AppOrientationCoordinator {
    static let shared = AppOrientationCoordinator()

    private(set) var supportedMask: UIInterfaceOrientationMask = .portrait
    private var playerModeActive = false

    private init() {}

    func prepareForPlayerPresentation(source: ResolvedPlaybackSource) async {
        let target = preferredPlayerOrientation(for: source)
        if let target {
            supportedMask = orientationMask(for: target)
            invalidateSupportedOrientations()
            await requestAndWait(for: target, reason: "pre-presentation")
        }
        playerModeActive = true
        supportedMask = [.portrait, .landscapeLeft, .landscapeRight]
        invalidateSupportedOrientations()
    }

    func playerDidAppear() {
        playerModeActive = true
        supportedMask = [.portrait, .landscapeLeft, .landscapeRight]
        invalidateSupportedOrientations()
    }

    func restoreMainInterfaceOrientation() {
        guard playerModeActive || supportedMask != .portrait else { return }
        playerModeActive = false
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

    private func requestAndWait(for target: UIInterfaceOrientation, reason: String) async {
        guard let scene = activeWindowScene() else {
            DiagnosticsLogger.shared.playback("AppOrientation", "prepare skipped reason=\(reason) scene=unavailable")
            return
        }
        if scene.interfaceOrientation == target {
            DiagnosticsLogger.shared.playback("AppOrientation", "prepared reason=\(reason) target=\(target.rawValue) actual=\(scene.interfaceOrientation.rawValue) attempts=0")
            return
        }

        request(target, reason: reason)
        var attempt = 0
        while attempt < 30 {
            try? await Task.sleep(nanoseconds: 40_000_000)
            guard !Task.isCancelled else { return }
            if scene.interfaceOrientation == target {
                DiagnosticsLogger.shared.playback("AppOrientation", "prepared reason=\(reason) target=\(target.rawValue) actual=\(scene.interfaceOrientation.rawValue) attempts=\(attempt + 1)")
                return
            }
            attempt += 1
            if attempt == 8 || attempt == 18 { request(target, reason: "\(reason)-retry\(attempt)") }
        }
        DiagnosticsLogger.shared.playback("AppOrientation", "prepare timeout reason=\(reason) target=\(target.rawValue) actual=\(scene.interfaceOrientation.rawValue)")
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
        DiagnosticsLogger.shared.playback("AppOrientation", "request reason=\(reason) target=\(target.rawValue) mask=\(mask.rawValue)")
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
