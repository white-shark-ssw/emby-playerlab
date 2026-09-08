import QuartzCore
import SwiftUI
import UIKit

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

    final class Coordinator: NSObject {
        private struct MotionSession {
            let startedAt: CFTimeInterval
            var displayIntervalsMS: [Double] = []
        }

        var onChange: (CGFloat) -> Void
        private weak var scrollView: UIScrollView?
        private var contentOffsetObservation: NSKeyValueObservation?
        private var restingAdjustedTopInset: CGFloat?
        private var lastUserPullDisplacement: CGFloat?
        private var displayLink: CADisplayLink?
        private var lastDisplayTimestamp: CFTimeInterval?
        private var motionSession: MotionSession?
        private var refreshRequestActive = false

        init(onChange: @escaping (CGFloat) -> Void) {
            self.onChange = onChange
            super.init()
        }

        func attach(from probe: UIView) {
            guard let scrollView = ancestorVerticalScrollView(from: probe) else { return }
            if self.scrollView !== scrollView {
                finishMotionSession(reason: "scroll-replaced")
                contentOffsetObservation?.invalidate()
                stopDisplayLink()
                self.scrollView = scrollView
                restingAdjustedTopInset = nil
                lastUserPullDisplacement = nil
                scrollView.alwaysBounceVertical = true
                contentOffsetObservation = scrollView.observe(\.contentOffset, options: [.initial, .new]) { [weak self] scrollView, _ in self?.emit(scrollView) }
                ensureDisplayLink()
            }
            rebaseRestingInsetIfIdle(scrollView)
            emit(scrollView)
        }

        func detach() {
            finishMotionSession(reason: "home-disappear")
            contentOffsetObservation?.invalidate()
            contentOffsetObservation = nil
            scrollView = nil
            restingAdjustedTopInset = nil
            lastUserPullDisplacement = nil
            stopDisplayLink()
        }

        private func ensureDisplayLink() {
            guard displayLink == nil else { return }
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

        private func updateMotionState(_ scrollView: UIScrollView) {
            guard motionSession == nil, scrollView.isDragging || scrollView.isDecelerating else { return }
            motionSession = MotionSession(startedAt: CACurrentMediaTime())
            lastDisplayTimestamp = nil
            updateRefreshRateRequest()
        }

        private func updateRefreshRateRequest() {
            guard let displayLink else { return }
            let maximumFPS = max(60, UIScreen.main.maximumFramesPerSecond)
            let shouldRequest = maximumFPS > 60 && motionSession != nil
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
            guard let scrollView else { return }
            guard var session = motionSession else {
                lastDisplayTimestamp = nil
                return
            }
            if let previous = lastDisplayTimestamp {
                let intervalMS = max(0, (link.timestamp - previous) * 1000)
                if intervalMS > 0, intervalMS < 200 { session.displayIntervalsMS.append(intervalMS) }
            }
            lastDisplayTimestamp = link.timestamp
            motionSession = session
            if !scrollView.isDragging && !scrollView.isDecelerating { finishMotionSession(reason: "motion-ended", endedAt: link.timestamp) }
        }

        private func finishMotionSession(reason: String, endedAt: CFTimeInterval = CACurrentMediaTime()) {
            guard let session = motionSession else { return }
            let display = intervalSummary(session.displayIntervalsMS)
            let durationMS = max(0, (endedAt - session.startedAt) * 1000)
            DiagnosticsLogger.shared.app(
                "HomeScrollCadence",
                "reason=\(reason) duration_ms=\(format(durationMS)) maximum_fps=\(UIScreen.main.maximumFramesPerSecond) refresh_request=\(refreshRequestActive ? 1 : 0) requested_min_fps=\(UIScreen.main.maximumFramesPerSecond > 60 ? 80 : 0) requested_max_fps=\(UIScreen.main.maximumFramesPerSecond > 60 ? UIScreen.main.maximumFramesPerSecond : 0) display_samples=\(session.displayIntervalsMS.count) display_p50_ms=\(format(display.p50)) display_p95_ms=\(format(display.p95)) display_p99_ms=\(format(display.p99)) display_max_ms=\(format(display.max)) display_ge10=\(display.ge10) display_ge12_5=\(display.ge12_5) display_ge16_7=\(display.ge16_7) display_ge25=\(display.ge25) display_ge33_3=\(display.ge33_3)"
            )
            motionSession = nil
            lastDisplayTimestamp = nil
            updateRefreshRateRequest()
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
            updateMotionState(scrollView)
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
