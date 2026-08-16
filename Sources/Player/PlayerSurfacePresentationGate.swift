import CoreGraphics
import Foundation
import UIKit

extension Notification.Name {
    static let onePlayerSurfacePresentationGateChanged = Notification.Name("OnePlayerSurfacePresentationGateChanged")
    static let onePlayerSurfacePresentationGateReleased = Notification.Name("OnePlayerSurfacePresentationGateReleased")
}

final class PlayerSurfacePresentationGate {
    static let shared = PlayerSurfacePresentationGate()

    private(set) var epoch: UInt64 = 0
    private(set) var isHolding = false
    private(set) var targetOrientation: UIInterfaceOrientation?
    private var foregroundReleaseArmed = false

    var requiresRendererAcknowledgement: Bool { isHolding && foregroundReleaseArmed }

    private init() {}

    func hold(targetOrientation: UIInterfaceOrientation?, reason: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        epoch &+= 1
        isHolding = true
        foregroundReleaseArmed = false
        self.targetOrientation = targetOrientation
        DiagnosticsLogger.shared.playback("PlayerPresentation", "hold epoch=\(epoch) target=\(targetOrientation?.rawValue ?? 0) reason=\(reason) releaseArmed=false")
        NotificationCenter.default.post(name: .onePlayerSurfacePresentationGateChanged, object: self)
    }

    func refresh(targetOrientation: UIInterfaceOrientation?, reason: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        if !isHolding {
            hold(targetOrientation: targetOrientation, reason: reason)
        }
        self.targetOrientation = targetOrientation
        foregroundReleaseArmed = true
        DiagnosticsLogger.shared.playback("PlayerPresentation", "refresh epoch=\(epoch) target=\(targetOrientation?.rawValue ?? 0) reason=\(reason) releaseArmed=true")
        NotificationCenter.default.post(name: .onePlayerSurfacePresentationGateChanged, object: self)
    }

    func rendererDidSettle(epoch settledEpoch: UInt64, targetBackingSize: CGSize, actualBackingSize: CGSize?) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard isHolding, foregroundReleaseArmed, settledEpoch == epoch else { return }
        let actualOrientation = activeWindowScene()?.interfaceOrientation
        if let targetOrientation, actualOrientation != targetOrientation {
            DiagnosticsLogger.shared.playback("PlayerPresentation", "keep-held epoch=\(epoch) targetOrientation=\(targetOrientation.rawValue) actualOrientation=\(actualOrientation?.rawValue ?? 0) targetBacking=\(Int(targetBackingSize.width))x\(Int(targetBackingSize.height))")
            return
        }
        isHolding = false
        foregroundReleaseArmed = false
        let actual = actualBackingSize ?? .zero
        DiagnosticsLogger.shared.playback("PlayerPresentation", "release epoch=\(epoch) orientation=\(actualOrientation?.rawValue ?? 0) targetBacking=\(Int(targetBackingSize.width))x\(Int(targetBackingSize.height)) actualBacking=\(Int(actual.width))x\(Int(actual.height))")
        NotificationCenter.default.post(name: .onePlayerSurfacePresentationGateChanged, object: self)
        NotificationCenter.default.post(name: .onePlayerSurfacePresentationGateReleased, object: self)
    }

    func passiveSurfaceDidSettle() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard isHolding, foregroundReleaseArmed else { return }
        let actualOrientation = activeWindowScene()?.interfaceOrientation
        if let targetOrientation, actualOrientation != targetOrientation { return }
        isHolding = false
        foregroundReleaseArmed = false
        DiagnosticsLogger.shared.playback("PlayerPresentation", "release epoch=\(epoch) orientation=\(actualOrientation?.rawValue ?? 0) renderer=passive")
        NotificationCenter.default.post(name: .onePlayerSurfacePresentationGateChanged, object: self)
        NotificationCenter.default.post(name: .onePlayerSurfacePresentationGateReleased, object: self)
    }

    func reset(reason: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard isHolding || targetOrientation != nil else { return }
        isHolding = false
        foregroundReleaseArmed = false
        targetOrientation = nil
        DiagnosticsLogger.shared.playback("PlayerPresentation", "reset epoch=\(epoch) reason=\(reason)")
        NotificationCenter.default.post(name: .onePlayerSurfacePresentationGateChanged, object: self)
    }

    private func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first(where: { $0.activationState == .foregroundInactive })
    }
}
