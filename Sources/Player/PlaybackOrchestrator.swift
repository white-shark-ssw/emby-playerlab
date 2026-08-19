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
        if preference.isAutomatic {
            let storedCompatibility = MediaCompatibilityStore.requiresCompatibilityEngine(itemId: source.itemId)
            if storedCompatibility {
                let compatibilityKind = PlayerEnginePreference.automaticCompatibilityKind
                self.currentKind = compatibilityKind
                DiagnosticsLogger.shared.log("Compatibility", "item=\(source.itemId) automaticProfile=\(compatibilityKind.title)+UnifiedTransportV3 reason=stored-media-compatibility")
            } else {
                self.currentKind = preference.resolved(for: source.mediaSource)
                DiagnosticsLogger.shared.log("Compatibility", "item=\(source.itemId) automaticProfile=\(currentKind.title)+UnifiedTransportV3 reason=high-performance-priority")
            }
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

        if kind == .resourceLoaderAVPlayer || kind == .transportAVPlayer || kind == .mpv || kind == .ksAVIO {
            let currentForward = snapshot.bufferedRanges.reduce(0.0) { result, range in
                guard range.lowerBound <= snapshot.position + 0.25, range.upperBound >= snapshot.position - 0.10 else { return result }
                return max(result, range.upperBound - snapshot.position)
            }
            if currentForward < 0.5 { return .recoverTransport(message: "当前位置可播缓存已耗尽，正在把下载优先级拉回当前画面；不会切换播放引擎") }
            if health.transportHealthy { return .wait(message: "数据正在补充，保持当前播放引擎等待恢复") }
            return .recoverTransport(message: "当前位置数据不足，重建当前传输窗口；不会切换播放引擎")
        }

        if kind == .avPlayer { return .wait(message: "AVPlayer 正在等待网络数据，不自动切换引擎") }
        return .reloadCurrent(reason: "当前引擎长时间未推进，尝试重载同一引擎")
    }

    func actionForPrematureEOF(kind: PlayerEngineKind, reason: String, snapshot: PlayerSnapshot, metrics: TransportMetricsSnapshot?) -> PlaybackRecoveryAction {
        let duration = max(snapshot.duration, source.mediaSource.durationSeconds ?? 0)
        let farFromEnd = duration > 0 && snapshot.position + max(3, duration * 0.005) < duration
        let health = assessTransport(metrics: metrics)
        let recentFailure = (metrics?.recentNetworkFailureAgeSeconds ?? .infinity) <= 8
        let belowMediaRate = (metrics?.currentDownloadBytesPerSecond ?? 0) > 0 && (metrics?.currentDownloadBytesPerSecond ?? 0) < health.mediaBytesPerSecond * 1.10
        let transportStarved = snapshot.isBuffering || recentFailure || belowMediaRate || !health.transportHealthy
        DiagnosticsLogger.shared.playback("Orchestrator", "prematureEOF engine=\(kind.title) farFromEnd=\(farFromEnd) transportStarved=\(transportStarved) recentFailure=\(recentFailure) failureAge=\(String(format: "%.2f", metrics?.recentNetworkFailureAgeSeconds ?? .infinity)) networkBps=\(Int(metrics?.currentDownloadBytesPerSecond ?? 0)) mediaBps=\(Int(health.mediaBytesPerSecond)) reason=\(reason)")
        let unifiedKinds: Set<PlayerEngineKind> = [.resourceLoaderAVPlayer, .transportAVPlayer, .mpv, .ksAVIO]
        if farFromEnd && unifiedKinds.contains(kind) {
            let detail = transportStarved ? "当前传输存在饥饿/失败" : "当前传输仍健康，按异常媒体 EOF 处理"
            return .recoverTransport(message: "提前 EOF：\(detail)；保持当前引擎原地恢复，不允许递归重建")
        }
        if farFromEnd && transportStarved { return .recoverTransport(message: "网络/缓存供给不足时出现提前 EOF，保持当前引擎恢复当前位置数据") }
        return .reloadCurrent(reason: "疑似提前结束：\(reason)；仅非 UnifiedTransport 引擎允许受控重载")
    }

    func actionForEngineError(kind: PlayerEngineKind, message: String) -> PlaybackRecoveryAction? {
        let normalized = message.lowercased()
        if kind == .ksAVIO, automaticMode, normalized.contains("mdk native isolation") {
            DiagnosticsLogger.shared.playback("Orchestrator", "engine error engine=\(kind.title) failureIsolation=triggered action=switch-mpv error=\(message)")
            return .switchEngine(.mpv, reason: "MDK native worker 超时；主线程仍响应，受控切换到 MPV 高兼容引擎")
        }
        if kind == .ksAVIO, automaticMode, normalized.contains("mdk session unsafe") {
            DiagnosticsLogger.shared.playback("Orchestrator", "engine error engine=\(kind.title) sessionUnsafe=true action=switch-mpv-immediate error=\(message)")
            return .switchEngine(.mpv, reason: "MDK 当前会话已进入不安全状态；立即切换到 MPV 高兼容引擎")
        }
        if kind == .ksAVIO, automaticMode, normalized.contains("mdk abnormal media recovery exhausted") {
            DiagnosticsLogger.shared.playback("Orchestrator", "engine error engine=\(kind.title) recoveryExhausted=true action=switch-mpv-immediate error=\(message)")
            return .switchEngine(.mpv, reason: "MDK 异常媒体恢复已用尽；立即切换到 MPV 高兼容引擎")
        }
        DiagnosticsLogger.shared.log("Orchestrator", "engine error engine=\(kind.title) runtimeSwitch=disabled error=\(message)")
        return nil
    }
}
