import Foundation
import QuartzCore
import SwiftUI
import UIKit

final class EmbyPosterGridCadenceDiagnostics: NSObject {
    static let shared = EmbyPosterGridCadenceDiagnostics()

    private struct MotionSession {
        let startedAt: CFTimeInterval
        let startItemCount: Int
        var offsetIntervalsMS: [Double] = []
        var displayIntervalsMS: [Double] = []
        var dragSamples = 0
        var decelerationSamples = 0
        var cellAppearCount = 0
        var cellDisappearCount = 0
        var loadAheadCount = 0
        var itemCountChanges = 0
        var maxAbsVelocityY: CGFloat = 0
        var maxAbsDeltaY: CGFloat = 0
    }

    private final class Owner {
        weak var scrollView: UIScrollView?
        var route: String
        var itemCount: Int
        var lastOffsetY: CGFloat
        var lastOffsetTimestamp: CFTimeInterval?
        var lastDisplayOffsetY: CGFloat
        var observation: NSKeyValueObservation?
        var session: MotionSession?

        init(scrollView: UIScrollView, route: String, itemCount: Int) {
            self.scrollView = scrollView
            self.route = route
            self.itemCount = itemCount
            lastOffsetY = scrollView.contentOffset.y
            lastDisplayOffsetY = scrollView.contentOffset.y
        }
    }

    private var owners: [UUID: Owner] = [:]
    private var displayLink: CADisplayLink?
    private var lastDisplayTimestamp: CFTimeInterval?
    private var refreshRequestActive = false

    private override init() {}

    func observe(_ scrollView: UIScrollView, ownerID: UUID, route: String, itemCount: Int) {
        precondition(Thread.isMainThread)
        if let owner = owners[ownerID], owner.scrollView === scrollView {
            owner.route = route
            updateItemCount(itemCount, ownerID: ownerID)
            return
        }
        stopObserving(ownerID: ownerID)
        let owner = Owner(scrollView: scrollView, route: route, itemCount: itemCount)
        owner.observation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self, weak scrollView] _, _ in
            guard let self, let scrollView else { return }
            self.contentOffsetDidChange(ownerID: ownerID, scrollView: scrollView)
        }
        owners[ownerID] = owner
        ensureDisplayLink()
    }

    func update(ownerID: UUID, route: String, itemCount: Int) {
        precondition(Thread.isMainThread)
        guard let owner = owners[ownerID] else { return }
        owner.route = route
        updateItemCount(itemCount, ownerID: ownerID)
    }

    func stopObserving(ownerID: UUID) {
        precondition(Thread.isMainThread)
        guard let owner = owners.removeValue(forKey: ownerID) else { return }
        if let session = owner.session { log(session: session, owner: owner, endedAt: CACurrentMediaTime(), reason: "grid-disappear") }
        owner.observation?.invalidate()
        owner.observation = nil
        if owners.isEmpty { stopDisplayLink() }
        else { updateRefreshRateRequest() }
    }

    func cellDidAppear(ownerID: UUID) {
        precondition(Thread.isMainThread)
        guard var session = owners[ownerID]?.session else { return }
        session.cellAppearCount += 1
        owners[ownerID]?.session = session
    }

    func cellDidDisappear(ownerID: UUID) {
        precondition(Thread.isMainThread)
        guard var session = owners[ownerID]?.session else { return }
        session.cellDisappearCount += 1
        owners[ownerID]?.session = session
    }

    func loadAheadDidTrigger(ownerID: UUID) {
        precondition(Thread.isMainThread)
        guard var session = owners[ownerID]?.session else { return }
        session.loadAheadCount += 1
        owners[ownerID]?.session = session
    }

    private func updateItemCount(_ itemCount: Int, ownerID: UUID) {
        guard let owner = owners[ownerID] else { return }
        if owner.itemCount != itemCount, var session = owner.session {
            session.itemCountChanges += 1
            owner.session = session
        }
        owner.itemCount = itemCount
    }

    private func contentOffsetDidChange(ownerID: UUID, scrollView: UIScrollView) {
        precondition(Thread.isMainThread)
        guard let owner = owners[ownerID], owner.scrollView === scrollView else { return }
        let now = CACurrentMediaTime()
        let offsetY = scrollView.contentOffset.y
        let deltaY = offsetY - owner.lastOffsetY
        owner.lastOffsetY = offsetY

        let isUserMotion = scrollView.isDragging || scrollView.isDecelerating
        if owner.session == nil, isUserMotion {
            owner.session = MotionSession(startedAt: now, startItemCount: owner.itemCount)
            owner.lastOffsetTimestamp = now
        }
        guard var session = owner.session else {
            owner.lastOffsetTimestamp = now
            return
        }

        if let previous = owner.lastOffsetTimestamp {
            let intervalMS = max(0, (now - previous) * 1000)
            if intervalMS > 0, intervalMS < 200 { session.offsetIntervalsMS.append(intervalMS) }
        }
        owner.lastOffsetTimestamp = now
        if scrollView.isDragging { session.dragSamples += 1 }
        if scrollView.isDecelerating { session.decelerationSamples += 1 }
        session.maxAbsVelocityY = max(session.maxAbsVelocityY, abs(scrollView.panGestureRecognizer.velocity(in: scrollView).y))
        session.maxAbsDeltaY = max(session.maxAbsDeltaY, abs(deltaY))
        owner.session = session
        updateRefreshRateRequest()
    }

    private func ensureDisplayLink() {
        guard displayLink == nil else { return }
        lastDisplayTimestamp = nil
        let link = CADisplayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        lastDisplayTimestamp = nil
        refreshRequestActive = false
    }

    private func updateRefreshRateRequest() {
        guard let displayLink else { return }
        let maximumFPS = max(60, UIScreen.main.maximumFramesPerSecond)
        let shouldRequest = maximumFPS > 60 && owners.values.contains { $0.session != nil }
        guard shouldRequest != refreshRequestActive else { return }
        refreshRequestActive = shouldRequest
        if shouldRequest {
            let maximum = Float(maximumFPS)
            displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: maximum, preferred: maximum)
        } else {
            displayLink.preferredFrameRateRange = .default
        }
    }

    @objc private func displayLinkDidFire(_ link: CADisplayLink) {
        let previousDisplayTimestamp = lastDisplayTimestamp
        lastDisplayTimestamp = link.timestamp
        var staleOwnerIDs: [UUID] = []

        for (ownerID, owner) in owners {
            guard let scrollView = owner.scrollView else {
                staleOwnerIDs.append(ownerID)
                continue
            }
            guard var session = owner.session else {
                owner.lastDisplayOffsetY = scrollView.contentOffset.y
                continue
            }

            if let previousDisplayTimestamp {
                let intervalMS = max(0, (link.timestamp - previousDisplayTimestamp) * 1000)
                if intervalMS > 0, intervalMS < 200 { session.displayIntervalsMS.append(intervalMS) }
            }
            owner.session = session

            let currentOffsetY = scrollView.contentOffset.y
            let movedSinceLastDisplay = abs(currentOffsetY - owner.lastDisplayOffsetY) > 0.01
            owner.lastDisplayOffsetY = currentOffsetY
            if !scrollView.isDragging && !scrollView.isDecelerating && !movedSinceLastDisplay {
                owner.session = nil
                owner.lastOffsetTimestamp = nil
                log(session: session, owner: owner, endedAt: link.timestamp, reason: "motion-ended")
            }
        }

        for ownerID in staleOwnerIDs { stopObserving(ownerID: ownerID) }
        updateRefreshRateRequest()
    }

    private func log(session: MotionSession, owner: Owner, endedAt: CFTimeInterval, reason: String) {
        let offset = intervalSummary(session.offsetIntervalsMS)
        let display = intervalSummary(session.displayIntervalsMS)
        let durationMS = max(0, (endedAt - session.startedAt) * 1000)
        DiagnosticsLogger.shared.app(
            "PosterGridCadence",
            "route=\(owner.route) reason=\(reason) duration_ms=\(format(durationMS)) maximum_fps=\(UIScreen.main.maximumFramesPerSecond) refresh_request=\(refreshRequestActive ? 1 : 0) requested_min_fps=\(UIScreen.main.maximumFramesPerSecond > 60 ? 80 : 0) requested_max_fps=\(UIScreen.main.maximumFramesPerSecond > 60 ? UIScreen.main.maximumFramesPerSecond : 0) offset_samples=\(session.offsetIntervalsMS.count) offset_p50_ms=\(format(offset.p50)) offset_p95_ms=\(format(offset.p95)) offset_p99_ms=\(format(offset.p99)) offset_max_ms=\(format(offset.max)) offset_ge10=\(offset.ge10) offset_ge12_5=\(offset.ge12_5) offset_ge16_7=\(offset.ge16_7) offset_ge25=\(offset.ge25) offset_ge33_3=\(offset.ge33_3) display_samples=\(session.displayIntervalsMS.count) display_p50_ms=\(format(display.p50)) display_p95_ms=\(format(display.p95)) display_p99_ms=\(format(display.p99)) display_max_ms=\(format(display.max)) display_ge10=\(display.ge10) display_ge12_5=\(display.ge12_5) display_ge16_7=\(display.ge16_7) display_ge25=\(display.ge25) display_ge33_3=\(display.ge33_3) drag_samples=\(session.dragSamples) decel_samples=\(session.decelerationSamples) cell_appear=\(session.cellAppearCount) cell_disappear=\(session.cellDisappearCount) load_ahead=\(session.loadAheadCount) item_count_start=\(session.startItemCount) item_count_end=\(owner.itemCount) item_count_changes=\(session.itemCountChanges) max_velocity_y=\(format(Double(session.maxAbsVelocityY))) max_delta_y=\(format(Double(session.maxAbsDeltaY)))"
        )
    }

    private func intervalSummary(_ samples: [Double]) -> (p50: Double, p95: Double, p99: Double, max: Double, ge10: Int, ge12_5: Int, ge16_7: Int, ge25: Int, ge33_3: Int) {
        guard !samples.isEmpty else { return (-1, -1, -1, -1, 0, 0, 0, 0, 0) }
        let sorted = samples.sorted()
        func percentile(_ value: Double) -> Double {
            let index = min(sorted.count - 1, max(0, Int(ceil(Double(sorted.count) * value)) - 1))
            return sorted[index]
        }
        return (
            percentile(0.50),
            percentile(0.95),
            percentile(0.99),
            sorted.last ?? -1,
            samples.filter { $0 >= 10.0 }.count,
            samples.filter { $0 >= 12.5 }.count,
            samples.filter { $0 >= 16.7 }.count,
            samples.filter { $0 >= 25.0 }.count,
            samples.filter { $0 >= 33.3 }.count
        )
    }

    private func format(_ value: Double) -> String { String(format: "%.2f", value) }
}

private final class EmbyPosterGridCadenceProbeView: UIView {
    var hierarchyDidChange: ((UIView) -> Void)?

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        hierarchyDidChange?(self)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        hierarchyDidChange?(self)
    }
}

struct EmbyPosterGridCadenceProbe: UIViewRepresentable {
    let ownerID: UUID
    let route: String
    let itemCount: Int

    func makeCoordinator() -> Coordinator { Coordinator(ownerID: ownerID, route: route, itemCount: itemCount) }

    func makeUIView(context: Context) -> UIView {
        let view = EmbyPosterGridCadenceProbeView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.hierarchyDidChange = { [weak coordinator = context.coordinator] probe in coordinator?.attach(from: probe) }
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak view] in
            guard let view else { return }
            coordinator?.attach(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.route = route
        context.coordinator.itemCount = itemCount
        EmbyPosterGridCadenceDiagnostics.shared.update(ownerID: ownerID, route: route, itemCount: itemCount)
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak uiView] in
            guard let uiView else { return }
            coordinator?.attach(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) { coordinator.detach() }

    final class Coordinator {
        let ownerID: UUID
        var route: String
        var itemCount: Int
        private weak var scrollView: UIScrollView?

        init(ownerID: UUID, route: String, itemCount: Int) {
            self.ownerID = ownerID
            self.route = route
            self.itemCount = itemCount
        }

        func attach(from probe: UIView) {
            guard let scrollView = ancestorVerticalScrollView(from: probe) else { return }
            self.scrollView = scrollView
            EmbyPosterGridCadenceDiagnostics.shared.observe(scrollView, ownerID: ownerID, route: route, itemCount: itemCount)
        }

        func detach() {
            EmbyPosterGridCadenceDiagnostics.shared.stopObserving(ownerID: ownerID)
            scrollView = nil
        }

        private func ancestorVerticalScrollView(from probe: UIView) -> UIScrollView? {
            var current: UIView? = probe
            while let view = current {
                if let scrollView = view as? UIScrollView, !scrollView.isPagingEnabled { return scrollView }
                current = view.superview
            }
            return nil
        }
    }
}
