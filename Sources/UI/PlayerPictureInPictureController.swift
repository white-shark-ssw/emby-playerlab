import AVFoundation
import AVKit
import Combine

@MainActor
final class PlayerPictureInPictureController: NSObject, ObservableObject, @preconcurrency AVPictureInPictureControllerDelegate {
    @Published private(set) var isPossible = false
    @Published private(set) var isActive = false

    private weak var playerLayer: AVPlayerLayer?
    private var controller: AVPictureInPictureController?
    private var possibleObservation: NSKeyValueObservation?

    func attach(playerLayer: AVPlayerLayer) {
        guard self.playerLayer !== playerLayer else { return }
        stopAndDetach()
        self.playerLayer = playerLayer
        guard AVPictureInPictureController.isPictureInPictureSupported(),
              let pictureInPictureController = AVPictureInPictureController(playerLayer: playerLayer) else { return }

        pictureInPictureController.delegate = self
        if #available(iOS 14.2, *) { pictureInPictureController.canStartPictureInPictureAutomaticallyFromInline = true }
        possibleObservation = pictureInPictureController.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] controller, _ in
            DispatchQueue.main.async { self?.isPossible = controller.isPictureInPicturePossible }
        }
        controller = pictureInPictureController
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
