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
    let lifecycleGeneration: Int
    let onChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(lifecycleGeneration: lifecycleGeneration, onChange: onChange) }

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
        context.coordinator.update(lifecycleGeneration: lifecycleGeneration, onChange: onChange)
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
        private var lifecycleGeneration: Int
        private weak var scrollView: UIScrollView?
        private var contentOffsetObservation: NSKeyValueObservation?
        private var restingAdjustedTopInset: CGFloat?
        private var needsRestingInsetRebase = true

        init(lifecycleGeneration: Int, onChange: @escaping (CGFloat) -> Void) {
            self.lifecycleGeneration = lifecycleGeneration
            self.onChange = onChange
        }

        func update(lifecycleGeneration: Int, onChange: @escaping (CGFloat) -> Void) {
            self.onChange = onChange
            guard self.lifecycleGeneration != lifecycleGeneration else { return }
            self.lifecycleGeneration = lifecycleGeneration
            needsRestingInsetRebase = true
        }

        func attach(from probe: UIView) {
            guard let scrollView = ancestorVerticalScrollView(from: probe) else { return }
            if self.scrollView !== scrollView {
                contentOffsetObservation?.invalidate()
                self.scrollView = scrollView
                needsRestingInsetRebase = true
                scrollView.alwaysBounceVertical = true
                contentOffsetObservation = scrollView.observe(\.contentOffset, options: [.initial, .new]) { [weak self] scrollView, _ in self?.emit(scrollView) }
            }
            rebaseRestingInsetIfNeeded(scrollView)
            emit(scrollView)
        }

        private func rebaseRestingInsetIfNeeded(_ scrollView: UIScrollView) {
            guard needsRestingInsetRebase, scrollView.refreshControl?.isRefreshing != true else { return }
            restingAdjustedTopInset = scrollView.adjustedContentInset.top
            needsRestingInsetRebase = false
        }

        func detach() {
            contentOffsetObservation?.invalidate()
            contentOffsetObservation = nil
            scrollView = nil
            restingAdjustedTopInset = nil
            needsRestingInsetRebase = true
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
            let topInset = restingAdjustedTopInset ?? scrollView.adjustedContentInset.top
            let rawDisplacement = -(scrollView.contentOffset.y + topInset)
            if Thread.isMainThread { onChange(rawDisplacement) }
            else { DispatchQueue.main.async { [weak self] in self?.onChange(rawDisplacement) } }
        }
    }
}
