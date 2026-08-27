import AVFoundation
import Foundation

extension AVPlayerEngine {
    func setPlaybackRate(_ rate: Double) {
        guard player.rate != 0 else { return }
        player.rate = Float(min(8, max(0.15, rate)))
    }
}

extension KTVAVPlayerEngine {
    func setPlaybackRate(_ rate: Double) {
        guard player.rate != 0 else { return }
        player.rate = Float(min(8, max(0.15, rate)))
    }
}

extension PlayerController {
    var maxSupportedPlaybackRate: Double {
        #if canImport(AetherEngine)
        if let engine = engine as? AetherPlayerEngine { return engine.maxSupportedPlaybackRate }
        #endif
        return 8
    }

    func setPlaybackRate(_ rate: Double) {
        let clamped = min(maxSupportedPlaybackRate, max(0.15, rate))
        engine.setPlaybackRate(clamped)
        DiagnosticsLogger.shared.playback("PlaybackRate", "engine=\(engineKind.title) rate=\(String(format: "%.2f", clamped)) playing=\(playbackControlIsPlaying)")
    }
}
