import Foundation

/// Separates demux byte dependencies from the authoritative rolling-cache playback head.
///
/// Engines/demuxers may jump between audio/video/index byte regions at high frequency. Those reads
/// must be served urgently, but they do not move the rolling cache by themselves. The cache head is
/// allowed to advance only when the engine's media clock is also making forward playback progress.
/// No time-to-byte ratio is used: media time is only an authority gate, while byte locations always
/// come from real reads.
struct PlaybackDemandCoordinator {
    enum Decision: Equatable {
        case hold
        case advance(offset: Int64)
        case promote(offset: Int64, reason: String)
    }

    private struct DependencySample {
        let date: Date
        let offset: Int64
    }

    private struct FarCandidate {
        var offset: Int64
        var confirmations: Int
        var lastAt: Date
    }

    private var dependencies: [DependencySample] = []
    private var lastPlaybackPosition: Double?
    private var farCandidate: FarCandidate?
    private let dependencyRetentionSeconds: TimeInterval = 1.5
    private let maximumDependencySamples = 256

    mutating func reset() {
        dependencies.removeAll(keepingCapacity: true)
        lastPlaybackPosition = nil
        farCandidate = nil
    }

    mutating func observeDependency(offset: Int64, now: Date = Date()) {
        guard offset >= 0 else { return }
        dependencies.append(DependencySample(date: now, offset: offset))
        prune(now: now)
        if dependencies.count > maximumDependencySamples { dependencies.removeFirst(dependencies.count - maximumDependencySamples) }
    }

    mutating func confirmPlaybackProgress(position: Double, isBuffering: Bool, activeCenter: Int64, nearDistance: Int64, now: Date = Date()) -> Decision {
        guard position.isFinite, position >= 0 else { return .hold }
        prune(now: now)

        guard let previousPosition = lastPlaybackPosition else {
            lastPlaybackPosition = position
            return .hold
        }
        if position < previousPosition - 0.35 {
            lastPlaybackPosition = position
            farCandidate = nil
            return .hold
        }
        guard !isBuffering, position - previousPosition >= 0.10 else { return .hold }
        lastPlaybackPosition = position

        guard let candidate = dependencies.map(\.offset).min(), candidate > activeCenter else {
            farCandidate = nil
            return .hold
        }

        let distance = candidate - activeCenter
        let nearLimit = max(8 * 1_048_576, nearDistance)
        if distance <= nearLimit {
            farCandidate = nil
            return .advance(offset: candidate)
        }

        let clusterTolerance = max(1 * 1_048_576, nearLimit / 2)
        if var current = farCandidate,
           now.timeIntervalSince(current.lastAt) <= 1.5,
           abs(candidate - current.offset) <= clusterTolerance {
            current.offset = min(current.offset, candidate)
            current.confirmations += 1
            current.lastAt = now
            farCandidate = current
        } else {
            farCandidate = FarCandidate(offset: candidate, confirmations: 1, lastAt: now)
        }

        guard let confirmed = farCandidate, confirmed.confirmations >= 3 else { return .hold }
        farCandidate = nil
        return .promote(offset: confirmed.offset, reason: "engine-clock-confirmed-byte-demand")
    }

    private mutating func prune(now: Date) {
        let cutoff = now.addingTimeInterval(-dependencyRetentionSeconds)
        dependencies.removeAll { $0.date < cutoff }
    }
}
