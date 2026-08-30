import Foundation
import QuartzCore
import SwiftUI
import UIKit

final class EmbyPosterGridCadenceDiagnostics: NSObject {
    static let shared = EmbyPosterGridCadenceDiagnostics()

    private final class MotionSession {
        let startedAt: CFTimeInterval
        let startItemCount: Int
        var displayIntervalsMS: [Double] = []
        var offsetSampleCount = 0
        var cellAppearCount = 0
        var cellDisappearCount = 0
        var loadAheadCount = 0
        var itemCountChanges = 0
        var imagePublishCount = 0
        var decelerationDisplayFrameCount = 0
        var decelerationDisplayZeroMoveCount = 0
        var decelerationDisplayCatchUpCount = 0
        var decelerationDisplayReverseCount = 0
        var lastDecelerationDisplayOffsetY: CGFloat?
        var lastDecelerationDisplayDeltaY: CGFloat?
        var previousDecelerationDisplayWasZero = false

        init(startedAt: CFTimeInterval, startItemCount: Int) {
            self.startedAt = startedAt
            self.startItemCount = startItemCount
        }
    }

    private final class Owner {
        weak var scrollView: UIScrollView?
        var route: String
        var itemCount: Int
        var lastDisplayOffsetY: CGFloat
        var observation: NSKeyValueObservation?
        var session: MotionSession?

        init(scrollView: UIScrollView, route: String, itemCount: Int) {
            self.scrollView = scrollView
            self.route = route
            self.itemCount = itemCount
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
        owners[ownerID]?.session?.cellAppearCount += 1
    }

    func cellDidDisappear(ownerID: UUID) {
        precondition(Thread.isMainThread)
        owners[ownerID]?.session?.cellDisappearCount += 1
    }

    func imageDidPublish(ownerID: UUID) {
        precondition(Thread.isMainThread)
        owners[ownerID]?.session?.imagePublishCount += 1
    }

    func loadAheadDidTrigger(ownerID: UUID) {
        precondition(Thread.isMainThread)
        owners[ownerID]?.session?.loadAheadCount += 1
    }

    private func updateItemCount(_ itemCount: Int, ownerID: UUID) {
        guard let owner = owners[ownerID] else { return }
        if owner.itemCount != itemCount { owner.session?.itemCountChanges += 1 }
        owner.itemCount = itemCount
    }

    private func contentOffsetDidChange(ownerID: UUID, scrollView: UIScrollView) {
        precondition(Thread.isMainThread)
        guard let owner = owners[ownerID], owner.scrollView === scrollView else { return }
        let isUserMotion = scrollView.isDragging || scrollView.isDecelerating
        if owner.session == nil, isUserMotion {
            owner.session = MotionSession(startedAt: CACurrentMediaTime(), startItemCount: owner.itemCount)
            lastDisplayTimestamp = nil
            updateRefreshRateRequest()
        }
        owner.session?.offsetSampleCount += 1
    }

    private func ensureDisplayLink() {
        guard displayLink == nil else { return }
        lastDisplayTimestamp = nil
        let link = CADisplayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.preferredFrameRateRange = .default
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
            guard let session = owner.session else {
                owner.lastDisplayOffsetY = scrollView.contentOffset.y
                continue
            }

            if let previousDisplayTimestamp {
                let intervalMS = max(0, (link.timestamp - previousDisplayTimestamp) * 1000)
                if intervalMS > 0, intervalMS < 200 { session.displayIntervalsMS.append(intervalMS) }
            }

            let currentOffsetY = scrollView.contentOffset.y
            if scrollView.isDecelerating {
                if let previousOffsetY = session.lastDecelerationDisplayOffsetY {
                    let deltaY = currentOffsetY - previousOffsetY
                    session.decelerationDisplayFrameCount += 1
                    if abs(deltaY) <= 0.01 {
                        session.decelerationDisplayZeroMoveCount += 1
                        session.previousDecelerationDisplayWasZero = true
                    } else {
                        if session.previousDecelerationDisplayWasZero { session.decelerationDisplayCatchUpCount += 1 }
                        if let previousDeltaY = session.lastDecelerationDisplayDeltaY, abs(previousDeltaY) > 0.01, deltaY.sign != previousDeltaY.sign {
                            session.decelerationDisplayReverseCount += 1
                        }
                        session.lastDecelerationDisplayDeltaY = deltaY
                        session.previousDecelerationDisplayWasZero = false
                    }
                }
                session.lastDecelerationDisplayOffsetY = currentOffsetY
            } else {
                session.lastDecelerationDisplayOffsetY = currentOffsetY
                session.lastDecelerationDisplayDeltaY = nil
                session.previousDecelerationDisplayWasZero = false
            }

            let movedSinceLastDisplay = abs(currentOffsetY - owner.lastDisplayOffsetY) > 0.01
            owner.lastDisplayOffsetY = currentOffsetY
            if !scrollView.isDragging && !scrollView.isDecelerating && !movedSinceLastDisplay {
                owner.session = nil
                log(session: session, owner: owner, endedAt: link.timestamp, reason: "motion-ended")
            }
        }

        for ownerID in staleOwnerIDs { stopObserving(ownerID: ownerID) }
        updateRefreshRateRequest()
    }

    private func log(session: MotionSession, owner: Owner, endedAt: CFTimeInterval, reason: String) {
        let display = intervalSummary(session.displayIntervalsMS)
        let durationMS = max(0, (endedAt - session.startedAt) * 1000)
        let durationSeconds = max(durationMS / 1000, 0.001)
        let offsetHz = Double(session.offsetSampleCount) / durationSeconds
        let displayHz = Double(session.displayIntervalsMS.count) / durationSeconds
        let zeroRatio = session.decelerationDisplayFrameCount > 0 ? Double(session.decelerationDisplayZeroMoveCount) / Double(session.decelerationDisplayFrameCount) : 0
        let catchUpRatio = session.decelerationDisplayFrameCount > 0 ? Double(session.decelerationDisplayCatchUpCount) / Double(session.decelerationDisplayFrameCount) : 0
        DiagnosticsLogger.shared.app(
            "PosterGridCadence",
            "route=\(owner.route) reason=\(reason) duration_ms=\(format(durationMS)) maximum_fps=\(UIScreen.main.maximumFramesPerSecond) refresh_request=\(refreshRequestActive ? 1 : 0) requested_min_fps=\(UIScreen.main.maximumFramesPerSecond > 60 ? 80 : 0) requested_max_fps=\(UIScreen.main.maximumFramesPerSecond > 60 ? UIScreen.main.maximumFramesPerSecond : 0) offset_samples=\(session.offsetSampleCount) offset_hz=\(format(offsetHz)) display_samples=\(session.displayIntervalsMS.count) display_hz=\(format(displayHz)) display_p50_ms=\(format(display.p50)) display_p95_ms=\(format(display.p95)) display_p99_ms=\(format(display.p99)) display_max_ms=\(format(display.max)) display_ge10=\(display.ge10) display_ge12_5=\(display.ge12_5) display_ge16_7=\(display.ge16_7) display_ge25=\(display.ge25) display_ge33_3=\(display.ge33_3) item_count_start=\(session.startItemCount) item_count_end=\(owner.itemCount) item_count_changes=\(session.itemCountChanges) cell_appear=\(session.cellAppearCount) cell_disappear=\(session.cellDisappearCount) image_publish=\(session.imagePublishCount) load_ahead=\(session.loadAheadCount) decel_display_frames=\(session.decelerationDisplayFrameCount) decel_display_zero=\(session.decelerationDisplayZeroMoveCount) decel_display_catchup=\(session.decelerationDisplayCatchUpCount) decel_display_reverse=\(session.decelerationDisplayReverseCount) decel_zero_ratio=\(format(zeroRatio)) decel_catchup_ratio=\(format(catchUpRatio))"
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
            percentile(0.50), percentile(0.95), percentile(0.99), sorted.last ?? -1,
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
