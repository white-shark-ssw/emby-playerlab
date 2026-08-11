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

private final class ImmersiveNavigationAppearanceEntry {
    weak var navigationController: UINavigationController?
    let standardAppearance: UINavigationBarAppearance
    let scrollEdgeAppearance: UINavigationBarAppearance?
    let compactAppearance: UINavigationBarAppearance?
    let tintColor: UIColor?
    let wasTranslucent: Bool
    var owners = Set<UUID>()
    var generation = 0

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        let bar = navigationController.navigationBar
        standardAppearance = (bar.standardAppearance.copy() as? UINavigationBarAppearance) ?? bar.standardAppearance
        scrollEdgeAppearance = bar.scrollEdgeAppearance?.copy() as? UINavigationBarAppearance
        compactAppearance = bar.compactAppearance?.copy() as? UINavigationBarAppearance
        tintColor = bar.tintColor
        wasTranslucent = bar.isTranslucent
    }
}

private final class ImmersiveNavigationAppearanceManager {
    static let shared = ImmersiveNavigationAppearanceManager()
    private var entries: [ObjectIdentifier: ImmersiveNavigationAppearanceEntry] = [:]

    func acquire(navigationController: UINavigationController, owner: UUID) {
        precondition(Thread.isMainThread)
        let key = ObjectIdentifier(navigationController)
        let entry = entries[key] ?? ImmersiveNavigationAppearanceEntry(navigationController: navigationController)
        entries[key] = entry
        entry.generation += 1
        guard entry.owners.insert(owner).inserted else { return }
        apply(to: navigationController)
        DiagnosticsLogger.shared.log("NavigationVisual", "event=immersive-nav-acquire owners=\(entry.owners.count) stack=\(navigationController.viewControllers.count)")
    }

    func release(navigationController: UINavigationController, owner: UUID) {
        precondition(Thread.isMainThread)
        let key = ObjectIdentifier(navigationController)
        guard let entry = entries[key], entry.owners.remove(owner) != nil else { return }
        entry.generation += 1
        let generation = entry.generation
        DiagnosticsLogger.shared.log("NavigationVisual", "event=immersive-nav-release owners=\(entry.owners.count) stack=\(navigationController.viewControllers.count)")
        guard entry.owners.isEmpty else { return }
        DispatchQueue.main.async { [weak self, weak navigationController] in
            guard let self, let navigationController, let current = self.entries[key], current === entry, current.owners.isEmpty, current.generation == generation else { return }
            self.restore(entry, on: navigationController)
            self.entries.removeValue(forKey: key)
        }
    }

    private func apply(to navigationController: UINavigationController) {
        let bar = navigationController.navigationBar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        let backButton = UIBarButtonItemAppearance(style: .plain)
        backButton.normal.titlePositionAdjustment = UIOffset(horizontal: -1000, vertical: 0)
        backButton.highlighted.titlePositionAdjustment = UIOffset(horizontal: -1000, vertical: 0)
        appearance.backButtonAppearance = backButton
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
        bar.tintColor = .white
        bar.isTranslucent = true
    }

    private func restore(_ entry: ImmersiveNavigationAppearanceEntry, on navigationController: UINavigationController) {
        let bar = navigationController.navigationBar
        bar.standardAppearance = entry.standardAppearance
        bar.scrollEdgeAppearance = entry.scrollEdgeAppearance
        bar.compactAppearance = entry.compactAppearance
        bar.tintColor = entry.tintColor
        bar.isTranslucent = entry.wasTranslucent
        DiagnosticsLogger.shared.log("NavigationVisual", "event=immersive-nav-restore stack=\(navigationController.viewControllers.count)")
    }
}

private final class ImmersiveNavigationAppearanceViewController: UIViewController {
    private let owner = UUID()
    private weak var acquiredNavigationController: UINavigationController?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        acquireIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        acquireIfNeeded()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        releaseIfNeeded()
    }

    func acquireIfNeeded() {
        guard viewIfLoaded?.window != nil, let navigationController else { return }
        if acquiredNavigationController !== navigationController { releaseIfNeeded() }
        acquiredNavigationController = navigationController
        ImmersiveNavigationAppearanceManager.shared.acquire(navigationController: navigationController, owner: owner)
    }

    func releaseIfNeeded() {
        guard let navigationController = acquiredNavigationController else { return }
        ImmersiveNavigationAppearanceManager.shared.release(navigationController: navigationController, owner: owner)
        acquiredNavigationController = nil
    }
}

private struct ImmersiveNavigationAppearanceBridge: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ImmersiveNavigationAppearanceViewController {
        let controller = ImmersiveNavigationAppearanceViewController()
        controller.view.isUserInteractionEnabled = false
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ uiViewController: ImmersiveNavigationAppearanceViewController, context: Context) {
        DispatchQueue.main.async { uiViewController.acquireIfNeeded() }
    }

    static func dismantleUIViewController(_ uiViewController: ImmersiveNavigationAppearanceViewController, coordinator: ()) { uiViewController.releaseIfNeeded() }
}

extension View {
    func nativeInteractivePop() -> some View { self }
    func immersiveSystemNavigationAppearance() -> some View { background(ImmersiveNavigationAppearanceBridge().frame(width: 0, height: 0)) }
    func detailPagePresentation() -> some View { modifier(DetailPagePresentationModifier()) }
    func hidesServerDockWhileVisible() -> some View { detailPagePresentation() }
}

enum DetailHaptics {
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func lightImpact() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
