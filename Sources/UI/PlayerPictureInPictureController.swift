import AVFoundation
import AVKit
import Combine
import UIKit

@MainActor
final class PlayerPictureInPictureController: NSObject, ObservableObject, @preconcurrency AVPictureInPictureControllerDelegate {
    @Published private(set) var isPossible = AVPictureInPictureController.isPictureInPictureSupported()
    @Published private(set) var isActive = false

    private weak var playerLayer: AVPlayerLayer?
    private var controller: AVPictureInPictureController?
    private var possibleObservation: NSKeyValueObservation?
    private var pendingStart = false
    private var startAttemptIssued = false
    private var startTimeout: DispatchWorkItem?
    private var pendingFailure: (() -> Void)?
    private weak var bridgePlayerController: PlayerController?
    private var bridgeOrigin: PlayerEngineKind?
    private var bridgeGeneration = 0

    func attach(playerLayer: AVPlayerLayer) {
        if self.playerLayer === playerLayer {
            tryStartPendingIfReady()
            return
        }
        detachNativeController(keepPendingStart: true)
        self.playerLayer = playerLayer
        guard AVPictureInPictureController.isPictureInPictureSupported(), let pictureInPictureController = AVPictureInPictureController(playerLayer: playerLayer) else {
            isPossible = false
            failPendingStart(reason: "controller-create-failed")
            return
        }
        pictureInPictureController.delegate = self
        if #available(iOS 14.2, *) { pictureInPictureController.canStartPictureInPictureAutomaticallyFromInline = true }
        controller = pictureInPictureController
        observePossible(pictureInPictureController)
        DiagnosticsLogger.shared.playback("PiP", "native playerLayer attached possible=\(pictureInPictureController.isPictureInPicturePossible)")
        tryStartPendingIfReady()
    }

    func toggle(using playerController: PlayerController) {
        if controller?.isPictureInPictureActive == true {
            controller?.stopPictureInPicture()
            return
        }
        guard !pendingStart, bridgeOrigin == nil else { return }
        if playerController.avPlayer != nil {
            requestStartWhenPossible()
            return
        }

        bridgePlayerController = playerController
        bridgeOrigin = playerController.engineKind
        bridgeGeneration &+= 1
        let generation = bridgeGeneration
        let origin = playerController.engineKind
        DiagnosticsLogger.shared.playback("PiP", "bridge requested from=\(origin.title) position=\(String(format: "%.3f", playerController.snapshot.position))")
        requestStartWhenPossible(timeout: 5) { [weak self] in self?.restoreBridge(reason: "native-start-failed", generation: generation) }
        playerController.switchEngine(to: .transportAVPlayer, reason: "用户切换")
    }

    func requestStartWhenPossible(timeout: TimeInterval = 5, onFailure: (() -> Void)? = nil) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            isPossible = false
            onFailure?()
            return
        }
        if controller?.isPictureInPictureActive == true { return }
        cancelPendingStart(notifyFailure: false)
        pendingStart = true
        startAttemptIssued = false
        pendingFailure = onFailure
        isPossible = true
        let workItem = DispatchWorkItem { [weak self] in self?.failPendingStart(reason: "start-timeout") }
        startTimeout = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + max(1, timeout), execute: workItem)
        DiagnosticsLogger.shared.playback("PiP", "native start requested hasLayer=\(playerLayer != nil) hasController=\(controller != nil)")
        tryStartPendingIfReady()
    }

    func toggle() {
        if controller?.isPictureInPictureActive == true { controller?.stopPictureInPicture() }
        else { requestStartWhenPossible() }
    }

    func stopAndDetach() {
        bridgeGeneration &+= 1
        bridgeOrigin = nil
        bridgePlayerController = nil
        cancelPendingStart(notifyFailure: false)
        if controller?.isPictureInPictureActive == true { controller?.stopPictureInPicture() }
        detachNativeController(keepPendingStart: false)
        isPossible = AVPictureInPictureController.isPictureInPictureSupported()
        isActive = false
    }

    private func observePossible(_ pictureInPictureController: AVPictureInPictureController) {
        possibleObservation = pictureInPictureController.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] controller, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isPossible = controller.isPictureInPicturePossible || self.pendingStart || self.bridgeOrigin != nil
                self.tryStartPendingIfReady()
            }
        }
    }

    private func tryStartPendingIfReady() {
        guard pendingStart, !startAttemptIssued, let controller, controller.isPictureInPicturePossible else { return }
        startAttemptIssued = true
        DiagnosticsLogger.shared.playback("PiP", "native playerLayer ready; startPictureInPicture")
        controller.startPictureInPicture()
    }

    private func cancelPendingStart(notifyFailure: Bool) {
        startTimeout?.cancel()
        startTimeout = nil
        let failure = pendingFailure
        pendingFailure = nil
        pendingStart = false
        startAttemptIssued = false
        if notifyFailure { failure?() }
    }

    private func failPendingStart(reason: String) {
        guard pendingStart else { return }
        DiagnosticsLogger.shared.playback("PiP", "native start failed reason=\(reason) possible=\(controller?.isPictureInPicturePossible ?? false) hasLayer=\(playerLayer != nil)")
        cancelPendingStart(notifyFailure: true)
    }

    private func detachNativeController(keepPendingStart: Bool) {
        possibleObservation = nil
        controller?.delegate = nil
        controller = nil
        playerLayer = nil
        if !keepPendingStart { cancelPendingStart(notifyFailure: false) }
    }

    private func restoreBridge(reason: String, generation: Int? = nil) {
        if let generation, generation != bridgeGeneration { return }
        guard let origin = bridgeOrigin, let playerController = bridgePlayerController else { return }
        bridgeGeneration &+= 1
        bridgeOrigin = nil
        bridgePlayerController = nil
        cancelPendingStart(notifyFailure: false)
        detachNativeController(keepPendingStart: false)
        isActive = false
        isPossible = AVPictureInPictureController.isPictureInPictureSupported()
        let restoreGeneration = bridgeGeneration
        let restore: () -> Void = { [weak self, weak playerController] in
            guard let self, let playerController, self.bridgeGeneration == restoreGeneration else { return }
            guard playerController.engineKind == .transportAVPlayer else {
                DiagnosticsLogger.shared.playback("PiP", "bridge restore skipped current=\(playerController.engineKind.title) reason=\(reason)")
                return
            }
            DiagnosticsLogger.shared.playback("PiP", "bridge restore to=\(origin.title) reason=\(reason) position=\(String(format: "%.3f", playerController.snapshot.position))")
            playerController.switchEngine(to: origin, reason: "用户切换")
        }
        if playerController.engineKind == .transportAVPlayer { restore() }
        else { DispatchQueue.main.asyncAfter(deadline: .now() + 0.50, execute: restore) }
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        cancelPendingStart(notifyFailure: false)
        isActive = true
        isPossible = true
        DiagnosticsLogger.shared.playback("PiP", "started native-playerLayer=true bridgeOrigin=\(bridgeOrigin?.title ?? "none")")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isActive = false
        DiagnosticsLogger.shared.playback("PiP", "stopped native-playerLayer=true bridgeOrigin=\(bridgeOrigin?.title ?? "none")")
        restoreBridge(reason: "pip-stopped")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        isActive = false
        DiagnosticsLogger.shared.playback("PiP", "start failed error=\(error.localizedDescription) native-playerLayer=true")
        if pendingStart { failPendingStart(reason: "delegate-error") }
        else { restoreBridge(reason: "delegate-error") }
    }
}
