import CoreGraphics
import Foundation

enum RendererLayoutReason: String {
    case layout
    case surface
    case engineChange
}

struct RendererSurfaceGeometry: Equatable {
    let pointSize: CGSize
    let expectedBackingSize: CGSize
    let observedBackingSize: CGSize
    let scale: CGFloat

    var hasObservedBacking: Bool { observedBackingSize.width > 1 && observedBackingSize.height > 1 }
    var backingMatchesExpected: Bool { !hasObservedBacking || Self.matches(observedBackingSize, expectedBackingSize, tolerance: 3) }

    static func matches(_ lhs: CGSize, _ rhs: CGSize, tolerance: CGFloat) -> Bool {
        abs(lhs.width - rhs.width) <= tolerance && abs(lhs.height - rhs.height) <= tolerance
    }
}

struct RendererLayoutRequest {
    let generation: UInt64
    let plan: VideoLayoutPlan
    let surface: RendererSurfaceGeometry
    let reason: RendererLayoutReason
    let forceRendererRefresh: Bool
}

struct RendererLayoutAcknowledgement {
    let generation: UInt64
    let matched: Bool
    let rendererConfigured: Bool
    let actualBackingSize: CGSize?
    let detail: String
}

protocol RendererLayoutEngineAdapter: AnyObject {
    func applyRendererLayout(_ request: RendererLayoutRequest, completion: @escaping (RendererLayoutAcknowledgement) -> Void)
}

@MainActor
final class RendererLayoutCoordinator {
    private struct PresentationSignature: Equatable {
        let contentMode: VideoLayoutPlan.ContentMode
        let sourceAspectRatio: Int?
        let aspectOverride: Int?

        init(plan: VideoLayoutPlan) {
            contentMode = plan.contentMode
            sourceAspectRatio = plan.sourceAspectRatio.map { Int(($0 * 10_000).rounded()) }
            aspectOverride = plan.aspectOverride.map { Int(($0 * 10_000).rounded()) }
        }
    }

    private struct SnapshotKey: Equatable {
        let engineID: ObjectIdentifier
        let plan: VideoLayoutPlan
        let targetBackingWidth: Int
        let targetBackingHeight: Int
        let scaleMilli: Int
        let presentationEpoch: UInt64
    }

    private enum State: String {
        case idle
        case waitingSurface
        case waitingRenderer
        case settled
        case failed
    }

    private var desiredPlan: VideoLayoutPlan?
    private var surfaceGeometry: RendererSurfaceGeometry?
    private var activeEngineID: ObjectIdentifier?
    private var activeSnapshotKey: SnapshotKey?
    private var activeTargetBackingSize: CGSize?
    private var lastPresentationSignature: PresentationSignature?
    private var lastTargetBackingSize: CGSize?
    private var lastRendererConfigured = false
    private var lastRendererActualBackingSize: CGSize?
    private var state: State = .idle
    private(set) var generation: UInt64 = 0
    private(set) var acknowledgedGeneration: UInt64 = 0

    func submit(plan: VideoLayoutPlan, engine: PlayerEngine, reason: RendererLayoutReason) {
        let engineID = ObjectIdentifier(engine as AnyObject)
        if activeEngineID != engineID {
            activeEngineID = engineID
            surfaceGeometry = nil
            activeSnapshotKey = nil
            activeTargetBackingSize = nil
            lastPresentationSignature = nil
            lastTargetBackingSize = nil
            lastRendererConfigured = false
            lastRendererActualBackingSize = nil
            state = .idle
        }
        desiredPlan = plan
        evaluate(engine: engine, reason: reason)
    }

    func surfaceDidSettle(_ geometry: RendererSurfaceGeometry, engine: PlayerEngine) {
        let engineID = ObjectIdentifier(engine as AnyObject)
        guard activeEngineID == nil || activeEngineID == engineID else { return }
        activeEngineID = engineID
        surfaceGeometry = geometry
        evaluate(engine: engine, reason: .surface)
    }

    func matches(plan: VideoLayoutPlan, engine: PlayerEngine) -> Bool {
        guard desiredPlan == plan else { return false }
        guard engine is RendererLayoutEngineAdapter else { return true }
        guard let surfaceGeometry, RendererSurfaceGeometry.matches(surfaceGeometry.pointSize, plan.surfaceFrame.size, tolerance: 1.5) else { return false }
        let target = targetBackingSize(for: plan, scale: surfaceGeometry.scale)
        guard let activeTargetBackingSize, RendererSurfaceGeometry.matches(activeTargetBackingSize, target, tolerance: 3) else { return false }
        guard state == .settled && acknowledgedGeneration == generation else { return false }
        if !lastRendererConfigured { return true }
        return surfaceGeometry.hasObservedBacking && RendererSurfaceGeometry.matches(surfaceGeometry.observedBackingSize, target, tolerance: 3)
    }

    func waitDescription(plan: VideoLayoutPlan, engine: PlayerEngine) -> String {
        let observed = surfaceGeometry?.observedBackingSize ?? .zero
        let scale = surfaceGeometry?.scale ?? 0
        let target = scale > 0 ? targetBackingSize(for: plan, scale: scale) : .zero
        let surface = surfaceGeometry?.pointSize ?? .zero
        return "engine=\(engine.kind.title) state=\(state.rawValue) generation=\(generation) ack=\(acknowledgedGeneration) planSurface=\(Int(plan.surfaceFrame.width))x\(Int(plan.surfaceFrame.height)) observedSurface=\(Int(surface.width))x\(Int(surface.height)) targetBacking=\(Int(target.width))x\(Int(target.height)) observedBacking=\(Int(observed.width))x\(Int(observed.height)) rendererConfigured=\(lastRendererConfigured) epoch=\(PlayerSurfacePresentationGate.shared.epoch)"
    }

    private func evaluate(engine: PlayerEngine, reason: RendererLayoutReason) {
        guard let plan = desiredPlan else { return }
        guard let surface = surfaceGeometry, RendererSurfaceGeometry.matches(surface.pointSize, plan.surfaceFrame.size, tolerance: 1.5) else {
            state = .waitingSurface
            return
        }

        let targetBacking = targetBackingSize(for: plan, scale: surface.scale)
        let normalizedSurface = RendererSurfaceGeometry(pointSize: surface.pointSize, expectedBackingSize: targetBacking, observedBackingSize: surface.observedBackingSize, scale: surface.scale)
        let observedMatchesTarget = normalizedSurface.hasObservedBacking && RendererSurfaceGeometry.matches(normalizedSurface.observedBackingSize, targetBacking, tolerance: 3)
        let engineID = ObjectIdentifier(engine as AnyObject)
        let presentationEpoch = PlayerSurfacePresentationGate.shared.epoch
        let key = SnapshotKey(
            engineID: engineID,
            plan: plan,
            targetBackingWidth: Int(targetBacking.width.rounded()),
            targetBackingHeight: Int(targetBacking.height.rounded()),
            scaleMilli: Int((surface.scale * 1_000).rounded()),
            presentationEpoch: presentationEpoch
        )

        if let adapter = engine as? RendererLayoutEngineAdapter {
            let sameSnapshot = key == activeSnapshotKey
            if sameSnapshot, state == .settled, !lastRendererConfigured || observedMatchesTarget {
                PlayerSurfacePresentationGate.shared.rendererDidSettle(epoch: presentationEpoch, targetBackingSize: targetBacking, actualBackingSize: lastRendererActualBackingSize)
                return
            }
            let mayRefreshRegressedSurface = sameSnapshot && state == .settled && lastRendererConfigured && !observedMatchesTarget
            let mayRetryFailedSnapshot = sameSnapshot && state == .failed && normalizedSurface.hasObservedBacking
            guard !sameSnapshot || mayRetryFailedSnapshot || mayRefreshRegressedSurface else { return }

            let signature = PresentationSignature(plan: plan)
            let targetChangedWithoutPresentationChange = lastPresentationSignature == signature && lastTargetBackingSize.map { !RendererSurfaceGeometry.matches($0, targetBacking, tolerance: 3) } == true
            let forceRefresh = PlayerSurfacePresentationGate.shared.isHolding || !observedMatchesTarget || targetChangedWithoutPresentationChange

            generation &+= 1
            let requestGeneration = generation
            activeSnapshotKey = key
            activeTargetBackingSize = targetBacking
            lastPresentationSignature = signature
            lastTargetBackingSize = targetBacking
            lastRendererConfigured = false
            lastRendererActualBackingSize = nil
            state = .waitingRenderer

            DiagnosticsLogger.shared.log(
                "RendererLayout",
                "request generation=\(requestGeneration) epoch=\(presentationEpoch) engine=\(engine.kind.title) reason=\(reason.rawValue) surface=\(Int(normalizedSurface.pointSize.width))x\(Int(normalizedSurface.pointSize.height)) target=\(Int(targetBacking.width))x\(Int(targetBacking.height)) observed=\(Int(normalizedSurface.observedBackingSize.width))x\(Int(normalizedSurface.observedBackingSize.height)) forceRefresh=\(forceRefresh)"
            )

            let request = RendererLayoutRequest(generation: requestGeneration, plan: plan, surface: normalizedSurface, reason: reason, forceRendererRefresh: forceRefresh)
            adapter.applyRendererLayout(request) { [weak self] acknowledgement in
                DispatchQueue.main.async {
                    guard let self, acknowledgement.generation == self.generation, self.activeSnapshotKey == key else { return }
                    self.lastRendererConfigured = acknowledgement.rendererConfigured
                    self.lastRendererActualBackingSize = acknowledgement.actualBackingSize
                    if acknowledgement.matched {
                        self.acknowledgedGeneration = acknowledgement.generation
                        self.state = .settled
                    } else {
                        self.state = .failed
                    }
                    let actual = acknowledgement.actualBackingSize ?? .zero
                    DiagnosticsLogger.shared.log(
                        "RendererLayout",
                        "ack generation=\(acknowledgement.generation) epoch=\(presentationEpoch) engine=\(engine.kind.title) matched=\(acknowledgement.matched) configured=\(acknowledgement.rendererConfigured) target=\(Int(targetBacking.width))x\(Int(targetBacking.height)) actual=\(Int(actual.width))x\(Int(actual.height)) detail=\(acknowledgement.detail)"
                    )
                    let latestSurfaceMatches = self.surfaceGeometry.map { current in
                        RendererSurfaceGeometry.matches(current.pointSize, plan.surfaceFrame.size, tolerance: 1.5) && (!acknowledgement.rendererConfigured || current.hasObservedBacking && RendererSurfaceGeometry.matches(current.observedBackingSize, targetBacking, tolerance: 3))
                    } == true
                    if acknowledgement.matched, latestSurfaceMatches {
                        PlayerSurfacePresentationGate.shared.rendererDidSettle(epoch: presentationEpoch, targetBackingSize: targetBacking, actualBackingSize: acknowledgement.actualBackingSize)
                    }
                }
            }
            return
        }

        if key != activeSnapshotKey {
            generation &+= 1
            activeSnapshotKey = key
            activeTargetBackingSize = targetBacking
        }
        acknowledgedGeneration = generation
        state = .settled
        PlayerSurfacePresentationGate.shared.passiveSurfaceDidSettle()
    }

    private func targetBackingSize(for plan: VideoLayoutPlan, scale: CGFloat) -> CGSize {
        CGSize(width: max(2, (plan.surfaceFrame.width * scale).rounded()), height: max(2, (plan.surfaceFrame.height * scale).rounded()))
    }
}
