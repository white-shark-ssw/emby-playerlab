import SwiftUI
import UIKit

struct RefreshableScrollView<Content: View>: UIViewControllerRepresentable {
    let refreshToken: Int
    let scrollToTopToken: Int
    let onRefresh: () async -> Void
    let content: Content

    init(refreshToken: Int = 0, scrollToTopToken: Int = 0, onRefresh: @escaping () async -> Void, @ViewBuilder content: () -> Content) {
        self.refreshToken = refreshToken
        self.scrollToTopToken = scrollToTopToken
        self.onRefresh = onRefresh
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onRefresh: onRefresh)
    }

    func makeUIViewController(context: Context) -> RefreshableHostingController<Content> {
        let controller = RefreshableHostingController(rootView: content)
        context.coordinator.controller = controller
        controller.refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.refreshRequested), for: .valueChanged)
        controller.lastRefreshToken = refreshToken
        controller.lastScrollToTopToken = scrollToTopToken
        return controller
    }

    func updateUIViewController(_ uiViewController: RefreshableHostingController<Content>, context: Context) {
        context.coordinator.onRefresh = onRefresh
        uiViewController.host.rootView = content

        if uiViewController.lastRefreshToken != refreshToken {
            uiViewController.lastRefreshToken = refreshToken
            context.coordinator.performRefresh(showSpinner: true)
        }

        if uiViewController.lastScrollToTopToken != scrollToTopToken {
            uiViewController.lastScrollToTopToken = scrollToTopToken
            let top = CGPoint(x: 0, y: -uiViewController.scrollView.adjustedContentInset.top)
            uiViewController.scrollView.setContentOffset(top, animated: true)
        }
    }

    final class Coordinator: NSObject {
        var onRefresh: () async -> Void
        weak var controller: RefreshableHostingController<Content>?
        private var isRefreshing = false

        init(onRefresh: @escaping () async -> Void) {
            self.onRefresh = onRefresh
        }

        @objc func refreshRequested() {
            performRefresh(showSpinner: false)
        }

        func performRefresh(showSpinner: Bool) {
            guard !isRefreshing, let controller else { return }
            isRefreshing = true
            if showSpinner, !controller.refreshControl.isRefreshing {
                controller.refreshControl.beginRefreshing()
                let offset = CGPoint(x: 0, y: -controller.refreshControl.frame.height - controller.scrollView.adjustedContentInset.top)
                controller.scrollView.setContentOffset(offset, animated: true)
            }
            Task { @MainActor in
                await onRefresh()
                controller.refreshControl.endRefreshing()
                isRefreshing = false
            }
        }
    }
}

final class RefreshableHostingController<Content: View>: UIViewController {
    let scrollView = UIScrollView()
    let refreshControl = UIRefreshControl()
    let host: UIHostingController<Content>
    var lastRefreshToken = 0
    var lastScrollToTopToken = 0

    init(rootView: Content) {
        host = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        scrollView.refreshControl = refreshControl
        host.view.backgroundColor = .clear

        addChild(host)
        view.addSubview(scrollView)
        scrollView.addSubview(host.view)
        host.didMove(toParent: self)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            host.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
    }
}
