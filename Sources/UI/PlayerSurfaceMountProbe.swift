import SwiftUI
import UIKit

struct PlayerSurfaceMountProbe: UIViewRepresentable {
    let onMounted: () -> Void

    func makeUIView(context: Context) -> MountProbeView {
        MountProbeView(onMounted: onMounted)
    }

    func updateUIView(_ uiView: MountProbeView, context: Context) {
        uiView.onMounted = onMounted
        uiView.reportIfMounted()
    }

    final class MountProbeView: UIView {
        var onMounted: () -> Void
        private var reportedWindow: UIWindow?

        init(onMounted: @escaping () -> Void) {
            self.onMounted = onMounted
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            backgroundColor = .clear
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            reportIfMounted()
        }

        func reportIfMounted() {
            guard let window, reportedWindow !== window else { return }
            reportedWindow = window
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window === window else { return }
                self.onMounted()
            }
        }
    }
}
