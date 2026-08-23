import UIKit

@MainActor
final class PlayerPiPHomeCoordinator {
    @discardableResult
    func requestHome() -> Bool {
        let selector = NSSelectorFromString("suspend")
        let application = UIApplication.shared
        guard application.responds(to: selector) else {
            DiagnosticsLogger.shared.playback("PiPHome", "request unavailable selector=suspend")
            return false
        }
        DiagnosticsLogger.shared.playback("PiPHome", "request begin state=\(application.applicationState.rawValue)")
        _ = application.perform(selector)
        return true
    }
}
