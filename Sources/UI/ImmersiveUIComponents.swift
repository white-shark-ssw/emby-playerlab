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

private final class ScopedInteractivePopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    weak var navigationController: UINavigationController?

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigationController else { return false }
        let allowed = navigationController.viewControllers.count > 1
        DiagnosticsLogger.shared.log("NavigationRace", "event=scoped-pop-should-begin allowed=\(allowed) stack=\(navigationController.viewControllers.count)")
        return allowed
    }
}

private final class ScopedInteractivePopEntry {
    weak var navigationController: UINavigationController?
    let originalDelegate: UIGestureRecognizerDelegate?
    let originalIsEnabled: Bool
    let proxy: ScopedInteractivePopGestureDelegate
    var owners = Set<UUID>()

    init(navigationController: UINavigationController, gesture: UIGestureRecognizer) {
        self.navigationController = navigationController
        originalDelegate = gesture.delegate
        originalIsEnabled = gesture.isEnabled
        proxy = ScopedInteractivePopGestureDelegate()
        proxy.navigationController = navigationController
    }
}

private final class ScopedInteractivePopManager {
    static let shared = ScopedInteractivePopManager()
    private var entries: [ObjectIdentifier: ScopedInteractivePopEntry] = [:]

    func acquire(navigationController: UINavigationController, owner: UUID) {
        precondition(Thread.isMainThread)
        guard let gesture = navigationController.interactivePopGestureRecognizer else { return }
        let key = ObjectIdentifier(navigationController)
        let entry: ScopedInteractivePopEntry
        if let existing = entries[key] {
            entry = existing
        } else {
            entry = ScopedInteractivePopEntry(navigationController: navigationController, gesture: gesture)
            entries[key] = entry
        }
        let inserted = entry.owners.insert(owner).inserted
        if gesture.delegate.map({ ($0 as AnyObject) !== entry.proxy }) ?? true { gesture.delegate = entry.proxy }
        if !gesture.isEnabled { gesture.isEnabled = true }
        if inserted { DiagnosticsLogger.shared.log("NavigationRace", "event=scoped-pop-acquire owners=\(entry.owners.count) stack=\(navigationController.viewControllers.count)") }
    }

    func release(navigationController: UINavigationController, owner: UUID) {
        precondition(Thread.isMainThread)
        let key = ObjectIdentifier(navigationController)
        guard let entry = entries[key], entry.owners.remove(owner) != nil else { return }
        DiagnosticsLogger.shared.log("NavigationRace", "event=scoped-pop-release owners=\(entry.owners.count) stack=\(navigationController.viewControllers.count)")
        guard entry.owners.isEmpty else { return }
        if let gesture = navigationController.interactivePopGestureRecognizer, gesture.delegate.map({ ($0 as AnyObject) === entry.proxy }) ?? false {
            gesture.delegate = entry.originalDelegate
            gesture.isEnabled = entry.originalIsEnabled
        }
        entries.removeValue(forKey: key)
    }
}

private final class ScopedNativeInteractivePopViewController: UIViewController {
    private let owner = UUID()
    private weak var acquiredNavigationController: UINavigationController?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        activateIfNeeded()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        deactivate()
    }

    func activateIfNeeded() {
        guard viewIfLoaded?.window != nil, let navigationController, navigationController.viewControllers.count > 1, navigationController.isNavigationBarHidden else { return }
        if acquiredNavigationController !== navigationController { deactivate() }
        acquiredNavigationController = navigationController
        ScopedInteractivePopManager.shared.acquire(navigationController: navigationController, owner: owner)
    }

    func deactivate() {
        guard let navigationController = acquiredNavigationController else { return }
        ScopedInteractivePopManager.shared.release(navigationController: navigationController, owner: owner)
        acquiredNavigationController = nil
    }
}

private struct ScopedNativeInteractivePopBridge: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ScopedNativeInteractivePopViewController {
        let controller = ScopedNativeInteractivePopViewController()
        controller.view.isUserInteractionEnabled = false
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ uiViewController: ScopedNativeInteractivePopViewController, context: Context) {
        DispatchQueue.main.async { uiViewController.activateIfNeeded() }
    }

    static func dismantleUIViewController(_ uiViewController: ScopedNativeInteractivePopViewController, coordinator: ()) { uiViewController.deactivate() }
}

extension View {
    func nativeInteractivePop() -> some View { background(ScopedNativeInteractivePopBridge().frame(width: 0, height: 0)) }
    func detailPagePresentation() -> some View { modifier(DetailPagePresentationModifier()) }
    func hidesServerDockWhileVisible() -> some View { detailPagePresentation() }
}

enum DetailHaptics {
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func lightImpact() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
