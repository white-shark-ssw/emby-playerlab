import AVFoundation
import Foundation

extension AVPlayerEngine {
    func setPlaybackRate(_ rate: Double) {
        guard player.rate != 0 else { return }
        player.rate = Float(min(4, max(0.25, rate)))
    }
}

extension KTVAVPlayerEngine {
    func setPlaybackRate(_ rate: Double) {
        guard player.rate != 0 else { return }
        player.rate = Float(min(4, max(0.25, rate)))
    }
}

extension PlayerController {
    func setPlaybackRate(_ rate: Double) {
        let clamped = min(4, max(0.25, rate))
        engine.setPlaybackRate(clamped)
        DiagnosticsLogger.shared.playback("PlaybackRate", "engine=\(engineKind.title) rate=\(String(format: "%.2f", clamped)) playing=\(playbackControlIsPlaying)")
    }
}
