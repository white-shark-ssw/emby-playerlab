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

struct AdaptiveHeroRevealMetrics {
    static let initialScale: CGFloat = 1.10
    private static let minimumRevealScale: CGFloat = 0.30

    static func detailBaseHeight(width: CGFloat) -> CGFloat { min(488, max(430, width * 1.08)) }
    static func compactBaseHeight(width: CGFloat) -> CGFloat { min(252, max(206, width * 0.51)) }

    static func revealDistance(heroHeight: CGFloat, viewportHeight: CGFloat) -> CGFloat {
        let geometryDriven = min(heroHeight * 0.16, viewportHeight * 0.085)
        return min(96, max(56, geometryDriven))
    }

    static func fullRevealScale(imageSize: CGSize?, viewportSize: CGSize) -> CGFloat {
        guard let imageSize, imageSize.width > 1, imageSize.height > 1, viewportSize.width > 1, viewportSize.height > 1 else { return 1 }
        let imageAspect = imageSize.width / imageSize.height
        let viewportAspect = viewportSize.width / viewportSize.height
        guard imageAspect > viewportAspect else { return 1 }
        return min(1, max(minimumRevealScale, viewportAspect / imageAspect))
    }

    static func progress(upwardScroll: CGFloat, revealDistance: CGFloat) -> CGFloat {
        guard revealDistance > 0 else { return 1 }
        return min(1, max(0, upwardScroll / revealDistance))
    }

    static func scale(fullRevealScale: CGFloat, progress: CGFloat) -> CGFloat {
        initialScale + (fullRevealScale - initialScale) * eased(progress)
    }

    static func topPinOffset(imageSize: CGSize?, viewportSize: CGSize, scale: CGFloat) -> CGFloat {
        guard let coverHeight = coverHeight(imageSize: imageSize, viewportSize: viewportSize) else { return -max(0, viewportSize.height * (1 - scale) * 0.5) }
        let coverTop = (viewportSize.height - coverHeight) * 0.5
        let scaledTop = viewportSize.height * 0.5 + scale * (coverTop - viewportSize.height * 0.5)
        return -max(0, scaledTop)
    }

    static func clearImageBottom(imageSize: CGSize?, viewportSize: CGSize, scale: CGFloat) -> CGFloat {
        guard let coverHeight = coverHeight(imageSize: imageSize, viewportSize: viewportSize), viewportSize.height > 1 else { return 1 }
        let offset = topPinOffset(imageSize: imageSize, viewportSize: viewportSize, scale: scale)
        let coverBottom = (viewportSize.height + coverHeight) * 0.5
        let scaledBottom = viewportSize.height * 0.5 + scale * (coverBottom - viewportSize.height * 0.5) + offset
        return min(1, max(0.05, scaledBottom / viewportSize.height))
    }

    private static func coverHeight(imageSize: CGSize?, viewportSize: CGSize) -> CGFloat? {
        guard let imageSize, imageSize.width > 1, imageSize.height > 1, viewportSize.width > 1, viewportSize.height > 1 else { return nil }
        let imageAspect = imageSize.width / imageSize.height
        let viewportAspect = viewportSize.width / viewportSize.height
        return imageAspect >= viewportAspect ? viewportSize.height : viewportSize.width / imageAspect
    }

    private static func eased(_ value: CGFloat) -> CGFloat {
        let clamped = min(1, max(0, value))
        let remaining = 1 - clamped
        return 1 - remaining * remaining
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

private final class ImmersiveNavigationAppearanceViewController: UIViewController {
    private weak var appearanceOwner: UIViewController?
    private var originalStandardAppearance: UINavigationBarAppearance?
    private var originalScrollEdgeAppearance: UINavigationBarAppearance?
    private var originalCompactAppearance: UINavigationBarAppearance?
    private var originalCompactScrollEdgeAppearance: UINavigationBarAppearance?
    private var sourceSnapshot: UIView?
    private var sourceControllerIdentifier: ObjectIdentifier?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshVisualOwnership()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshVisualOwnership()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        restoreNavigationItemAppearance()
        removeSourceSnapshot(reason: "destination-disappeared")
    }

    func refreshVisualOwnership() {
        guard viewIfLoaded?.window != nil else { return }
        applyNavigationItemAppearance()
        installSourceSnapshotIfNeeded()
    }

    func tearDown() {
        restoreNavigationItemAppearance()
        removeSourceSnapshot(reason: "bridge-dismantled")
    }

    private func owningNavigationController() -> UINavigationController? { navigationController }

    private func owningDestinationController() -> UIViewController? {
        guard let navigationController = owningNavigationController() else { return parent }
        var current: UIViewController = self
        while let next = current.parent, next !== navigationController { current = next }
        if current.parent === navigationController { return current }
        return navigationController.topViewController
    }

    private func applyNavigationItemAppearance() {
        guard let owner = owningDestinationController() else { return }
        if appearanceOwner !== owner {
            restoreNavigationItemAppearance()
            appearanceOwner = owner
            originalStandardAppearance = owner.navigationItem.standardAppearance
            originalScrollEdgeAppearance = owner.navigationItem.scrollEdgeAppearance
            originalCompactAppearance = owner.navigationItem.compactAppearance
            originalCompactScrollEdgeAppearance = owner.navigationItem.compactScrollEdgeAppearance
        }

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        let backButton = UIBarButtonItemAppearance(style: .plain)
        backButton.normal.titlePositionAdjustment = UIOffset(horizontal: -1000, vertical: 0)
        backButton.highlighted.titlePositionAdjustment = UIOffset(horizontal: -1000, vertical: 0)
        appearance.backButtonAppearance = backButton
        owner.navigationItem.standardAppearance = appearance
        owner.navigationItem.scrollEdgeAppearance = appearance
        owner.navigationItem.compactAppearance = appearance
        owner.navigationItem.compactScrollEdgeAppearance = appearance
        DiagnosticsLogger.shared.log("NavigationVisual", "event=destination-nav-appearance stack=\(owningNavigationController()?.viewControllers.count ?? 0)")
    }

    private func restoreNavigationItemAppearance() {
        guard let owner = appearanceOwner else { return }
        owner.navigationItem.standardAppearance = originalStandardAppearance
        owner.navigationItem.scrollEdgeAppearance = originalScrollEdgeAppearance
        owner.navigationItem.compactAppearance = originalCompactAppearance
        owner.navigationItem.compactScrollEdgeAppearance = originalCompactScrollEdgeAppearance
        DiagnosticsLogger.shared.log("NavigationVisual", "event=destination-nav-restore stack=\(owner.navigationController?.viewControllers.count ?? 0)")
        appearanceOwner = nil
        originalStandardAppearance = nil
        originalScrollEdgeAppearance = nil
        originalCompactAppearance = nil
        originalCompactScrollEdgeAppearance = nil
    }

    private func installSourceSnapshotIfNeeded() {
        guard let navigationController = owningNavigationController(), let destination = owningDestinationController(),
              let index = navigationController.viewControllers.firstIndex(where: { $0 === destination }), index > 0 else { return }
        let source = navigationController.viewControllers[index - 1]
        let identifier = ObjectIdentifier(source)
        if sourceControllerIdentifier == identifier, sourceSnapshot != nil { return }
        removeSourceSnapshot(reason: "source-changed")

        source.loadViewIfNeeded()
        guard let sourceView = source.viewIfLoaded else {
            DiagnosticsLogger.shared.log("NavigationVisual", "event=source-snapshot-skip reason=view-not-loaded stack=\(navigationController.viewControllers.count)")
            return
        }
        sourceView.setNeedsLayout()
        sourceView.layoutIfNeeded()
        guard sourceView.bounds.width > 1, sourceView.bounds.height > 1 else {
            DiagnosticsLogger.shared.log("NavigationVisual", "event=source-snapshot-skip reason=empty-bounds stack=\(navigationController.viewControllers.count)")
            return
        }

        let snapshot: UIView
        if let hierarchySnapshot = sourceView.snapshotView(afterScreenUpdates: false) {
            snapshot = hierarchySnapshot
        } else {
            let renderer = UIGraphicsImageRenderer(bounds: sourceView.bounds)
            let image = renderer.image { _ in sourceView.drawHierarchy(in: sourceView.bounds, afterScreenUpdates: false) }
            snapshot = UIImageView(image: image)
        }
        snapshot.frame = sourceView.bounds
        snapshot.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        snapshot.isUserInteractionEnabled = false
        snapshot.accessibilityElementsHidden = true
        sourceView.addSubview(snapshot)
        sourceView.bringSubviewToFront(snapshot)
        sourceSnapshot = snapshot
        sourceControllerIdentifier = identifier
        DiagnosticsLogger.shared.log("NavigationVisual", "event=source-snapshot-install stack=\(navigationController.viewControllers.count) source=\(type(of: source)) destination=\(type(of: destination))")
    }

    private func removeSourceSnapshot(reason: String) {
        guard let snapshot = sourceSnapshot else { return }
        snapshot.removeFromSuperview()
        sourceSnapshot = nil
        sourceControllerIdentifier = nil
        DiagnosticsLogger.shared.log("NavigationVisual", "event=source-snapshot-remove reason=\(reason)")
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
        DispatchQueue.main.async { uiViewController.refreshVisualOwnership() }
    }

    static func dismantleUIViewController(_ uiViewController: ImmersiveNavigationAppearanceViewController, coordinator: ()) { uiViewController.tearDown() }
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
