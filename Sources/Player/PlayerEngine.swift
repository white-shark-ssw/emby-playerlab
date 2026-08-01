import Foundation

struct PlayerSnapshot: Equatable {
    var position: Double = 0
    var duration: Double = 0
    var bufferedRanges: [ClosedRange<Double>] = []
    var isPlaying = false
    var isBuffering = false
    var waitingReason: String?
    var errorMessage: String?
    var didReachEnd = false
}

struct SeekResult {
    let requestedAt: TimeInterval
    let target: Double
    let bufferHit: Bool
    let completionLatencyMs: Double
}

protocol PlayerEngine: AnyObject {
    var onSnapshot: ((PlayerSnapshot) -> Void)? { get set }
    var onSeekCompleted: ((SeekResult) -> Void)? { get set }

    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double)
    func play()
    func pause()
    func seek(to seconds: Double, direction: SeekDirection)
    func stop()
}

enum SeekDirection {
    case forward
    case backward
    case absolute
}
