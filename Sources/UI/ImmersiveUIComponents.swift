import SwiftUI
import UIKit

enum ImmersiveUIMetrics {
    static let pageHorizontalPadding: CGFloat = 20
    static let topControlVisualSize: CGFloat = 26
    static let topControlHitSize: CGFloat = 44
    static let topControlPadding: CGFloat = 1
    static let quickJumpHitWidth: CGFloat = 15
    static let serverDockHeight: CGFloat = 40
}

enum DetailPresentationSettingsKey {
    static let fullyImmersive = "ui.detailFullyImmersive"
}

private struct ServerDockContentKey: EnvironmentKey {
    static let defaultValue: AnyView? = nil
}

private struct ServerDockBottomInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var serverDockContent: AnyView? {
        get { self[ServerDockContentKey.self] }
        set { self[ServerDockContentKey.self] = newValue }
    }

    var serverDockBottomInset: CGFloat {
        get { self[ServerDockBottomInsetKey.self] }
        set { self[ServerDockBottomInsetKey.self] = newValue }
    }
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

private struct DetailPagePresentationModifier: ViewModifier {
    @AppStorage(DetailPresentationSettingsKey.fullyImmersive) private var fullyImmersive = true
    @Environment(\.serverDockContent) private var serverDockContent
    @Environment(\.serverDockBottomInset) private var serverDockBottomInset

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if !fullyImmersive, let serverDockContent {
                    serverDockContent
                        .frame(height: ImmersiveUIMetrics.serverDockHeight)
                        .padding(.bottom, serverDockBottomInset)
                        .zIndex(100)
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
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
    final class Coordinator: NSObject {
        private let navigationControllers = NSHashTable<UINavigationController>.weakObjects()
        private let observedGestures = NSHashTable<UIGestureRecognizer>.weakObjects()

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
            if !observedGestures.contains(gesture) {
                observedGestures.add(gesture)
                gesture.addTarget(self, action: #selector(popGestureChanged(_:)))
            }
            gesture.delegate = nil
            gesture.isEnabled = navigationController.viewControllers.count > 1
            gesture.cancelsTouchesInView = true
        }

        private func navigationController(for gestureRecognizer: UIGestureRecognizer) -> UINavigationController? {
            navigationControllers.allObjects.first { $0.interactivePopGestureRecognizer === gestureRecognizer }
        }

        @objc private func popGestureChanged(_ gestureRecognizer: UIGestureRecognizer) {
            guard gestureRecognizer.state == .began || gestureRecognizer.state == .ended || gestureRecognizer.state == .cancelled || gestureRecognizer.state == .failed else { return }
            let navigationController = navigationController(for: gestureRecognizer)
            DiagnosticsLogger.shared.log("NavigationRace", "event=interactive-pop-state state=\(gestureRecognizer.state.rawValue) stack=\(navigationController?.viewControllers.count ?? 0) coordinatorPresent=\(navigationController?.transitionCoordinator != nil)")
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
    func nativeInteractivePop() -> some View { background(NativeNavigationPopBridge().frame(width: 0, height: 0)) }
    func detailPagePresentation() -> some View { modifier(DetailPagePresentationModifier()) }
    func hidesServerDockWhileVisible() -> some View { detailPagePresentation() }
}

enum DetailHaptics {
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func lightImpact() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
