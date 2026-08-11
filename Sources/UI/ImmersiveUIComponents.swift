import SwiftUI
import UIKit

enum ImmersiveUIMetrics {
    static let pageHorizontalPadding: CGFloat = 20
    static let topControlVisualSize: CGFloat = 26
    static let topControlHitSize: CGFloat = 44
    static let topControlPadding: CGFloat = 1
    static let quickJumpHitWidth: CGFloat = 15
}

final class ServerDockVisibilityController: ObservableObject {
    @Published private(set) var isHidden = false
    private var hiddenOwners = Set<UUID>()
    private var visibilityGeneration = 0

    func hide(owner: UUID) {
        precondition(Thread.isMainThread)
        visibilityGeneration += 1
        hiddenOwners.insert(owner)
        if !isHidden { isHidden = true }
    }

    func show(owner: UUID) {
        precondition(Thread.isMainThread)
        hiddenOwners.remove(owner)
        guard hiddenOwners.isEmpty else { return }
        visibilityGeneration += 1
        let generation = visibilityGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.hiddenOwners.isEmpty, self.visibilityGeneration == generation else { return }
            self.isHidden = false
        }
    }
}

private struct ServerDockVisibilityControllerKey: EnvironmentKey {
    static let defaultValue: ServerDockVisibilityController? = nil
}

extension EnvironmentValues {
    var serverDockVisibilityController: ServerDockVisibilityController? {
        get { self[ServerDockVisibilityControllerKey.self] }
        set { self[ServerDockVisibilityControllerKey.self] = newValue }
    }
}

private final class ImmersiveBottomSafeAreaViewController: UIViewController {
    weak var safeAreaCoordinator: ImmersiveBottomSafeAreaBridge.Coordinator?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        safeAreaCoordinator?.apply(from: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        safeAreaCoordinator?.apply(from: self)
    }
}

private struct ImmersiveBottomSafeAreaBridge: UIViewControllerRepresentable {
    final class Coordinator: NSObject {
        private weak var targetViewController: UIViewController?
        private var originalInsets: UIEdgeInsets?
        private var appliedInsets: UIEdgeInsets?

        func apply(from bridge: UIViewController) {
            guard let target = hostingTarget(from: bridge), target.viewIfLoaded?.window != nil else { return }
            if target !== targetViewController {
                restore()
                targetViewController = target
                originalInsets = target.additionalSafeAreaInsets
            }

            guard appliedInsets == nil else { return }
            let bottomInset = target.view.safeAreaInsets.bottom
            guard bottomInset > 0.5 else { return }

            var desired = originalInsets ?? target.additionalSafeAreaInsets
            desired.bottom -= bottomInset
            target.additionalSafeAreaInsets = desired
            appliedInsets = desired
            target.view.setNeedsLayout()
        }

        func restore() {
            guard let target = targetViewController, let originalInsets else {
                targetViewController = nil
                originalInsets = nil
                appliedInsets = nil
                return
            }
            if appliedInsets == nil || target.additionalSafeAreaInsets == appliedInsets {
                target.additionalSafeAreaInsets = originalInsets
                target.view.setNeedsLayout()
            }
            targetViewController = nil
            self.originalInsets = nil
            appliedInsets = nil
        }

        private func hostingTarget(from bridge: UIViewController) -> UIViewController? {
            guard let navigationController = bridge.navigationController else { return bridge.parent }
            var current = bridge.parent
            while let parent = current?.parent, parent !== navigationController { current = parent }
            return current ?? navigationController.topViewController
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = ImmersiveBottomSafeAreaViewController()
        controller.safeAreaCoordinator = context.coordinator
        controller.view.isUserInteractionEnabled = false
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ viewController: UIViewController, context: Context) {
        context.coordinator.apply(from: viewController)
        DispatchQueue.main.async { context.coordinator.apply(from: viewController) }
    }

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        coordinator.restore()
    }
}

private struct ServerDockHiddenWhileVisibleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .ignoresSafeArea(.container, edges: .bottom)
            .background(ImmersiveBottomSafeAreaBridge().frame(width: 0, height: 0))
    }
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

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
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
    func nativeInteractivePop() -> some View { background(NativeNavigationPopBridge().frame(width: 0, height: 0)) }
    func hidesServerDockWhileVisible() -> some View { modifier(ServerDockHiddenWhileVisibleModifier()) }
}

enum DetailHaptics {
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func lightImpact() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
