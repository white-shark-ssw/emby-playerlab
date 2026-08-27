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
    case aether

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ktvAVPlayer: return "旧 KTV AVPlayer"
        case .ksAVIO:
            #if MDK_LAB
            return "MDK高性能引擎"
            #else
            return "KSPlayer KSME（实验）"
            #endif
        case .resourceLoaderAVPlayer: return "智能 AVPlayer"
        case .transportAVPlayer: return "统一缓存 AVPlayer"
        case .avPlayer: return "直连 AVPlayer"
        case .mpv: return "MPV高兼容引擎"
        case .aether: return "Aether实验引擎"
        }
    }

    var automaticRank: Int {
        switch self {
        case .resourceLoaderAVPlayer: return 0
        case .mpv: return 1
        case .transportAVPlayer: return 2
        case .avPlayer: return 3
        case .ksAVIO: return 4
        case .aether: return 5
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
    case aether

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "自动（高性能优先）"
        case .resourceLoaderAVPlayer: return "诊断：智能 AVPlayer"
        case .transportAVPlayer: return "统一缓存 AVPlayer"
        case .avPlayer: return "诊断：直连 AVPlayer"
        case .mpv: return "MPV高兼容引擎"
        case .ksAVIO:
            #if MDK_LAB
            return "MDK高性能引擎"
            #else
            return "KSPlayer KSME（实验）"
            #endif
        case .aether: return "Aether实验引擎"
        }
    }

    static var selectableCases: [PlayerEnginePreference] {
        var result: [PlayerEnginePreference] = []
        #if canImport(Libmpv)
        result.append(.mpv)
        #endif
        #if canImport(AetherEngine)
        result.append(.aether)
        #endif
        #if MDK_LAB && canImport(KSPlayer)
        result.append(.ksAVIO)
        #endif
        return result
    }

    static var automaticCompatibilityKind: PlayerEngineKind {
        #if canImport(Libmpv)
        return .mpv
        #elseif MDK_LAB && canImport(KSPlayer)
        return .ksAVIO
        #elseif canImport(KSPlayer)
        return .ksAVIO
        #else
        return .resourceLoaderAVPlayer
        #endif
    }

    static var defaultPreference: PlayerEnginePreference {
        selectableCases.first ?? .mpv
    }

    static func persisted(rawValue: String?) -> PlayerEnginePreference {
        guard let preference = rawValue.flatMap(PlayerEnginePreference.init(rawValue:)), selectableCases.contains(preference) else { return defaultPreference }
        return preference
    }

    var isAutomatic: Bool { self == .automatic }

    func resolved(for source: MediaSource) -> PlayerEngineKind {
        switch self {
        case .resourceLoaderAVPlayer: return .resourceLoaderAVPlayer
        case .transportAVPlayer: return .transportAVPlayer
        case .avPlayer: return .avPlayer
        case .mpv: return .mpv
        case .ksAVIO: return .ksAVIO
        case .aether: return .aether
        case .automatic:
            #if MDK_LAB && canImport(KSPlayer)
            return .ksAVIO
            #elseif canImport(Libmpv)
            return .mpv
            #elseif canImport(KSPlayer)
            return .ksAVIO
            #else
            return .resourceLoaderAVPlayer
            #endif
        }
    }
}

struct PlayerSnapshot: Equatable {
    /// Engine playback clock. This is not proof that the frame is visible.
    var position: Double = 0
    /// Timestamp of the latest frame actually submitted to the renderer, when the engine can provide it.
    var renderedPosition: Double? = nil
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

struct PlaybackBufferState: Equatable {
    /// Engine-confirmed instantaneous playable media-time ranges.
    var livePlayableRanges: [ClosedRange<Double>] = []
    /// Session-persistent media-time ranges that were actually verified playable by the engine.
    /// These are historical playback facts, not a byte-to-time projection of the disk cache.
    var verifiedHistoryRanges: [ClosedRange<Double>] = []
    var isBuffering = false
    var waitingReason: String?
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
