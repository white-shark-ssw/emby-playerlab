import Foundation

/// Owns the lifecycle of one premature-EOF incident.
///
/// A far-from-end EOF is never allowed to recursively rebuild the same engine. The first event
/// receives one in-place recovery attempt. A second EOF before real playback progress quarantines
/// the incident so the player stays responsive and the user can choose the compatibility engine.
struct PrematureEOFRecoveryCoordinator {
    enum Decision: Equatable {
        case recoverInPlace
        case waitForCurrentRecovery
        case quarantine
    }

    private enum State: Equatable {
        case idle
        case recovering(origin: Double)
        case quarantined(origin: Double)
    }

    private var state: State = .idle

    mutating func reset() { state = .idle }

    mutating func begin(position: Double) -> Decision {
        let current = max(0, position)
        switch state {
        case .idle:
            state = .recovering(origin: current)
            return .recoverInPlace
        case .recovering(let origin):
            if abs(current - origin) <= 2 {
                state = .quarantined(origin: current)
                return .quarantine
            }
            state = .recovering(origin: current)
            return .recoverInPlace
        case .quarantined:
            return .quarantine
        }
    }

    mutating func observe(snapshot: PlayerSnapshot) {
        guard case .recovering(let origin) = state else { return }
        guard !snapshot.didReachEnd, !snapshot.isBuffering, snapshot.position.isFinite else { return }
        if snapshot.position >= origin + 0.15 { state = .idle }
    }

    var isQuarantined: Bool {
        if case .quarantined = state { return true }
        return false
    }
}
