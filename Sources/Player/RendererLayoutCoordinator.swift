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

    private struct RequestKey: Equatable {
        let engineID: ObjectIdentifier
        let plan: VideoLayoutPlan
        let expectedBackingWidth: Int
        let expectedBackingHeight: Int
        let observedBackingWidth: Int
        let observedBackingHeight: Int
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
    private var lastRequestKey: RequestKey?
    private var lastPresentationSignature: PresentationSignature?
    private var lastTargetBackingSize: CGSize?
    private var state: State = .idle
    private(set) var generation: UInt64 = 0
    private(set) var acknowledgedGeneration: UInt64 = 0

    func submit(plan: VideoLayoutPlan, engine: PlayerEngine, reason: RendererLayoutReason) {
        let engineID = ObjectIdentifier(engine as AnyObject)
        if activeEngineID != engineID {
            activeEngineID = engineID
            surfaceGeometry = nil
            lastRequestKey = nil
            lastPresentationSignature = nil
            lastTargetBackingSize = nil
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
        return state == .settled && acknowledgedGeneration == generation
    }

    func waitDescription(plan: VideoLayoutPlan, engine: PlayerEngine) -> String {
        let target = surfaceGeometry?.expectedBackingSize ?? .zero
        let observed = surfaceGeometry?.observedBackingSize ?? .zero
        return "engine=\(engine.kind.title) state=\(state.rawValue) generation=\(generation) ack=\(acknowledgedGeneration) planSurface=\(Int(plan.surfaceFrame.width))x\(Int(plan.surfaceFrame.height)) targetBacking=\(Int(target.width))x\(Int(target.height)) observedBacking=\(Int(observed.width))x\(Int(observed.height))"
    }

    private func evaluate(engine: PlayerEngine, reason: RendererLayoutReason) {
        guard let plan = desiredPlan else { return }
        guard let adapter = engine as? RendererLayoutEngineAdapter else {
            state = .settled
            acknowledgedGeneration = generation
            return
        }
        guard let surface = surfaceGeometry, RendererSurfaceGeometry.matches(surface.pointSize, plan.surfaceFrame.size, tolerance: 1.5) else {
            state = .waitingSurface
            return
        }
        guard surface.backingMatchesExpected else {
            state = .waitingSurface
            return
        }

        let engineID = ObjectIdentifier(engine as AnyObject)
        let key = RequestKey(
            engineID: engineID,
            plan: plan,
            expectedBackingWidth: Int(surface.expectedBackingSize.width.rounded()),
            expectedBackingHeight: Int(surface.expectedBackingSize.height.rounded()),
            observedBackingWidth: Int(surface.observedBackingSize.width.rounded()),
            observedBackingHeight: Int(surface.observedBackingSize.height.rounded())
        )
        guard key != lastRequestKey else { return }

        let signature = PresentationSignature(plan: plan)
        let forceRefresh = lastPresentationSignature == signature && lastTargetBackingSize.map { !RendererSurfaceGeometry.matches($0, surface.expectedBackingSize, tolerance: 3) } == true
        generation &+= 1
        let requestGeneration = generation
        lastRequestKey = key
        lastPresentationSignature = signature
        lastTargetBackingSize = surface.expectedBackingSize
        state = .waitingRenderer

        DiagnosticsLogger.shared.log(
            "RendererLayout",
            "request generation=\(requestGeneration) engine=\(engine.kind.title) reason=\(reason.rawValue) surface=\(Int(surface.pointSize.width))x\(Int(surface.pointSize.height)) target=\(Int(surface.expectedBackingSize.width))x\(Int(surface.expectedBackingSize.height)) observed=\(Int(surface.observedBackingSize.width))x\(Int(surface.observedBackingSize.height)) forceRefresh=\(forceRefresh)"
        )

        let request = RendererLayoutRequest(generation: requestGeneration, plan: plan, surface: surface, reason: reason, forceRendererRefresh: forceRefresh)
        adapter.applyRendererLayout(request) { [weak self] acknowledgement in
            DispatchQueue.main.async {
                guard let self, acknowledgement.generation == self.generation else { return }
                if acknowledgement.matched {
                    self.acknowledgedGeneration = acknowledgement.generation
                    self.state = .settled
                } else {
                    self.state = .failed
                }
                let actual = acknowledgement.actualBackingSize ?? .zero
                DiagnosticsLogger.shared.log(
                    "RendererLayout",
                    "ack generation=\(acknowledgement.generation) engine=\(engine.kind.title) matched=\(acknowledgement.matched) configured=\(acknowledgement.rendererConfigured) actual=\(Int(actual.width))x\(Int(actual.height)) detail=\(acknowledgement.detail)"
                )
            }
        }
    }
}
