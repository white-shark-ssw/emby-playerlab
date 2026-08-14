import SwiftUI
import UIKit

final class V3HomeRefreshStyleProbeView: UIView {
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

struct V3HomeRefreshControlStyler: UIViewRepresentable {
    let immersive: Bool

    func makeCoordinator() -> Coordinator { Coordinator(immersive: immersive) }

    func makeUIView(context: Context) -> V3HomeRefreshStyleProbeView {
        let view = V3HomeRefreshStyleProbeView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.hierarchyDidChange = { [weak coordinator = context.coordinator] probe in coordinator?.attach(from: probe) }
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak view] in
            guard let view else { return }
            coordinator?.attach(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: V3HomeRefreshStyleProbeView, context: Context) {
        context.coordinator.immersive = immersive
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak uiView] in
            guard let uiView else { return }
            coordinator?.attach(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: V3HomeRefreshStyleProbeView, coordinator: Coordinator) {
        uiView.hierarchyDidChange = nil
        coordinator.detach()
    }

    final class Coordinator: NSObject {
        var immersive: Bool
        private weak var refreshControl: UIRefreshControl?

        init(immersive: Bool) { self.immersive = immersive }

        func attach(from probe: UIView) {
            guard let scrollView = ancestorVerticalScrollView(from: probe), let refreshControl = scrollView.refreshControl else { return }
            if self.refreshControl !== refreshControl {
                self.refreshControl?.removeTarget(self, action: #selector(refreshTriggered), for: .valueChanged)
                self.refreshControl = refreshControl
                refreshControl.addTarget(self, action: #selector(refreshTriggered), for: .valueChanged)
            }
            refreshControl.tintColor = immersive ? UIColor.white.withAlphaComponent(0.96) : UIColor.label
            refreshControl.backgroundColor = .clear
            refreshControl.alpha = 1
            refreshControl.isHidden = false
            refreshControl.layer.zPosition = 1000
            scrollView.bringSubviewToFront(refreshControl)
        }

        func detach() {
            refreshControl?.removeTarget(self, action: #selector(refreshTriggered), for: .valueChanged)
            refreshControl = nil
        }

        @objc private func refreshTriggered() {
            let feedback = UIImpactFeedbackGenerator(style: .light)
            feedback.prepare()
            feedback.impactOccurred(intensity: 0.55)
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

struct V3HomeOwnedRefreshControl: UIViewRepresentable {
    let onRefresh: (@escaping () -> Void) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onRefresh: onRefresh) }

    func makeUIView(context: Context) -> V3HomeRefreshStyleProbeView {
        let view = V3HomeRefreshStyleProbeView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.hierarchyDidChange = { [weak coordinator = context.coordinator] probe in coordinator?.attach(from: probe) }
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak view] in
            guard let view else { return }
            coordinator?.attach(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: V3HomeRefreshStyleProbeView, context: Context) {
        context.coordinator.onRefresh = onRefresh
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak uiView] in
            guard let uiView else { return }
            coordinator?.attach(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: V3HomeRefreshStyleProbeView, coordinator: Coordinator) {
        uiView.hierarchyDidChange = nil
        coordinator.detach()
    }

    final class Coordinator: NSObject {
        var onRefresh: (@escaping () -> Void) -> Void
        private weak var scrollView: UIScrollView?
        private let refreshControl = UIRefreshControl()

        init(onRefresh: @escaping (@escaping () -> Void) -> Void) {
            self.onRefresh = onRefresh
            super.init()
            refreshControl.addTarget(self, action: #selector(refreshTriggered), for: .valueChanged)
        }

        func attach(from probe: UIView) {
            guard let scrollView = ancestorVerticalScrollView(from: probe) else { return }
            if self.scrollView !== scrollView {
                if let old = self.scrollView, old.refreshControl === refreshControl { old.refreshControl = nil }
                self.scrollView = scrollView
            }
            if scrollView.refreshControl !== refreshControl { scrollView.refreshControl = refreshControl }
            refreshControl.tintColor = UIColor.white.withAlphaComponent(0.96)
            refreshControl.backgroundColor = .clear
            refreshControl.alpha = 1
            refreshControl.isHidden = false
            refreshControl.layer.zPosition = 1000
            scrollView.bringSubviewToFront(refreshControl)
        }

        func detach() {
            if let scrollView, scrollView.refreshControl === refreshControl { scrollView.refreshControl = nil }
            self.scrollView = nil
            refreshControl.endRefreshing()
        }

        @objc private func refreshTriggered() {
            let feedback = UIImpactFeedbackGenerator(style: .light)
            feedback.prepare()
            feedback.impactOccurred(intensity: 0.55)
            onRefresh { [weak refreshControl] in
                DispatchQueue.main.async { refreshControl?.endRefreshing() }
            }
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
