import SwiftUI
import UIKit

struct PlaybackGestureOverlay: UIViewRepresentable {
    let onLeftDoubleTap: () -> Void
    let onRightDoubleTap: () -> Void
    let onHorizontalPanBegan: () -> Void
    let onHorizontalPanChanged: (_ translationX: CGFloat, _ viewWidth: CGFloat) -> Void
    let onHorizontalPanEnded: () -> Void
    let onHorizontalPanCancelled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onLeftDoubleTap: onLeftDoubleTap,
            onRightDoubleTap: onRightDoubleTap,
            onHorizontalPanBegan: onHorizontalPanBegan,
            onHorizontalPanChanged: onHorizontalPanChanged,
            onHorizontalPanEnded: onHorizontalPanEnded,
            onHorizontalPanCancelled: onHorizontalPanCancelled
        )
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.numberOfTouchesRequired = 1
        doubleTap.cancelsTouchesInView = false
        doubleTap.delegate = context.coordinator
        view.addGestureRecognizer(doubleTap)

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = false
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onLeftDoubleTap = onLeftDoubleTap
        context.coordinator.onRightDoubleTap = onRightDoubleTap
        context.coordinator.onHorizontalPanBegan = onHorizontalPanBegan
        context.coordinator.onHorizontalPanChanged = onHorizontalPanChanged
        context.coordinator.onHorizontalPanEnded = onHorizontalPanEnded
        context.coordinator.onHorizontalPanCancelled = onHorizontalPanCancelled
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onLeftDoubleTap: () -> Void
        var onRightDoubleTap: () -> Void
        var onHorizontalPanBegan: () -> Void
        var onHorizontalPanChanged: (_ translationX: CGFloat, _ viewWidth: CGFloat) -> Void
        var onHorizontalPanEnded: () -> Void
        var onHorizontalPanCancelled: () -> Void

        init(
            onLeftDoubleTap: @escaping () -> Void,
            onRightDoubleTap: @escaping () -> Void,
            onHorizontalPanBegan: @escaping () -> Void,
            onHorizontalPanChanged: @escaping (_ translationX: CGFloat, _ viewWidth: CGFloat) -> Void,
            onHorizontalPanEnded: @escaping () -> Void,
            onHorizontalPanCancelled: @escaping () -> Void
        ) {
            self.onLeftDoubleTap = onLeftDoubleTap
            self.onRightDoubleTap = onRightDoubleTap
            self.onHorizontalPanBegan = onHorizontalPanBegan
            self.onHorizontalPanChanged = onHorizontalPanChanged
            self.onHorizontalPanEnded = onHorizontalPanEnded
            self.onHorizontalPanCancelled = onHorizontalPanCancelled
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let location = recognizer.location(in: view)
            location.x < view.bounds.midX ? onLeftDoubleTap() : onRightDoubleTap()
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            switch recognizer.state {
            case .began:
                onHorizontalPanBegan()
            case .changed:
                onHorizontalPanChanged(recognizer.translation(in: view).x, max(view.bounds.width, 1))
            case .ended:
                onHorizontalPanEnded()
            case .cancelled, .failed:
                onHorizontalPanCancelled()
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  let view = pan.view else { return true }
            let velocity = pan.velocity(in: view)
            return abs(velocity.x) > 40 && abs(velocity.x) > abs(velocity.y) * 1.2
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }
    }
}
