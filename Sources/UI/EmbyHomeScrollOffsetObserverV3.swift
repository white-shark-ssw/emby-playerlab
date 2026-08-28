import SwiftUI
import UIKit
import Foundation
import QuartzCore

final class V3HomeVerticalMotionDiagnostics: NSObject {
    static let shared = V3HomeVerticalMotionDiagnostics()

    private struct CarouselEvent {
        let itemID: String
        let timestamp: CFTimeInterval
        let durationMS: Double
    }

    private weak var scrollView: UIScrollView?
    private var displayLink: CADisplayLink?
    private var lastDisplayTimestamp: CFTimeInterval?
    private var lastOffsetY: CGFloat?
    private var lastContentHeight: CGFloat?
    private var lastAdjustedTopInset: CGFloat?
    private var lastAutoAdvanceAt: CFTimeInterval?
    private var lastAutoAdvanceTargetID: String?
    private var lastSettle: CarouselEvent?

    private override init() {}

    func observe(_ scrollView: UIScrollView) {
        precondition(Thread.isMainThread)
        if self.scrollView !== scrollView {
            self.scrollView = scrollView
            lastDisplayTimestamp = nil
            lastOffsetY = scrollView.contentOffset.y
            lastContentHeight = scrollView.contentSize.height
            lastAdjustedTopInset = scrollView.adjustedContentInset.top
        }
        ensureDisplayLink()
    }

    func stopObserving(_ scrollView: UIScrollView) {
        precondition(Thread.isMainThread)
        guard self.scrollView === scrollView else { return }
        self.scrollView = nil
        displayLink?.invalidate()
        displayLink = nil
        lastDisplayTimestamp = nil
        lastOffsetY = nil
        lastContentHeight = nil
        lastAdjustedTopInset = nil
    }

    func carouselAutoAdvanceDidStart(fromID: String, toID: String) {
        precondition(Thread.isMainThread)
        lastAutoAdvanceAt = CACurrentMediaTime()
        lastAutoAdvanceTargetID = toID
        DiagnosticsLogger.shared.log("HomeCarouselTiming", "auto_start from=\(fromID) to=\(toID) \(scrollStateText())")
    }

    func carouselSettleDidStart(itemID: String) -> CFTimeInterval {
        precondition(Thread.isMainThread)
        let startedAt = CACurrentMediaTime()
        let autoAgeMS = lastAutoAdvanceAt.map { max(0, (startedAt - $0) * 1000) } ?? -1
        DiagnosticsLogger.shared.log("HomeCarouselTiming", "settle_start item=\(itemID) auto_target=\(lastAutoAdvanceTargetID ?? \"none\") auto_age_ms=\(String(format: \"%.1f\", autoAgeMS)) \(scrollStateText())")
        return startedAt
    }

    func carouselSettleDidComplete(itemID: String, startedAt: CFTimeInterval) {
        precondition(Thread.isMainThread)
        let completedAt = CACurrentMediaTime()
        let durationMS = max(0, (completedAt - startedAt) * 1000)
        lastSettle = CarouselEvent(itemID: itemID, timestamp: startedAt, durationMS: durationMS)
        let autoAgeMS = lastAutoAdvanceAt.map { max(0, (completedAt - $0) * 1000) } ?? -1
        DiagnosticsLogger.shared.log("HomeCarouselTiming", "settle_end item=\(itemID) duration_ms=\(String(format: \"%.1f\", durationMS)) auto_target=\(lastAutoAdvanceTargetID ?? \"none\") auto_age_ms=\(String(format: \"%.1f\", autoAgeMS)) \(scrollStateText())")
    }

    private func ensureDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(displayLinkTick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func displayLinkTick(_ link: CADisplayLink) {
        guard let scrollView else { return }
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let adjustedTopInset = scrollView.adjustedContentInset.top
        guard let previousTimestamp = lastDisplayTimestamp else {
            lastDisplayTimestamp = link.timestamp
            lastOffsetY = offsetY
            lastContentHeight = contentHeight
            lastAdjustedTopInset = adjustedTopInset
            return
        }

        let gap = max(0, link.timestamp - previousTimestamp)
        let deltaY = offsetY - (lastOffsetY ?? offsetY)
        let contentDelta = contentHeight - (lastContentHeight ?? contentHeight)
        let insetDelta = adjustedTopInset - (lastAdjustedTopInset ?? adjustedTopInset)
        lastDisplayTimestamp = link.timestamp
        lastOffsetY = offsetY
        lastContentHeight = contentHeight
        lastAdjustedTopInset = adjustedTopInset

        let moving = scrollView.isDragging || scrollView.isDecelerating || abs(deltaY) >= 0.5
        let layoutShift = abs(contentDelta) >= 1 || abs(insetDelta) >= 0.5
        guard moving, gap >= 0.018 || layoutShift else { return }

        let now = link.timestamp
        let autoAgeMS = lastAutoAdvanceAt.map { max(0, (now - $0) * 1000) } ?? -1
        let settleAgeMS = lastSettle.map { max(0, (now - $0.timestamp) * 1000) } ?? -1
        let phase = scrollView.isDragging ? "dragging" : (scrollView.isDecelerating ? "decelerating" : "moving")
        let gapText = String(format: "%.1f", gap * 1000)
        let offsetText = String(format: "%.2f", offsetY)
        let deltaText = String(format: "%.2f", deltaY)
        let velocityText = String(format: "%.1f", scrollView.panGestureRecognizer.velocity(in: scrollView).y)
        let contentHeightText = String(format: "%.1f", contentHeight)
        let contentDeltaText = String(format: "%.1f", contentDelta)
        let insetText = String(format: "%.1f", adjustedTopInset)
        let insetDeltaText = String(format: "%.1f", insetDelta)
        let autoAgeText = String(format: "%.1f", autoAgeMS)
        let settleAgeText = String(format: "%.1f", settleAgeMS)
        let settleDurationText = String(format: "%.1f", lastSettle?.durationMS ?? -1)
        let settleItemID = lastSettle?.itemID ?? "none"
        DiagnosticsLogger.shared.log("HomeVerticalHitch", "gap_ms=\(gapText) phase=\(phase) offset_y=\(offsetText) delta_y=\(deltaText) velocity_y=\(velocityText) content_h=\(contentHeightText) content_delta_h=\(contentDeltaText) inset_top=\(insetText) inset_delta_top=\(insetDeltaText) auto_target=\(lastAutoAdvanceTargetID ?? \"none\") auto_age_ms=\(autoAgeText) settle_item=\(settleItemID) settle_age_ms=\(settleAgeText) settle_duration_ms=\(settleDurationText)")
    }

    private func scrollStateText() -> String {
        guard let scrollView else { return "phase=none offset_y=-1.00 velocity_y=0.0" }
        let phase = scrollView.isDragging ? "dragging" : (scrollView.isDecelerating ? "decelerating" : "idle")
        let offsetText = String(format: "%.2f", scrollView.contentOffset.y)
        let velocityText = String(format: "%.1f", scrollView.panGestureRecognizer.velocity(in: scrollView).y)
        return "phase=\(phase) offset_y=\(offsetText) velocity_y=\(velocityText)"
    }
}

final class V3HomeScrollOffsetProbeView: UIView {
    var hierarchyDidChange: ((UIView) -> Void)?

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        hierarchyDidChange?(self)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        hierarchyDidChange?(self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        hierarchyDidChange?(self)
    }
}

struct V3HomeScrollOffsetObserver: UIViewRepresentable {
    let onChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeUIView(context: Context) -> V3HomeScrollOffsetProbeView {
        let view = V3HomeScrollOffsetProbeView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.hierarchyDidChange = { [weak coordinator = context.coordinator] probe in coordinator?.attach(from: probe) }
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak view] in
            guard let view else { return }
            coordinator?.attach(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: V3HomeScrollOffsetProbeView, context: Context) {
        context.coordinator.onChange = onChange
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak uiView] in
            guard let uiView else { return }
            coordinator?.attach(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: V3HomeScrollOffsetProbeView, coordinator: Coordinator) {
        uiView.hierarchyDidChange = nil
        coordinator.detach()
    }

    final class Coordinator {
        var onChange: (CGFloat) -> Void
        private weak var scrollView: UIScrollView?
        private var contentOffsetObservation: NSKeyValueObservation?
        private var restingAdjustedTopInset: CGFloat?
        private var lastUserPullDisplacement: CGFloat?

        init(onChange: @escaping (CGFloat) -> Void) { self.onChange = onChange }

        func attach(from probe: UIView) {
            guard let scrollView = ancestorVerticalScrollView(from: probe) else { return }
            if self.scrollView !== scrollView {
                if let existingScrollView = self.scrollView { V3HomeVerticalMotionDiagnostics.shared.stopObserving(existingScrollView) }
                contentOffsetObservation?.invalidate()
                self.scrollView = scrollView
                restingAdjustedTopInset = nil
                lastUserPullDisplacement = nil
                scrollView.alwaysBounceVertical = true
                contentOffsetObservation = scrollView.observe(\.contentOffset, options: [.initial, .new]) { [weak self] scrollView, _ in self?.emit(scrollView) }
            }
            V3HomeVerticalMotionDiagnostics.shared.observe(scrollView)
            rebaseRestingInsetIfIdle(scrollView)
            emit(scrollView)
        }

        func detach() {
            if let scrollView { V3HomeVerticalMotionDiagnostics.shared.stopObserving(scrollView) }
            contentOffsetObservation?.invalidate()
            contentOffsetObservation = nil
            scrollView = nil
            restingAdjustedTopInset = nil
            lastUserPullDisplacement = nil
        }

        private func rebaseRestingInsetIfIdle(_ scrollView: UIScrollView) {
            guard !scrollView.isDragging, !scrollView.isDecelerating, scrollView.refreshControl?.isRefreshing != true else { return }
            restingAdjustedTopInset = scrollView.adjustedContentInset.top
        }

        private func ancestorVerticalScrollView(from probe: UIView) -> UIScrollView? {
            var current: UIView? = probe
            while let view = current {
                if let scrollView = view as? UIScrollView, !scrollView.isPagingEnabled { return scrollView }
                current = view.superview
            }
            return nil
        }

        private func emit(_ scrollView: UIScrollView) {
            let refreshing = scrollView.refreshControl?.isRefreshing == true
            if !scrollView.isDragging, !scrollView.isDecelerating, !refreshing { restingAdjustedTopInset = scrollView.adjustedContentInset.top }
            let topInset = restingAdjustedTopInset ?? scrollView.adjustedContentInset.top
            let rawDisplacement = -(scrollView.contentOffset.y + topInset)
            var output = rawDisplacement

            if scrollView.isDragging, rawDisplacement > 0 {
                if refreshing {
                    let pinned = max(lastUserPullDisplacement ?? rawDisplacement, rawDisplacement)
                    lastUserPullDisplacement = pinned
                    output = pinned
                } else {
                    lastUserPullDisplacement = rawDisplacement
                }
            } else if refreshing, let pinned = lastUserPullDisplacement {
                output = max(rawDisplacement, pinned)
            } else if !refreshing, !scrollView.isDragging {
                lastUserPullDisplacement = nil
            }

            if Thread.isMainThread { onChange(output) }
            else { DispatchQueue.main.async { [weak self] in self?.onChange(output) } }
        }
    }
}
