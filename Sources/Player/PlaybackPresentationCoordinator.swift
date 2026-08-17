import Combine
import Foundation

struct PlayerPresentationPreferenceKeys {
    static let motionSmoothingMode = "player.motionSmoothingMode"
    static let videoEnhancementEnabled = "player.videoEnhancementEnabled"
}

enum MotionSmoothingMode: String, CaseIterable, Identifiable {
    case off
    case automatic
    case fps60
    case fps120

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "关闭"
        case .automatic: return "自动"
        case .fps60: return "60 FPS"
        case .fps120: return "120 FPS"
        }
    }
}

enum VideoEnhancementFeature: String, Hashable {
    case upscale
    case sharpen
    case deband
    case chroma

    var title: String {
        switch self {
        case .upscale: return "上采样"
        case .sharpen: return "锐化"
        case .deband: return "去色带"
        case .chroma: return "色度增强"
        }
    }
}

enum PlaybackTimingStrategy: String {
    case audioMaster
    case displayCadenced
    case motionSmoothed
}

struct PlaybackPresentationPlan: Equatable {
    let requestedRate: Double
    let sourceFPS: Double?
    let displayFPS: Double
    let timingStrategy: PlaybackTimingStrategy
    let motionSmoothingMode: MotionSmoothingMode
    let effectiveMotionTargetFPS: Double?
    let videoEnhancementEnabled: Bool
    let requestedEnhancementFeatures: [VideoEnhancementFeature]

    var isHighRate: Bool { requestedRate > 2.0 }
    var motionSmoothingRequested: Bool { effectiveMotionTargetFPS != nil }
}

struct PlaybackPresentationAcknowledgement: Equatable {
    let activeMotionSmoothing: Bool
    let activeEnhancementFeatures: [VideoEnhancementFeature]
    let detail: String

    static let unsupported = PlaybackPresentationAcknowledgement(activeMotionSmoothing: false, activeEnhancementFeatures: [], detail: "engine-adapter-unavailable")
}

protocol PlaybackPresentationEngineAdapter: AnyObject {
    func applyPresentationPlan(_ plan: PlaybackPresentationPlan, completion: @escaping (PlaybackPresentationAcknowledgement) -> Void)
}

@MainActor
final class PlaybackPresentationCoordinator: ObservableObject {
    @Published private(set) var currentPlan: PlaybackPresentationPlan?
    @Published private(set) var acknowledgement = PlaybackPresentationAcknowledgement.unsupported

    private let sourceFPS: Double?
    private let sourceWidth: Int?
    private let sourceHeight: Int?

    init(source: ResolvedPlaybackSource) {
        let video = source.mediaSource.mediaStreams?.first(where: { $0.type?.caseInsensitiveCompare("Video") == .orderedSame })
        sourceFPS = video?.averageFrameRate ?? video?.realFrameRate
        sourceWidth = video?.width
        sourceHeight = video?.height
    }

    func makePlan(rate: Double, motionSmoothingMode: MotionSmoothingMode, videoEnhancementEnabled: Bool, displayFPS: Double) -> PlaybackPresentationPlan {
        let rate = min(8, max(0.15, rate))
        let displayFPS = min(240, max(30, displayFPS.isFinite ? displayFPS : 60))
        let motionTarget = resolvedMotionTarget(rate: rate, mode: motionSmoothingMode, displayFPS: displayFPS)
        let timingStrategy: PlaybackTimingStrategy = motionTarget != nil ? .motionSmoothed : (rate > 2 ? .displayCadenced : .audioMaster)
        return PlaybackPresentationPlan(
            requestedRate: rate,
            sourceFPS: sourceFPS,
            displayFPS: displayFPS,
            timingStrategy: timingStrategy,
            motionSmoothingMode: motionSmoothingMode,
            effectiveMotionTargetFPS: motionTarget,
            videoEnhancementEnabled: videoEnhancementEnabled,
            requestedEnhancementFeatures: videoEnhancementEnabled ? enhancementFeatures() : []
        )
    }

    func apply(_ plan: PlaybackPresentationPlan, using engine: PlayerEngine) {
        currentPlan = plan
        acknowledgement = PlaybackPresentationAcknowledgement(activeMotionSmoothing: false, activeEnhancementFeatures: [], detail: "awaiting-engine-ack")
        guard let adapter = engine as? PlaybackPresentationEngineAdapter else {
            engine.setPlaybackRate(plan.requestedRate)
            acknowledgement = .unsupported
            DiagnosticsLogger.shared.playback("PresentationPlan", "engine=\(engine.kind.title) adapter=missing rate=\(String(format: "%.2f", plan.requestedRate))")
            return
        }
        adapter.applyPresentationPlan(plan) { [weak self] acknowledgement in
            DispatchQueue.main.async {
                guard let self, self.currentPlan == plan else { return }
                self.acknowledgement = acknowledgement
                DiagnosticsLogger.shared.playback("PresentationPlan", "engine=\(engine.kind.title) rate=\(String(format: "%.2f", plan.requestedRate)) timing=\(plan.timingStrategy.rawValue) display=\(String(format: "%.1f", plan.displayFPS)) source=\(plan.sourceFPS.map { String(format: "%.3f", $0) } ?? "unknown") motion=\(acknowledgement.activeMotionSmoothing) enhancement=\(acknowledgement.activeEnhancementFeatures.map(\.rawValue).joined(separator: ",")) detail=\(acknowledgement.detail)")
            }
        }
    }

    var activeFeatureBadges: [String] {
        var badges: [String] = []
        if !acknowledgement.activeEnhancementFeatures.isEmpty {
            badges.append("超画")
            badges.append(contentsOf: acknowledgement.activeEnhancementFeatures.prefix(2).map(\.title))
        }
        if acknowledgement.activeMotionSmoothing, let target = currentPlan?.effectiveMotionTargetFPS { badges.append("\(Int(target.rounded()))Hz") }
        return badges
    }

    private func resolvedMotionTarget(rate: Double, mode: MotionSmoothingMode, displayFPS: Double) -> Double? {
        guard abs(rate - 1) < 0.01 else { return nil }
        switch mode {
        case .off: return nil
        case .automatic:
            guard let sourceFPS, sourceFPS < 50 else { return nil }
            return displayFPS >= 100 ? min(120, displayFPS) : min(60, displayFPS)
        case .fps60:
            return min(60, displayFPS)
        case .fps120:
            return min(120, displayFPS)
        }
    }

    private func enhancementFeatures() -> [VideoEnhancementFeature] {
        guard let sourceWidth, let sourceHeight else { return [.sharpen, .deband] }
        if sourceWidth <= 1920 || sourceHeight <= 1080 { return [.upscale, .sharpen, .deband, .chroma] }
        return [.sharpen, .deband, .chroma]
    }
}
