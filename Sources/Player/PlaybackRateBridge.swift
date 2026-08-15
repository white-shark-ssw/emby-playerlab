import AVFoundation
import Foundation

extension AVPlayerEngine {
    func setPlaybackRate(_ rate: Double) {
        let clamped = Float(min(4, max(0.25, rate)))
        player.defaultRate = clamped
        if player.rate != 0 { player.rate = clamped }
    }
}

extension KTVAVPlayerEngine {
    func setPlaybackRate(_ rate: Double) {
        let clamped = Float(min(4, max(0.25, rate)))
        player.defaultRate = clamped
        if player.rate != 0 { player.rate = clamped }
    }
}

extension PlayerController {
    func setPlaybackRate(_ rate: Double) {
        let clamped = min(4, max(0.25, rate))
        engine.setPlaybackRate(clamped)
        DiagnosticsLogger.shared.playback("PlaybackRate", "engine=\(engineKind.title) rate=\(String(format: "%.2f", clamped)) playing=\(playbackControlIsPlaying)")
    }
}
