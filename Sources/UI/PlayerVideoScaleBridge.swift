import Foundation

@MainActor
extension PlayerController {
    func applyVideoScaleMode(_ mode: PlayerVideoScaleMode) {
        guard let engine = engine as? MPVPlayerEngine else { return }
        switch mode {
        case .fit, .source:
            engine.setVideoGeometry(panscan: 0, aspectOverride: nil)
        case .fill:
            engine.setVideoGeometry(panscan: 1, aspectOverride: nil)
        case .ratio16x9:
            engine.setVideoGeometry(panscan: 0, aspectOverride: "16:9")
        case .ratio4x3:
            engine.setVideoGeometry(panscan: 0, aspectOverride: "4:3")
        }
        DiagnosticsLogger.shared.playback("PlayerUI", "mpv picture mode=\(mode.rawValue)")
    }
}