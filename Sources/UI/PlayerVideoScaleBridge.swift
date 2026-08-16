import Foundation

extension MPVPlayerEngine: RendererLayoutEngineAdapter {}

@MainActor
private enum RendererLayoutRegistry {
    static let coordinators = NSMapTable<PlayerController, RendererLayoutCoordinator>.weakToStrongObjects()

    static func coordinator(for controller: PlayerController) -> RendererLayoutCoordinator {
        if let coordinator = coordinators.object(forKey: controller) { return coordinator }
        let coordinator = RendererLayoutCoordinator()
        coordinators.setObject(coordinator, forKey: controller)
        return coordinator
    }
}

@MainActor
extension PlayerController {
    private var rendererLayoutCoordinator: RendererLayoutCoordinator { RendererLayoutRegistry.coordinator(for: self) }

    func applyVideoLayout(_ plan: VideoLayoutPlan) {
        rendererLayoutCoordinator.submit(plan: plan, engine: engine, reason: .layout)
        let sourceAspect = plan.sourceAspectRatio.map { String(format: "%.4f", $0) } ?? "nil"
        let aspectOverride = plan.aspectOverride.map { String(format: "%.4f", $0) } ?? "nil"
        DiagnosticsLogger.shared.playback(
            "VideoLayout",
            "engine=\(engineKind.title) viewport=\(Int(plan.viewport.width))x\(Int(plan.viewport.height)) surface=\(Int(plan.surfaceFrame.width))x\(Int(plan.surfaceFrame.height)) mode=\(plan.contentMode.rawValue) sourceAspect=\(sourceAspect) override=\(aspectOverride)"
        )
    }

    func rendererSurfaceDidSettle(_ geometry: RendererSurfaceGeometry) {
        rendererLayoutCoordinator.surfaceDidSettle(geometry, engine: engine)
    }

    func rendererLayoutMatches(_ plan: VideoLayoutPlan) -> Bool {
        rendererLayoutCoordinator.matches(plan: plan, engine: engine)
    }

    func rendererLayoutWaitDescription(_ plan: VideoLayoutPlan) -> String {
        rendererLayoutCoordinator.waitDescription(plan: plan, engine: engine)
    }
}
