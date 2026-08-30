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
    let onScrollViewChange: (UIScrollView?) -> Void
    let onChange: (CGFloat) -> Void

    init(onScrollViewChange: @escaping (UIScrollView?) -> Void = { _ in }, onChange: @escaping (CGFloat) -> Void) {
        self.onScrollViewChange = onScrollViewChange
        self.onChange = onChange
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScrollViewChange: onScrollViewChange, onChange: onChange) }

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
        context.coordinator.onScrollViewChange = onScrollViewChange
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
        var onScrollViewChange: (UIScrollView?) -> Void
        var onChange: (CGFloat) -> Void
        private weak var scrollView: UIScrollView?
        private var contentOffsetObservation: NSKeyValueObservation?
        private var restingAdjustedTopInset: CGFloat?
        private var lastUserPullDisplacement: CGFloat?

        init(onScrollViewChange: @escaping (UIScrollView?) -> Void, onChange: @escaping (CGFloat) -> Void) {
            self.onScrollViewChange = onScrollViewChange
            self.onChange = onChange
        }

        func attach(from probe: UIView) {
            guard let scrollView = ancestorVerticalScrollView(from: probe) else { return }
            if self.scrollView !== scrollView {
                contentOffsetObservation?.invalidate()
                self.scrollView = scrollView
                onScrollViewChange(scrollView)
                restingAdjustedTopInset = nil
                lastUserPullDisplacement = nil
                scrollView.alwaysBounceVertical = true
                contentOffsetObservation = scrollView.observe(\.contentOffset, options: [.initial, .new]) { [weak self] scrollView, _ in self?.emit(scrollView) }
            }
            rebaseRestingInsetIfIdle(scrollView)
            emit(scrollView)
        }

        func detach() {
            contentOffsetObservation?.invalidate()
            contentOffsetObservation = nil
            onScrollViewChange(nil)
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
