import SwiftUI
import UIKit

extension View {
    func fullScreenCover<Content: View>(item: Binding<ResolvedPlaybackSource?>, @ViewBuilder content: @escaping (ResolvedPlaybackSource) -> Content) -> some View {
        background(
            ResolvedPlaybackFullscreenPresenter(item: item, content: content)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        )
    }
}

private struct ResolvedPlaybackFullscreenPresenter<Content: View>: UIViewControllerRepresentable {
    @Binding var item: ResolvedPlaybackSource?
    let content: (ResolvedPlaybackSource) -> Content

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.itemBinding = $item
        context.coordinator.contentBuilder = content
        DispatchQueue.main.async { context.coordinator.synchronize(anchor: uiViewController, item: item) }
    }

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) { coordinator.dismissImmediately() }

    final class Coordinator {
        var itemBinding: Binding<ResolvedPlaybackSource?>?
        var contentBuilder: ((ResolvedPlaybackSource) -> Content)?
        private weak var hostController: UIViewController?
        private var presenting = false
        private var dismissing = false

        @MainActor
        func synchronize(anchor: UIViewController, item: ResolvedPlaybackSource?) {
            if let source = item {
                guard hostController == nil, !presenting, !dismissing, let builder = contentBuilder else { return }
                guard let presenter = topPresenter(from: anchor) else {
                    DispatchQueue.main.async { [weak self, weak anchor] in
                        guard let self, let anchor else { return }
                        self.synchronize(anchor: anchor, item: self.itemBinding?.wrappedValue)
                    }
                    return
                }
                presenting = true
                let host = DismissAwareHostingController(rootView: builder(source))
                host.modalPresentationStyle = .overFullScreen
                host.modalTransitionStyle = .crossDissolve
                host.view.backgroundColor = .clear
                host.onDismissed = { [weak self, weak host] in
                    guard let self, self.hostController === host else { return }
                    self.hostController = nil
                    self.presenting = false
                    self.dismissing = false
                    if self.itemBinding?.wrappedValue != nil { self.itemBinding?.wrappedValue = nil }
                    DiagnosticsLogger.shared.playback("PlayerUI", "fullscreen player dismissed transition=crossDissolve")
                }
                hostController = host
                DiagnosticsLogger.shared.playback("PlayerUI", "fullscreen player present transition=immediate style=overFullScreen")
                presenter.present(host, animated: false) { [weak self] in self?.presenting = false }
            } else if let host = hostController, !dismissing {
                dismissing = true
                host.dismiss(animated: true) { [weak self] in
                    self?.hostController = nil
                    self?.presenting = false
                    self?.dismissing = false
                }
            }
        }

        @MainActor
        func dismissImmediately() {
            guard let host = hostController else { return }
            host.dismiss(animated: false)
            hostController = nil
            presenting = false
            dismissing = false
        }

        @MainActor
        private func topPresenter(from anchor: UIViewController) -> UIViewController? {
            guard let window = anchor.viewIfLoaded?.window else { return nil }
            var current = window.rootViewController
            while let presented = current?.presentedViewController, presented !== hostController { current = presented }
            return current
        }
    }
}

private final class DismissAwareHostingController<Content: View>: UIHostingController<Content> {
    var onDismissed: (() -> Void)?
    private var didNotifyDismissed = false

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard !didNotifyDismissed, presentingViewController == nil || isBeingDismissed else { return }
        didNotifyDismissed = true
        onDismissed?()
    }
}
