import Foundation

struct PlayerPiPBehaviorState: Equatable {
    enum PlaybackState: String { case playing, paused, stopped }
    enum PresentationState: String { case idle, preparing, starting, active, returning, closing, backgroundPaused, recovering }
    enum ExitIntent: String { case none, returnToPlayer, pauseAndSuspend, failureFallback, detach }
    enum SeekState: Equatable {
        case idle
        case waitingForLanding(token: UInt64, suppressPauseUntil: CFTimeInterval)
        case waitingForVisualCommit(token: UInt64, authoritative: Double)
        case settling(token: UInt64, until: CFTimeInterval)

        var isActive: Bool {
            switch self {
            case .idle: return false
            case .waitingForLanding, .waitingForVisualCommit, .settling: return true
            }
        }

        func suppressesSystemPause(at now: CFTimeInterval) -> Bool {
            switch self {
            case .idle: return false
            case .waitingForLanding(_, let until): return now < until
            case .waitingForVisualCommit: return true
            case .settling(_, let until): return now < until
            }
        }
    }

    var playback: PlaybackState = .playing
    var presentation: PresentationState = .idle
    var exitIntent: ExitIntent = .none
    var seek: SeekState = .idle

    mutating func beginSession(isPlaying: Bool) {
        playback = isPlaying ? .playing : .paused
        presentation = .preparing
        exitIntent = .none
        seek = .idle
    }

    mutating func reset() {
        playback = .playing
        presentation = .idle
        exitIntent = .none
        seek = .idle
    }
}
