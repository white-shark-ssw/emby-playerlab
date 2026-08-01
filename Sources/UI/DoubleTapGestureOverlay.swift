import SwiftUI
import UIKit

struct DoubleTapGestureOverlay: UIViewRepresentable {
    let onLeftDoubleTap: () -> Void
    let onRightDoubleTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLeftDoubleTap: onLeftDoubleTap, onRightDoubleTap: onRightDoubleTap)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let recognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        recognizer.numberOfTapsRequired = 2
        recognizer.numberOfTouchesRequired = 1
        recognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onLeftDoubleTap = onLeftDoubleTap
        context.coordinator.onRightDoubleTap = onRightDoubleTap
    }

    final class Coordinator: NSObject {
        var onLeftDoubleTap: () -> Void
        var onRightDoubleTap: () -> Void

        init(onLeftDoubleTap: @escaping () -> Void, onRightDoubleTap: @escaping () -> Void) {
            self.onLeftDoubleTap = onLeftDoubleTap
            self.onRightDoubleTap = onRightDoubleTap
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let location = recognizer.location(in: view)
            if location.x < view.bounds.midX {
                onLeftDoubleTap()
            } else {
                onRightDoubleTap()
            }
        }
    }
}
