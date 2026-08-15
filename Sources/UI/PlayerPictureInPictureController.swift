import AVFoundation
import AVKit
import Combine

@MainActor
final class PlayerPictureInPictureController: NSObject, ObservableObject, AVPictureInPictureControllerDelegate {
    @Published private(set) var isPossible = false
    @Published private(set) var isActive = false

    private weak var playerLayer: AVPlayerLayer?
    private var controller: AVPictureInPictureController?
    private var possibleObservation: NSKeyValueObservation?

    func attach(playerLayer: AVPlayerLayer) {
        guard self.playerLayer !== playerLayer else { return }
        stopAndDetach()
        self.playerLayer = playerLayer
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }

        let controller = AVPictureInPictureController(playerLayer: playerLayer)
        controller.delegate = self
        if #available(iOS 14.2, *) { controller.canStartPictureInPictureAutomaticallyFromInline = true }
        possibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] controller, _ in
            DispatchQueue.main.async { self?.isPossible = controller.isPictureInPicturePossible }
        }
        self.controller = controller
    }

    func toggle() {
        guard let controller else { return }
        if controller.isPictureInPictureActive { controller.stopPictureInPicture() }
        else if controller.isPictureInPicturePossible { controller.startPictureInPicture() }
    }

    func stopAndDetach() {
        possibleObservation = nil
        if controller?.isPictureInPictureActive == true { controller?.stopPictureInPicture() }
        controller?.delegate = nil
        controller = nil
        playerLayer = nil
        isPossible = false
        isActive = false
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isActive = true
        DiagnosticsLogger.shared.playback("PiP", "started")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isActive = false
        DiagnosticsLogger.shared.playback("PiP", "stopped")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        isActive = false
        DiagnosticsLogger.shared.playback("PiP", "start failed error=\(error.localizedDescription)")
    }
}
