import SwiftUI
import UIKit

private final class V3HomeCarouselImmediateDragRecognizer: UIGestureRecognizer {
    var onBegan: (() -> Void)?
    var onSample: ((CGSize) -> V3HomeCarouselDragAxis?)?
    private var origin: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard touches.count == 1, let touch = touches.first, let view else { state = .failed; return }
        origin = touch.location(in: view)
        onBegan?()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first, let view, let origin else { state = .failed; return }
        let samples = event.coalescedTouches(for: touch) ?? [touch]
        for sample in samples {
            let location = sample.location(in: view)
            let translation = CGSize(width: location.x - origin.x, height: location.y - origin.y)
            let axis = onSample?(translation)
            if axis == .vertical { state = .failed; return }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { state = .failed }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { state = .failed }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    override func reset() {
        super.reset()
        origin = nil
    }
}

struct V3HomeCarouselNativeDragCapture: UIViewRepresentable {
    let onBegan: () -> Void
    let onSample: (CGSize) -> V3HomeCarouselDragAxis?

    func makeCoordinator() -> Coordinator { Coordinator(onBegan: onBegan, onSample: onSample) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        let recognizer = V3HomeCarouselImmediateDragRecognizer()
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = context.coordinator
        recognizer.onBegan = { context.coordinator.onBegan() }
        recognizer.onSample = { context.coordinator.onSample($0) }
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onBegan = onBegan
        context.coordinator.onSample = onSample
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onBegan: () -> Void
        var onSample: (CGSize) -> V3HomeCarouselDragAxis?

        init(onBegan: @escaping () -> Void, onSample: @escaping (CGSize) -> V3HomeCarouselDragAxis?) {
            self.onBegan = onBegan
            self.onSample = onSample
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
    }
}

extension V3EmbyHomeView {
    func beginNativeCarouselDrag() {
        carouselTransitionState.dragAxis = nil
        carouselTransitionState.resetDragDiagnostics()
    }

    @discardableResult
    func handleNativeCarouselDrag(_ translation: CGSize, width: CGFloat) -> V3HomeCarouselDragAxis? {
        carouselTransitionState.recordDragSample(translation)
        let horizontal = translation.width
        let vertical = translation.height
        if carouselTransitionState.dragAxis == nil {
            guard max(abs(horizontal), abs(vertical)) >= 0.5 else { return nil }
            carouselTransitionState.dragAxis = abs(horizontal) >= abs(vertical) ? .horizontal : .vertical
            carouselTransitionState.recordDragAxisLock(translation)
        }
        guard carouselTransitionState.dragAxis == .horizontal else { return carouselTransitionState.dragAxis }
        suppressCarouselTap()
        guard transitionToID == nil || isCarouselDragging else { return .horizontal }
        let direction = horizontal < 0 ? 1 : -1
        guard let currentID = currentCarouselItemID, let targetID = neighborCarouselItemID(from: currentID, direction: direction) else { return .horizontal }
        if !isCarouselDragging || transitionFromID != currentID || transitionToID != targetID {
            carouselTransitionState.recordDragTransitionStart(translation)
            transitionFromID = currentID
            transitionToID = targetID
            transitionProgress = 0
            transitionDirection = direction
            isCarouselDragging = true
        }
        transitionProgress = min(1, max(0, abs(horizontal) / max(1, width)))
        return .horizontal
    }
}
