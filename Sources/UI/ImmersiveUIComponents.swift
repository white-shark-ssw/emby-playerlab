import SwiftUI
import UIKit

enum ImmersiveUIMetrics {
    static let pageHorizontalPadding: CGFloat = 20
    static let topControlVisualSize: CGFloat = 26
    static let topControlHitSize: CGFloat = 44
    static let topControlPadding: CGFloat = 4
    static let quickJumpHitWidth: CGFloat = 96
}

struct ImmersiveBackdrop: View {
    let url: URL?
    let overlayOpacity: Double
    let blurRadius: CGFloat

    init(url: URL?, overlayOpacity: Double, blurRadius: CGFloat = 52) {
        self.url = url
        self.overlayOpacity = overlayOpacity
        self.blurRadius = blurRadius
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                    default: Color(uiColor: .systemBackground)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .scaleEffect(1.18)
                .blur(radius: blurRadius)
                Color(uiColor: .systemBackground).opacity(overlayOpacity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }
}

struct DetailPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1)
            .opacity(configuration.isPressed ? 0.76 : 1)
            .animation(.easeOut(duration: 0.055), value: configuration.isPressed)
    }
}

private final class NativeNavigationPopViewController: UIViewController {
    weak var popCoordinator: NativeNavigationPopBridge.Coordinator?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        popCoordinator?.install(from: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        popCoordinator?.install(from: self)
    }
}

private struct NativeNavigationPopBridge: UIViewControllerRepresentable {
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private let navigationControllers = NSHashTable<UINavigationController>.weakObjects()

        func install(from viewController: UIViewController) {
            if let navigationController = viewController.navigationController { install(navigationController) }
            if let root = viewController.viewIfLoaded?.window?.rootViewController { installTree(from: root) }
        }

        private func installTree(from root: UIViewController) {
            var stack: [UIViewController] = [root]
            while let current = stack.popLast() {
                if let navigationController = current as? UINavigationController { install(navigationController) }
                if let presented = current.presentedViewController { stack.append(presented) }
                stack.append(contentsOf: current.children)
            }
        }

        private func install(_ navigationController: UINavigationController) {
            navigationControllers.add(navigationController)
            guard let gesture = navigationController.interactivePopGestureRecognizer else { return }
            gesture.isEnabled = navigationController.viewControllers.count > 1
            gesture.delegate = self
            gesture.cancelsTouchesInView = true
        }

        private func navigationController(for gestureRecognizer: UIGestureRecognizer) -> UINavigationController? {
            navigationControllers.allObjects.first { $0.interactivePopGestureRecognizer === gestureRecognizer }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let navigationController = navigationController(for: gestureRecognizer) else { return false }
            return navigationController.viewControllers.count > 1 && navigationController.transitionCoordinator == nil
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = NativeNavigationPopViewController()
        controller.popCoordinator = context.coordinator
        return controller
    }

    func updateUIViewController(_ viewController: UIViewController, context: Context) {
        context.coordinator.install(from: viewController)
        DispatchQueue.main.async { context.coordinator.install(from: viewController) }
    }
}

extension View {
    func nativeInteractivePop() -> some View {
        background(NativeNavigationPopBridge().frame(width: 0, height: 0))
    }
}

enum DetailHaptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func lightImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
