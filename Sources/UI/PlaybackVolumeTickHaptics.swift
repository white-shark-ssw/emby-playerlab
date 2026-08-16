import CoreHaptics
import Foundation

final class PlaybackVolumeTickHaptics {
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?

    func prepare() {
        guard supportsHaptics else { return }
        configureIfNeeded()
        do { try engine?.start() }
        catch { rebuildAndStart() }
    }

    func play() {
        guard supportsHaptics else { return }
        configureIfNeeded()
        do {
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            rebuildAndStart()
            try? player?.start(atTime: CHHapticTimeImmediate)
        }
    }

    private func configureIfNeeded() {
        guard engine == nil || player == nil else { return }
        do {
            let engine = try CHHapticEngine(audioSession: nil)
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = false
            engine.resetHandler = { [weak self] in
                DispatchQueue.main.async {
                    self?.engine = nil
                    self?.player = nil
                    self?.configureIfNeeded()
                    try? self?.engine?.start()
                }
            }

            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.18),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.82)
                ],
                relativeTime: 0,
                duration: 0.010
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            self.engine = engine
            self.player = try engine.makePlayer(with: pattern)
        } catch {
            engine = nil
            player = nil
        }
    }

    private func rebuildAndStart() {
        engine = nil
        player = nil
        configureIfNeeded()
        try? engine?.start()
    }
}
