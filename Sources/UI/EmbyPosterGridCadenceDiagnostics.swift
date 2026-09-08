import CoreFoundation
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
        var decelerationDisplayFrameCount = 0
        var decelerationDisplayZeroMoveCount = 0
        var decelerationDisplayCatchUpCount = 0
        var decelerationDisplayReverseCount = 0
        var decelerationDisplayDeltas: [Double] = []
        var decelerationDisplayStepRatios: [Double] = []
        var lastDecelerationDisplayOffsetY: CGFloat?
        var lastDecelerationDisplayDeltaY: CGFloat?
        var previousDecelerationDisplayWasZero = false
        var offsetChangesSinceLastDisplay = 0
        var imagePublishCount = 0
        var lastDisplayCellAppearCount = 0
        var lastDisplayCellDisappearCount = 0
        var lastDisplayLoadAheadCount = 0
        var lastDisplayItemCountChanges = 0
        var lastDisplayImagePublishCount = 0
        var lastDisplayRunLoopBeforeWaitingCount = 0
        var longDisplayGapCount = 0
        var longDisplayGapWithCellChurnCount = 0
        var longDisplayGapWithImagePublishCount = 0
        var longDisplayGapWithLoadAheadCount = 0
        var longDisplayGapWithItemCountChangeCount = 0
        var longDisplayGapWithNoTrackedGridWorkCount = 0
        var longDisplayGapMaxCellAppearDelta = 0
        var longDisplayGapMaxCellDisappearDelta = 0
        var longDisplayGapMaxImagePublishDelta = 0
        var longDisplayGapMaxOffsetChanges = 0
        var severe25GapCount = 0
        var severe25WithCellChurnCount = 0
        var severe25WithImagePublishCount = 0
        var severe25WithLoadAheadCount = 0
        var severe25WithItemCountChangeCount = 0
        var severe25WithNoTrackedGridWorkCount = 0
        var severe25WithoutRunLoopWaitCount = 0
        var severe25WithRunLoopWaitCount = 0
        var severe33GapCount = 0
        var severe33WithCellChurnCount = 0
        var severe33WithImagePublishCount = 0
        var severe33WithLoadAheadCount = 0
        var severe33WithItemCountChangeCount = 0
        var severe33WithNoTrackedGridWorkCount = 0
        var severe33WithoutRunLoopWaitCount = 0
        var severe33WithRunLoopWaitCount = 0
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
    private var runLoopObserver: CFRunLoopObserver?
    private var runLoopBeforeWaitingCount = 0

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

    func imageDidPublish(ownerID: UUID) {
        precondition(Thread.isMainThread)
        guard var session = owners[ownerID]?.session else { return }
        session.imagePublishCount += 1
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
            var session = MotionSession(startedAt: now, startItemCount: owner.itemCount)
            session.lastDisplayRunLoopBeforeWaitingCount = runLoopBeforeWaitingCount
            owner.session = session
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
        session.offsetChangesSinceLastDisplay += 1
        owner.session = session
        updateRefreshRateRequest()
    }

    private func ensureDisplayLink() {
        guard displayLink == nil else { return }
        ensureRunLoopObserver()
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
        stopRunLoopObserver()
    }

    private func ensureRunLoopObserver() {
        guard runLoopObserver == nil else { return }
        guard let observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, CFRunLoopActivity.beforeWaiting.rawValue, true, 0, { [weak self] _, _ in self?.runLoopBeforeWaitingCount += 1 }) else { return }
        runLoopObserver = observer
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, CFRunLoopMode.commonModes)
    }

    private func stopRunLoopObserver() {
        guard let runLoopObserver else { return }
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), runLoopObserver, CFRunLoopMode.commonModes)
        self.runLoopObserver = nil
        runLoopBeforeWaitingCount = 0
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
                if intervalMS > 0, intervalMS < 200 {
                    session.displayIntervalsMS.append(intervalMS)
                    let cellAppearDelta = max(0, session.cellAppearCount - session.lastDisplayCellAppearCount)
                    let cellDisappearDelta = max(0, session.cellDisappearCount - session.lastDisplayCellDisappearCount)
                    let loadAheadDelta = max(0, session.loadAheadCount - session.lastDisplayLoadAheadCount)
                    let itemCountChangeDelta = max(0, session.itemCountChanges - session.lastDisplayItemCountChanges)
                    let imagePublishDelta = max(0, session.imagePublishCount - session.lastDisplayImagePublishCount)
                    let runLoopBeforeWaitingDelta = max(0, runLoopBeforeWaitingCount - session.lastDisplayRunLoopBeforeWaitingCount)
                    let hasCellChurn = cellAppearDelta > 0 || cellDisappearDelta > 0
                    let hasTrackedGridWork = hasCellChurn || imagePublishDelta > 0 || loadAheadDelta > 0 || itemCountChangeDelta > 0
                    if intervalMS >= 12.5 {
                        session.longDisplayGapCount += 1
                        if hasCellChurn { session.longDisplayGapWithCellChurnCount += 1 }
                        if imagePublishDelta > 0 { session.longDisplayGapWithImagePublishCount += 1 }
                        if loadAheadDelta > 0 { session.longDisplayGapWithLoadAheadCount += 1 }
                        if itemCountChangeDelta > 0 { session.longDisplayGapWithItemCountChangeCount += 1 }
                        if !hasTrackedGridWork { session.longDisplayGapWithNoTrackedGridWorkCount += 1 }
                        session.longDisplayGapMaxCellAppearDelta = max(session.longDisplayGapMaxCellAppearDelta, cellAppearDelta)
                        session.longDisplayGapMaxCellDisappearDelta = max(session.longDisplayGapMaxCellDisappearDelta, cellDisappearDelta)
                        session.longDisplayGapMaxImagePublishDelta = max(session.longDisplayGapMaxImagePublishDelta, imagePublishDelta)
                        session.longDisplayGapMaxOffsetChanges = max(session.longDisplayGapMaxOffsetChanges, session.offsetChangesSinceLastDisplay)
                    }
                    if intervalMS >= 25.0 {
                        session.severe25GapCount += 1
                        if hasCellChurn { session.severe25WithCellChurnCount += 1 }
                        if imagePublishDelta > 0 { session.severe25WithImagePublishCount += 1 }
                        if loadAheadDelta > 0 { session.severe25WithLoadAheadCount += 1 }
                        if itemCountChangeDelta > 0 { session.severe25WithItemCountChangeCount += 1 }
                        if !hasTrackedGridWork { session.severe25WithNoTrackedGridWorkCount += 1 }
                        if runLoopBeforeWaitingDelta == 0 { session.severe25WithoutRunLoopWaitCount += 1 }
                        else { session.severe25WithRunLoopWaitCount += 1 }
                    }
                    if intervalMS >= 33.3 {
                        session.severe33GapCount += 1
                        if hasCellChurn { session.severe33WithCellChurnCount += 1 }
                        if imagePublishDelta > 0 { session.severe33WithImagePublishCount += 1 }
                        if loadAheadDelta > 0 { session.severe33WithLoadAheadCount += 1 }
                        if itemCountChangeDelta > 0 { session.severe33WithItemCountChangeCount += 1 }
                        if !hasTrackedGridWork { session.severe33WithNoTrackedGridWorkCount += 1 }
                        if runLoopBeforeWaitingDelta == 0 { session.severe33WithoutRunLoopWaitCount += 1 }
                        else { session.severe33WithRunLoopWaitCount += 1 }
                    }
                }
            }
            session.lastDisplayCellAppearCount = session.cellAppearCount
            session.lastDisplayCellDisappearCount = session.cellDisappearCount
            session.lastDisplayLoadAheadCount = session.loadAheadCount
            session.lastDisplayItemCountChanges = session.itemCountChanges
            session.lastDisplayImagePublishCount = session.imagePublishCount
            session.lastDisplayRunLoopBeforeWaitingCount = runLoopBeforeWaitingCount
            session.offsetChangesSinceLastDisplay = 0

            let currentOffsetY = scrollView.contentOffset.y
            if scrollView.isDecelerating {
                if let previousOffsetY = session.lastDecelerationDisplayOffsetY {
                    let deltaY = currentOffsetY - previousOffsetY
                    let absDeltaY = abs(deltaY)
                    session.decelerationDisplayFrameCount += 1
                    if absDeltaY <= 0.01 {
                        session.decelerationDisplayZeroMoveCount += 1
                        session.previousDecelerationDisplayWasZero = true
                    } else {
                        session.decelerationDisplayDeltas.append(Double(absDeltaY))
                        if session.previousDecelerationDisplayWasZero { session.decelerationDisplayCatchUpCount += 1 }
                        if let previousDeltaY = session.lastDecelerationDisplayDeltaY, abs(previousDeltaY) > 0.01 {
                            if deltaY.sign != previousDeltaY.sign { session.decelerationDisplayReverseCount += 1 }
                            else {
                                let stepRatio = abs(Double(absDeltaY - abs(previousDeltaY))) / max(Double(abs(previousDeltaY)), 0.01)
                                if stepRatio < 10 { session.decelerationDisplayStepRatios.append(stepRatio) }
                            }
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
            owner.session = session
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
        let decelerationDelta = valueSummary(session.decelerationDisplayDeltas)
        let decelerationStep = valueSummary(session.decelerationDisplayStepRatios)
        let durationMS = max(0, (endedAt - session.startedAt) * 1000)
        DiagnosticsLogger.shared.app(
            "PosterGridCadence",
            "route=\(owner.route) reason=\(reason) duration_ms=\(format(durationMS)) maximum_fps=\(UIScreen.main.maximumFramesPerSecond) refresh_request=\(refreshRequestActive ? 1 : 0) requested_min_fps=\(UIScreen.main.maximumFramesPerSecond > 60 ? 80 : 0) requested_max_fps=\(UIScreen.main.maximumFramesPerSecond > 60 ? UIScreen.main.maximumFramesPerSecond : 0) offset_samples=\(session.offsetIntervalsMS.count) offset_p50_ms=\(format(offset.p50)) offset_p95_ms=\(format(offset.p95)) offset_p99_ms=\(format(offset.p99)) offset_max_ms=\(format(offset.max)) offset_ge10=\(offset.ge10) offset_ge12_5=\(offset.ge12_5) offset_ge16_7=\(offset.ge16_7) offset_ge25=\(offset.ge25) offset_ge33_3=\(offset.ge33_3) display_samples=\(session.displayIntervalsMS.count) display_p50_ms=\(format(display.p50)) display_p95_ms=\(format(display.p95)) display_p99_ms=\(format(display.p99)) display_max_ms=\(format(display.max)) display_ge10=\(display.ge10) display_ge12_5=\(display.ge12_5) display_ge16_7=\(display.ge16_7) display_ge25=\(display.ge25) display_ge33_3=\(display.ge33_3) drag_samples=\(session.dragSamples) decel_samples=\(session.decelerationSamples) cell_appear=\(session.cellAppearCount) cell_disappear=\(session.cellDisappearCount) load_ahead=\(session.loadAheadCount) item_count_start=\(session.startItemCount) item_count_end=\(owner.itemCount) item_count_changes=\(session.itemCountChanges) max_velocity_y=\(format(Double(session.maxAbsVelocityY))) max_delta_y=\(format(Double(session.maxAbsDeltaY))) decel_display_frames=\(session.decelerationDisplayFrameCount) decel_display_zero=\(session.decelerationDisplayZeroMoveCount) decel_display_catchup=\(session.decelerationDisplayCatchUpCount) decel_display_reverse=\(session.decelerationDisplayReverseCount) decel_delta_p50_pt=\(format(decelerationDelta.p50)) decel_delta_p95_pt=\(format(decelerationDelta.p95)) decel_delta_p99_pt=\(format(decelerationDelta.p99)) decel_delta_max_pt=\(format(decelerationDelta.max)) decel_step_ratio_p50=\(format(decelerationStep.p50)) decel_step_ratio_p95=\(format(decelerationStep.p95)) decel_step_ratio_p99=\(format(decelerationStep.p99)) decel_step_ratio_max=\(format(decelerationStep.max)) image_publish=\(session.imagePublishCount) long_gap_ge12_5=\(session.longDisplayGapCount) long_gap_cell_churn=\(session.longDisplayGapWithCellChurnCount) long_gap_image_publish=\(session.longDisplayGapWithImagePublishCount) long_gap_load_ahead=\(session.longDisplayGapWithLoadAheadCount) long_gap_item_change=\(session.longDisplayGapWithItemCountChangeCount) long_gap_untracked=\(session.longDisplayGapWithNoTrackedGridWorkCount) long_gap_max_cell_appear=\(session.longDisplayGapMaxCellAppearDelta) long_gap_max_cell_disappear=\(session.longDisplayGapMaxCellDisappearDelta) long_gap_max_image_publish=\(session.longDisplayGapMaxImagePublishDelta) long_gap_max_offset_updates=\(session.longDisplayGapMaxOffsetChanges) severe25_ge25=\(session.severe25GapCount) severe25_cell_churn=\(session.severe25WithCellChurnCount) severe25_image_publish=\(session.severe25WithImagePublishCount) severe25_load_ahead=\(session.severe25WithLoadAheadCount) severe25_item_change=\(session.severe25WithItemCountChangeCount) severe25_untracked=\(session.severe25WithNoTrackedGridWorkCount) severe25_no_runloop_wait=\(session.severe25WithoutRunLoopWaitCount) severe25_with_runloop_wait=\(session.severe25WithRunLoopWaitCount) severe33_ge33_3=\(session.severe33GapCount) severe33_cell_churn=\(session.severe33WithCellChurnCount) severe33_image_publish=\(session.severe33WithImagePublishCount) severe33_load_ahead=\(session.severe33WithLoadAheadCount) severe33_item_change=\(session.severe33WithItemCountChangeCount) severe33_untracked=\(session.severe33WithNoTrackedGridWorkCount) severe33_no_runloop_wait=\(session.severe33WithoutRunLoopWaitCount) severe33_with_runloop_wait=\(session.severe33WithRunLoopWaitCount)"
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

    private func valueSummary(_ samples: [Double]) -> (p50: Double, p95: Double, p99: Double, max: Double) {
        guard !samples.isEmpty else { return (-1, -1, -1, -1) }
        let sorted = samples.sorted()
        func percentile(_ value: Double) -> Double {
            let index = min(sorted.count - 1, max(0, Int(ceil(Double(sorted.count) * value)) - 1))
            return sorted[index]
        }
        return (percentile(0.50), percentile(0.95), percentile(0.99), sorted.last ?? -1)
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
