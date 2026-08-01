import Foundation

enum PlayerEngineKind: String, CaseIterable, Identifiable {
    case transportAVPlayer
    case avPlayer
    case mpv

    var id: String { rawValue }

    var title: String {
        switch self {
        case .transportAVPlayer: return "Transport AVPlayer"
        case .avPlayer: return "AVPlayer"
        case .mpv: return "MPV"
        }
    }
}

enum PlayerEnginePreference: String, CaseIterable, Identifiable {
    case automatic
    case transportAVPlayer
    case avPlayer
    case mpv

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "自动（MP4 使用传输层）"
        case .transportAVPlayer: return "强制 Transport AVPlayer"
        case .avPlayer: return "强制原生 AVPlayer"
        case .mpv: return "强制 MPV"
        }
    }

    func resolved(for source: MediaSource) -> PlayerEngineKind {
        switch self {
        case .transportAVPlayer:
            return .transportAVPlayer
        case .avPlayer:
            return .avPlayer
        case .mpv:
            return .mpv
        case .automatic:
            let nativeContainers: Set<String> = ["mp4", "mov", "m4v"]
            if nativeContainers.contains(source.normalizedContainer) {
                return .transportAVPlayer
            }
            let mpvContainers: Set<String> = ["mkv", "webm", "avi", "flv", "ts", "m2ts", "wmv"]
            return mpvContainers.contains(source.normalizedContainer) ? .mpv : .transportAVPlayer
        }
    }
}

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
    let actualPosition: Double?
    let bufferHit: Bool
    let completionLatencyMs: Double
    let measurement: String
}

protocol PlayerEngine: AnyObject {
    var kind: PlayerEngineKind { get }
    var onSnapshot: ((PlayerSnapshot) -> Void)? { get set }
    var onSeekCompleted: ((SeekResult) -> Void)? { get set }

    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double)
    func play()
    func pause()
    func seek(to seconds: Double, direction: SeekDirection)
    func reload(at seconds: Double)
    func stop()
}

enum SeekDirection {
    case forward
    case backward
    case absolute
}
