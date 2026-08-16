import Foundation

/// Converts raw byte reads from any playback engine into one stable active playback head.
///
/// The transport remains the owner of cache policy. Engines only report real byte demand; this
/// coordinator decides whether a distant read is a temporary parallel/demux head or sustained
/// playback that should move the rolling cache window.
struct PlaybackDemandCoordinator {
    enum Decision: Equatable {
        case nearHead
        case holdCandidate(samples: Int)
        case promote(offset: Int64, reason: String)
    }

    private struct Candidate {
        var firstAt: Date
        var lastAt: Date
        var firstOffset: Int64
        var lastOffset: Int64
        var samples: Int
    }

    private var candidate: Candidate?

    mutating func reset() { candidate = nil }

    mutating func observe(offset: Int64, activeCenter: Int64, nearDistance: Int64, starving: Bool, now: Date = Date()) -> Decision {
        guard offset >= 0 else { return .nearHead }
        let distance = offset >= activeCenter ? offset - activeCenter : activeCenter - offset
        guard offset > activeCenter, distance > nearDistance else {
            if let candidate, now.timeIntervalSince(candidate.lastAt) > 1.0 { self.candidate = nil }
            return .nearHead
        }

        let backwardTolerance: Int64 = 1 * 1_048_576
        let maximumForwardStep = max(32 * 1_048_576, nearDistance)
        if var current = candidate {
            let sampleGap = now.timeIntervalSince(current.lastAt)
            let monotonic = offset + backwardTolerance >= current.lastOffset
            let step = offset >= current.lastOffset ? offset - current.lastOffset : 0
            if sampleGap <= 1.0, monotonic, step <= maximumForwardStep {
                current.lastAt = now
                current.lastOffset = max(current.lastOffset, offset)
                current.samples += 1
                candidate = current
            } else {
                candidate = Candidate(firstAt: now, lastAt: now, firstOffset: offset, lastOffset: offset, samples: 1)
            }
        } else {
            candidate = Candidate(firstAt: now, lastAt: now, firstOffset: offset, lastOffset: offset, samples: 1)
        }

        guard let current = candidate else { return .holdCandidate(samples: 0) }
        let elapsed = now.timeIntervalSince(current.firstAt)
        let progress = max(0, current.lastOffset - current.firstOffset)
        let minimumSamples = starving ? 3 : 5
        let minimumElapsed: TimeInterval = starving ? 0.12 : 0.30
        let minimumProgress: Int64 = starving ? 0 : 256 * 1024
        guard current.samples >= minimumSamples, elapsed >= minimumElapsed, progress >= minimumProgress else {
            return .holdCandidate(samples: current.samples)
        }

        candidate = nil
        return .promote(offset: current.lastOffset, reason: starving ? "starvation-sustained-demand" : "sustained-monotonic-demand")
    }
}
