import Foundation

enum PlaybackRecoveryAction: Equatable {
    case recoverTransport(message: String)
    case switchEngine(PlayerEngineKind, reason: String)
    case reloadCurrent(reason: String)
    case wait(message: String)
}

struct PlaybackHealthAssessment: Equatable {
    let mediaBytesPerSecond: Double
    let minimumEffectiveBytesPerSecond: Double
    let minimumContiguousBytes: Int64
    let transportHealthy: Bool
    let reason: String
}

final class PlaybackOrchestrator {
    let automaticMode: Bool
    private let source: ResolvedPlaybackSource
    private(set) var currentKind: PlayerEngineKind
    private var errorKinds: Set<PlayerEngineKind> = []

    init(source: ResolvedPlaybackSource, preference: PlayerEnginePreference) {
        self.source = source
        self.automaticMode = preference.isAutomatic
        self.currentKind = preference.resolved(for: source.mediaSource)
    }

    func didSwitch(to kind: PlayerEngineKind) {
        currentKind = kind
    }

    func assessTransport(metrics: TransportMetricsSnapshot?) -> PlaybackHealthAssessment {
        let duration = max(source.mediaSource.durationSeconds ?? 0, 1)
        let size = Double(max(source.mediaSource.size ?? 0, 0))
        let mediaRate = size > 0 ? size / duration : 2 * 1_048_576
        let minimumSpeed = max(mediaRate * 3.0, 4 * 1_048_576)
        let minimumContiguous = Int64(max(mediaRate * 12.0, 16 * 1_048_576))

        guard let metrics else {
            return PlaybackHealthAssessment(
                mediaBytesPerSecond: mediaRate,
                minimumEffectiveBytesPerSecond: minimumSpeed,
                minimumContiguousBytes: minimumContiguous,
                transportHealthy: currentKind == .avPlayer || currentKind == .mpv,
                reason: "当前引擎没有共享传输指标"
            )
        }

        let enoughContiguous = metrics.contiguousCacheBytes >= minimumContiguous
        let enoughSpeed = metrics.currentDownloadBytesPerSecond >= minimumSpeed
        let noActiveDownloadNeeded = metrics.activeRequestCount == 0 && metrics.contiguousCacheBytes >= minimumContiguous / 2
        let healthy = enoughContiguous || enoughSpeed || noActiveDownloadNeeded
        let reason = "有效速度=\(Int(metrics.currentDownloadBytesPerSecond))B/s 连续=\(metrics.contiguousCacheBytes)B 阈值速度=\(Int(minimumSpeed))B/s 阈值连续=\(minimumContiguous)B"
        return PlaybackHealthAssessment(
            mediaBytesPerSecond: mediaRate,
            minimumEffectiveBytesPerSecond: minimumSpeed,
            minimumContiguousBytes: minimumContiguous,
            transportHealthy: healthy,
            reason: reason
        )
    }

    func actionForStall(
        kind: PlayerEngineKind,
        recoveryCount: Int,
        snapshot: PlayerSnapshot,
        metrics: TransportMetricsSnapshot?
    ) -> PlaybackRecoveryAction {
        let health = assessTransport(metrics: metrics)
        DiagnosticsLogger.shared.log(
            "Orchestrator",
            "stall engine=\(kind.title) count=\(recoveryCount) transportHealthy=\(health.transportHealthy) \(health.reason) waiting=\(snapshot.waitingReason ?? "none")"
        )

        guard automaticMode else {
            return .recoverTransport(message: "诊断固定引擎：执行当前引擎恢复")
        }

        if kind == .resourceLoaderAVPlayer || kind == .ksAVIO {
            if !health.transportHealthy {
                return .recoverTransport(message: "当前位置连续数据不足，优先重建按需窗口，不切换解码引擎")
            }
            if recoveryCount >= 2, let next = nextEngine(after: kind) {
                return .switchEngine(next, reason: "数据充足但 \(kind.title) 连续停滞")
            }
            return .recoverTransport(message: "数据基本充足，先执行一次当前引擎恢复")
        }

        if kind == .avPlayer, recoveryCount >= 2, let next = nextEngine(after: .resourceLoaderAVPlayer) {
            return .switchEngine(next, reason: "直连 AVPlayer 连续停滞")
        }

        if kind == .mpv {
            return .reloadCurrent(reason: "MPV 容错引擎停滞")
        }

        if kind == .transportAVPlayer {
            return .switchEngine(.resourceLoaderAVPlayer, reason: "旧版本机 HTTP 停滞，迁移到 ResourceLoader")
        }
        return .recoverTransport(message: "执行当前引擎恢复")
    }

    func actionForPrematureEOF(kind: PlayerEngineKind, reason: String) -> PlaybackRecoveryAction {
        guard automaticMode else { return .reloadCurrent(reason: reason) }
        if let next = nextEngine(after: kind) {
            return .switchEngine(next, reason: "疑似提前结束：\(reason)")
        }
        return .reloadCurrent(reason: reason)
    }

    func actionForEngineError(kind: PlayerEngineKind, message: String) -> PlaybackRecoveryAction? {
        guard automaticMode else { return nil }
        guard !errorKinds.contains(kind) else { return nil }
        errorKinds.insert(kind)
        if let next = nextEngine(after: kind) {
            return .switchEngine(next, reason: "\(kind.title) 错误：\(message)")
        }
        return nil
    }

    private func nextEngine(after kind: PlayerEngineKind) -> PlayerEngineKind? {
        switch kind {
        case .resourceLoaderAVPlayer, .avPlayer, .transportAVPlayer: return .ksAVIO
        case .ksAVIO: return .mpv
        case .mpv: return nil
        }
    }
}
