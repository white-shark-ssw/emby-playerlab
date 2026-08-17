import Foundation

enum PlayerEngineKind: String, CaseIterable, Identifiable {
    // Legacy implementations remain internal unless explicitly exposed by
    // PlayerEnginePreference for an available build variant.
    case ktvAVPlayer
    case ksAVIO
    case resourceLoaderAVPlayer
    case transportAVPlayer
    case avPlayer
    case mpv

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ktvAVPlayer: return "旧 KTV AVPlayer"
        case .ksAVIO: return "KSPlayer KSME（实验）"
        case .resourceLoaderAVPlayer: return "智能 AVPlayer"
        case .transportAVPlayer: return "统一缓存 AVPlayer"
        case .avPlayer: return "直连 AVPlayer"
        case .mpv: return "MPV 兼容引擎"
        }
    }

    var automaticRank: Int {
        switch self {
        case .resourceLoaderAVPlayer: return 0
        case .mpv: return 1
        case .transportAVPlayer: return 2
        case .avPlayer: return 3
        case .ksAVIO: return 4
        case .ktvAVPlayer: return 100
        }
    }
}

enum PlayerEnginePreference: String, CaseIterable, Identifiable {
    case automatic
    case resourceLoaderAVPlayer
    case transportAVPlayer
    case avPlayer
    case mpv
    case ksAVIO

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "自动（推荐）"
        case .resourceLoaderAVPlayer: return "诊断：智能 AVPlayer"
        case .transportAVPlayer: return "统一缓存 AVPlayer"
        case .avPlayer: return "诊断：直连 AVPlayer"
        case .mpv: return "MPV 兼容引擎"
        case .ksAVIO: return "KSPlayer KSME（实验）"
        }
    }

    static var selectableCases: [PlayerEnginePreference] {
        var result: [PlayerEnginePreference] = [.automatic]
        #if canImport(Libmpv)
        result.append(.mpv)
        #endif
        #if canImport(KSPlayer)
        result.append(.ksAVIO)
        #endif
        result.append(contentsOf: [.resourceLoaderAVPlayer, .transportAVPlayer, .avPlayer])
        return result
    }

    static var automaticCompatibilityKind: PlayerEngineKind {
        #if canImport(Libmpv)
        return .mpv
        #elseif canImport(KSPlayer)
        return .ksAVIO
        #else
        return .resourceLoaderAVPlayer
        #endif
    }

    static func persisted(rawValue: String?) -> PlayerEnginePreference {
        let preference = rawValue.flatMap(PlayerEnginePreference.init(rawValue:)) ?? .automatic
        return selectableCases.contains(preference) ? preference : .automatic
    }

    var isAutomatic: Bool { self == .automatic }

    func resolved(for source: MediaSource) -> PlayerEngineKind {
        switch self {
        case .resourceLoaderAVPlayer: return .resourceLoaderAVPlayer
        case .transportAVPlayer: return .transportAVPlayer
        case .avPlayer: return .avPlayer
        case .mpv: return .mpv
        case .ksAVIO: return .ksAVIO
        case .automatic:
            let nativeContainers: Set<String> = ["mp4", "mov", "m4v"]
            let nativeVideo: Set<String> = ["h264", "hevc", "h265"]
            let nativeAudio: Set<String> = ["aac", "alac", "mp3", "ac3", "eac3"]
            let video = source.videoCodec?.lowercased() ?? ""
            let audio = source.audioCodec?.lowercased() ?? ""
            if nativeContainers.contains(source.normalizedContainer),
               video.isEmpty || nativeVideo.contains(video),
               audio.isEmpty || nativeAudio.contains(audio) {
                return .resourceLoaderAVPlayer
            }
            return Self.automaticCompatibilityKind
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
    var accessLogStalls = 0
    var droppedVideoFrames = 0
    var observedBitrate: Double = 0
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
    func setPlaybackRate(_ rate: Double)
    func seek(to seconds: Double, direction: SeekDirection)
    func reload(at seconds: Double)
    func recoverStall(position: Double, duration: Double)
    func transportMetrics() async -> TransportMetricsSnapshot?
    func stop()
}

extension PlayerEngine {
    func setPlaybackRate(_ rate: Double) {}
    func recoverStall(position: Double, duration: Double) {}
    func transportMetrics() async -> TransportMetricsSnapshot? { nil }
}

final class SuspendedPlayerEngine: PlayerEngine {
    let kind: PlayerEngineKind
    var onSnapshot: ((PlayerSnapshot) -> Void)?
    var onSeekCompleted: ((SeekResult) -> Void)?

    init(kind: PlayerEngineKind) { self.kind = kind }

    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double) {}
    func play() {}
    func pause() {}
    func seek(to seconds: Double, direction: SeekDirection) {}
    func reload(at seconds: Double) {}
    func stop() {}
}

enum SeekDirection {
    case forward
    case backward
    case absolute
}
