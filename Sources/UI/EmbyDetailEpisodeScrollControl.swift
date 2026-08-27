import SwiftUI
import UIKit

final class EmbyDetailEpisodeScrollController: ObservableObject {
    private weak var probeView: UIView?
    private weak var scrollView: UIScrollView?

    func attach(from probe: UIView) {
        precondition(Thread.isMainThread)
        guard let scrollView = ancestorScrollView(from: probe) else { return }
        probeView = probe
        self.scrollView = scrollView
    }

    func detach(from probe: UIView) {
        precondition(Thread.isMainThread)
        guard probeView === probe else { return }
        probeView = nil
        scrollView = nil
    }

    @discardableResult
    func stopDeceleration() -> Bool {
        precondition(Thread.isMainThread)
        guard let scrollView, scrollView.isDecelerating else { return false }
        scrollView.setContentOffset(scrollView.contentOffset, animated: false)
        return true
    }

    private func ancestorScrollView(from probe: UIView) -> UIScrollView? {
        var current: UIView? = probe
        while let view = current {
            if let scrollView = view as? UIScrollView { return scrollView }
            current = view.superview
        }
        return nil
    }
}

private final class EmbyDetailEpisodeScrollProbeUIView: UIView {
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

struct EmbyDetailEpisodeNativeScrollProbe: UIViewRepresentable {
    let controller: EmbyDetailEpisodeScrollController

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    func makeUIView(context: Context) -> EmbyDetailEpisodeScrollProbeUIView {
        let view = EmbyDetailEpisodeScrollProbeUIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.hierarchyDidChange = { [weak coordinator = context.coordinator] probe in coordinator?.attach(from: probe) }
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak view] in
            guard let view else { return }
            coordinator?.attach(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: EmbyDetailEpisodeScrollProbeUIView, context: Context) {
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak uiView] in
            guard let uiView else { return }
            coordinator?.attach(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: EmbyDetailEpisodeScrollProbeUIView, coordinator: Coordinator) {
        uiView.hierarchyDidChange = nil
        coordinator.detach(from: uiView)
    }

    final class Coordinator {
        private let controller: EmbyDetailEpisodeScrollController

        init(controller: EmbyDetailEpisodeScrollController) { self.controller = controller }
        func attach(from probe: UIView) { controller.attach(from: probe) }
        func detach(from probe: UIView) { controller.detach(from: probe) }
    }
}
