import SwiftUI
import UIKit

// Read-only observation of the actual detail scroll view; no delegate/gesture/offset or layout ownership.
struct EmbyDetailScrollDiagnostics: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.changed = { [weak coordinator = context.coordinator] probe in coordinator?.attach(probe) }
        return view
    }
    func updateUIView(_ view: Probe, context: Context) { context.coordinator.attach(view) }
    static func dismantleUIView(_ view: Probe, coordinator: Coordinator) { view.changed = nil; coordinator.stop() }

    final class Probe: UIView {
        var changed: ((Probe) -> Void)?
        override func didMoveToWindow() { super.didMoveToWindow(); changed?(self) }
        override func didMoveToSuperview() { super.didMoveToSuperview(); changed?(self) }
        override func layoutSubviews() { super.layoutSubviews(); changed?(self) }
    }

    final class Coordinator: NSObject {
        private weak var scroll: UIScrollView?
        private weak var controller: UIViewController?
        private var link: CADisplayLink?
        private let identity = String(UUID().uuidString.prefix(8))
        private var started: CFTimeInterval = 0
        private var previousFrame: CFTimeInterval = 0
        private var maximumGap: Double = 0
        private var samples = 0
        private var over25 = 0
        private var events = 0
        private var lastPan = -1
        private var lastHeight: CGFloat = -1
        private var initialOffset: CGFloat = 0
        private var moved = false
        private var completed = false

        func attach(_ probe: Probe) {
            guard probe.window != nil else { stop(); return }
            var ancestor = probe.superview
            while let view = ancestor, !(view is UIScrollView) { ancestor = view.superview }
            guard let target = ancestor as? UIScrollView else { return }
            guard scroll !== target || (!completed && link == nil) else { return }
            stop()
            scroll = target
            var responder: UIResponder? = probe
            while let value = responder, !(value is UIViewController) { responder = value.next }
            controller = responder as? UIViewController
            started = CACurrentMediaTime(); previousFrame = 0; maximumGap = 0; samples = 0; over25 = 0
            events = 0; lastPan = -1; lastHeight = -1; initialOffset = target.contentOffset.y; moved = false; completed = false
            report("attach")
            let display = CADisplayLink(target: self, selector: #selector(tick(_:)))
            link = display; display.add(to: .main, forMode: .common)
            controller?.transitionCoordinator?.animate(alongsideTransition: nil) { [weak self] context in
                self?.report(context.isCancelled ? "transition-cancelled" : "transition-complete")
            }
        }

        @objc private func tick(_ display: CADisplayLink) {
            guard let scroll else { stop(); return }
            if previousFrame > 0 {
                let gap = (display.timestamp - previousFrame) * 1000
                maximumGap = max(maximumGap, gap); samples += 1
                if gap >= 25 { over25 += 1 }
            }
            previousFrame = display.timestamp
            let pan = scroll.panGestureRecognizer.state.rawValue
            if pan != lastPan { lastPan = pan; report("pan") }
            if abs(scroll.contentSize.height - lastHeight) > 1 { lastHeight = scroll.contentSize.height; report("extent") }
            if !moved && abs(scroll.contentOffset.y - initialOffset) > 1 { moved = true; report("first-offset") }
            if CACurrentMediaTime() - started >= 3 { completed = true; stop() }
        }

        private func report(_ event: String) {
            guard events < 32, let scroll else { return }
            events += 1
            let inset = scroll.adjustedContentInset
            let maximum = max(-inset.top, scroll.contentSize.height - scroll.bounds.height + inset.bottom)
            DiagnosticsLogger.shared.log("DetailScroll", "event=\(event) probe=\(identity) elapsed_ms=\((CACurrentMediaTime() - started) * 1000) offset=\(scroll.contentOffset.y) content_height=\(scroll.contentSize.height) viewport=\(scroll.bounds.height) top=\(inset.top) bottom=\(inset.bottom) max_offset=\(maximum) enabled=\(scroll.isScrollEnabled ? 1 : 0) tracking=\(scroll.isTracking ? 1 : 0) dragging=\(scroll.isDragging ? 1 : 0) decelerating=\(scroll.isDecelerating ? 1 : 0) pan=\(scroll.panGestureRecognizer.state.rawValue) transition=\(controller?.transitionCoordinator != nil ? 1 : 0) samples=\(samples) max_gap_ms=\(maximumGap) ge25=\(over25)")
        }

        func stop() {
            guard link != nil else { return }
            report("finish"); link?.invalidate(); link = nil; completed = true
        }
    }
}
