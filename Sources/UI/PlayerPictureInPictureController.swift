import AVFoundation
import AVKit
import Combine

@MainActor
final class PlayerPictureInPictureController: ObservableObject {
    @Published private(set) var isPossible = AVPictureInPictureController.isPictureInPictureSupported()
    @Published private(set) var isActive = false
    @Published private(set) var closePlaybackGeneration: UInt64 = 0

    private let sessionCoordinator: PlayerPiPSessionCoordinator

    init() {
        let coordinator = PlayerPiPSessionCoordinator()
        sessionCoordinator = coordinator
        coordinator.onPossibleChanged = { [weak self] value in self?.isPossible = value }
        coordinator.onActiveChanged = { [weak self] value in self?.isActive = value }
        coordinator.onPlaybackClosureRequested = { [weak self] in self?.closePlaybackGeneration &+= 1 }
    }

    func attach(playerLayer: AVPlayerLayer) {
        _ = playerLayer
        DiagnosticsLogger.shared.playback("PiP", "AVPlayerLayer attach ignored policy=samplebuffer-only")
    }

    func toggle(using playbackController: PlayerController) { sessionCoordinator.toggle(using: playbackController) }
    func stopAndDetach() { sessionCoordinator.stopAndDetach() }
}
