import Foundation

extension MPVPlayerEngine: VideoLayoutEngineAdapter {
    func applyVideoLayout(_ plan: VideoLayoutPlan) {
        setVideoGeometry(panscan: plan.mpvPanscan, aspectOverride: plan.mpvAspectOverride)
    }
}

@MainActor
extension PlayerController {
    func applyVideoLayout(_ plan: VideoLayoutPlan) {
        (engine as? VideoLayoutEngineAdapter)?.applyVideoLayout(plan)
        let sourceAspect = plan.sourceAspectRatio.map { String(format: "%.4f", $0) } ?? "nil"
        let aspectOverride = plan.aspectOverride.map { String(format: "%.4f", $0) } ?? "nil"
        DiagnosticsLogger.shared.playback(
            "VideoLayout",
            "engine=\(engineKind.title) viewport=\(Int(plan.viewport.width))x\(Int(plan.viewport.height)) surface=\(Int(plan.surfaceFrame.width))x\(Int(plan.surfaceFrame.height)) mode=\(plan.contentMode.rawValue) sourceAspect=\(sourceAspect) override=\(aspectOverride)"
        )
    }
}
