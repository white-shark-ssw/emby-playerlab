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

    init(source: ResolvedPlaybackSource, preference: PlayerEnginePreference) {
        self.source = source
        self.automaticMode = preference.isAutomatic
        if preference.isAutomatic, MediaCompatibilityStore.requiresFFmpeg(itemId: source.itemId) {
            self.currentKind = .ksAVIO
            DiagnosticsLogger.shared.log("Compatibility", "item=\(source.itemId) automaticEngine=KSPlayer-FFmpeg reason=stored-video-freeze")
        } else {
            self.currentKind = preference.resolved(for: source.mediaSource)
        }
    }

    func didSwitch(to kind: PlayerEngineKind) { currentKind = kind }

    func assessTransport(metrics: TransportMetricsSnapshot?) -> PlaybackHealthAssessment {
        let duration = max(source.mediaSource.durationSeconds ?? 0, 1)
        let size = Double(max(source.mediaSource.size ?? 0, 0))
        let mediaRate = size > 0 ? size / duration : 2 * 1_048_576
        let minimumSpeed = max(mediaRate * 1.5, 2 * 1_048_576)
        let minimumContiguous = Int64(max(mediaRate * 8.0, 12 * 1_048_576))

        guard let metrics else {
            return PlaybackHealthAssessment(
                mediaBytesPerSecond: mediaRate,
                minimumEffectiveBytesPerSecond: minimumSpeed,
                minimumContiguousBytes: minimumContiguous,
                transportHealthy: false,
                reason: "当前引擎没有可用传输指标"
            )
        }

        let enoughContiguous = metrics.contiguousCacheBytes >= minimumContiguous
        let enoughSpeed = metrics.currentDownloadBytesPerSecond >= minimumSpeed
        let activelyGrowing = metrics.activeRequestCount > 0 && metrics.currentDownloadBytesPerSecond > 0
        let healthy = enoughContiguous || enoughSpeed || activelyGrowing
        let reason = "有效速度=\(Int(metrics.currentDownloadBytesPerSecond))B/s 连续=\(metrics.contiguousCacheBytes)B 活动=\(metrics.activeRequestCount) 阈值速度=\(Int(minimumSpeed))B/s 阈值连续=\(minimumContiguous)B"
        return PlaybackHealthAssessment(
            mediaBytesPerSecond: mediaRate,
            minimumEffectiveBytesPerSecond: minimumSpeed,
            minimumContiguousBytes: minimumContiguous,
            transportHealthy: healthy,
            reason: reason
        )
    }

    func actionForStall(kind: PlayerEngineKind, recoveryCount: Int, snapshot: PlayerSnapshot, metrics: TransportMetricsSnapshot?) -> PlaybackRecoveryAction {
        let health = assessTransport(metrics: metrics)
        DiagnosticsLogger.shared.log(
            "Orchestrator",
            "stall engine=\(kind.title) count=\(recoveryCount) transportHealthy=\(health.transportHealthy) \(health.reason) waiting=\(snapshot.waitingReason ?? "none") runtimeSwitch=disabled"
        )

        if kind == .ktvAVPlayer {
            if let metrics, metrics.activeRequestCount > 0, metrics.currentDownloadBytesPerSecond > 0 {
                let speed = ByteCountFormatter.string(fromByteCount: Int64(metrics.currentDownloadBytesPerSecond), countStyle: .file)
                let cached = ByteCountFormatter.string(fromByteCount: metrics.cacheBytes, countStyle: .file)
                return .wait(message: "正在补充缓存 · \(speed)/s · 已缓存 \(cached)")
            }
            return .recoverTransport(message: "下载暂时没有推进，正在重新启动持续预取；不会切换播放引擎")
        }

        if kind == .resourceLoaderAVPlayer || kind == .ksAVIO || kind == .transportAVPlayer {
            if health.transportHealthy { return .wait(message: "数据正在补充，保持当前播放引擎等待恢复") }
            return .recoverTransport(message: "当前位置数据不足，重建当前传输窗口；不会切换播放引擎")
        }

        if kind == .avPlayer { return .wait(message: "AVPlayer 正在等待网络数据，不自动切换引擎") }
        return .reloadCurrent(reason: "当前引擎长时间未推进，尝试重载同一引擎")
    }

    func actionForPrematureEOF(kind: PlayerEngineKind, reason: String) -> PlaybackRecoveryAction {
        .reloadCurrent(reason: "疑似提前结束：\(reason)；保持当前引擎恢复")
    }

    func actionForEngineError(kind: PlayerEngineKind, message: String) -> PlaybackRecoveryAction? {
        DiagnosticsLogger.shared.log("Orchestrator", "engine error engine=\(kind.title) runtimeSwitch=disabled error=\(message)")
        return nil
    }
}
