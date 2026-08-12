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
    static let cropResponseFactor: CGFloat = 0.65
    static func detailBaseHeight(width: CGFloat) -> CGFloat { min(488, max(430, width * 1.08)) }
    static func compactBaseHeight(width: CGFloat) -> CGFloat { min(252, max(206, width * 0.51)) }

    static func cropTravel(imageSize: CGSize?, viewportSize: CGSize) -> CGFloat {
        let initialSize = initialRenderedImageSize(imageSize: imageSize, viewportSize: viewportSize)
        let fullSize = fullRevealImageSize(imageSize: imageSize, viewportSize: viewportSize)
        return max(0, initialSize.height - fullSize.height)
    }

    static func consumedCropScroll(upwardScroll: CGFloat, cropTravel: CGFloat) -> CGFloat {
        min(max(0, upwardScroll) * cropResponseFactor, max(0, cropTravel))
    }

    // Native container motion remains 1:1 with UIScrollView. The clear backdrop releases crop
    // at a softer response rate so image geometry changes do not outrun the user's finger.
    static func renderedImageSize(imageSize: CGSize?, viewportSize: CGSize, consumedCropScroll: CGFloat) -> CGSize {
        let initialSize = initialRenderedImageSize(imageSize: imageSize, viewportSize: viewportSize)
        let fullSize = fullRevealImageSize(imageSize: imageSize, viewportSize: viewportSize)
        guard let imageSize, imageSize.width > 1, imageSize.height > 1 else {
            let height = max(fullSize.height, initialSize.height - max(0, consumedCropScroll))
            let ratio = initialSize.height > 1 ? initialSize.width / initialSize.height : 1
            return CGSize(width: height * ratio, height: height)
        }
        let aspect = imageSize.width / imageSize.height
        let height = max(fullSize.height, initialSize.height - max(0, consumedCropScroll))
        return CGSize(width: height * aspect, height: height)
    }

    static func stretchedImageSize(imageSize: CGSize?, viewportSize: CGSize) -> CGSize {
        let cover = coverSize(imageSize: imageSize, viewportSize: viewportSize) ?? viewportSize
        return CGSize(width: cover.width * initialScale, height: cover.height * initialScale)
    }

    static func clearImageBottom(renderedImageSize: CGSize, viewportHeight: CGFloat) -> CGFloat {
        guard viewportHeight > 1 else { return 1 }
        return min(1, max(0.05, renderedImageSize.height / viewportHeight))
    }

    private static func initialRenderedImageSize(imageSize: CGSize?, viewportSize: CGSize) -> CGSize {
        let cover = coverSize(imageSize: imageSize, viewportSize: viewportSize) ?? viewportSize
        return CGSize(width: cover.width * initialScale, height: cover.height * initialScale)
    }

    private static func fullRevealImageSize(imageSize: CGSize?, viewportSize: CGSize) -> CGSize {
        guard let imageSize, imageSize.width > 1, imageSize.height > 1, viewportSize.width > 1, viewportSize.height > 1 else { return viewportSize }
        // Width is the hard reveal floor. Never shrink the clear backdrop narrower than the viewport,
        // even when a compact Hero is wider than the source aspect ratio.
        let scale = viewportSize.width / imageSize.width
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private static func coverSize(imageSize: CGSize?, viewportSize: CGSize) -> CGSize? {
        guard let imageSize, imageSize.width > 1, imageSize.height > 1, viewportSize.width > 1, viewportSize.height > 1 else { return nil }
        let scale = max(viewportSize.width / imageSize.width, viewportSize.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}

final class AdaptiveHeroScrollProbeUIView: UIView {
    var hierarchyDidChange: ((UIView) -> Void)?

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        hierarchyDidChange?(self)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        hierarchyDidChange?(self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        hierarchyDidChange?(self)
    }
}

struct AdaptiveHeroNativeScrollObserver: UIViewRepresentable {
    let forceVerticalBounce: Bool
    let onChange: (CGFloat) -> Void

    init(forceVerticalBounce: Bool = false, onChange: @escaping (CGFloat) -> Void) {
        self.forceVerticalBounce = forceVerticalBounce
        self.onChange = onChange
    }

    func makeCoordinator() -> Coordinator { Coordinator(forceVerticalBounce: forceVerticalBounce, onChange: onChange) }

    func makeUIView(context: Context) -> AdaptiveHeroScrollProbeUIView {
        let view = AdaptiveHeroScrollProbeUIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.hierarchyDidChange = { [weak coordinator = context.coordinator] probe in coordinator?.attach(from: probe) }
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak view] in
            guard let view else { return }
            coordinator?.attach(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: AdaptiveHeroScrollProbeUIView, context: Context) {
        context.coordinator.forceVerticalBounce = forceVerticalBounce
        context.coordinator.onChange = onChange
        context.coordinator.applyBouncePolicy()
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak uiView] in
            guard let uiView else { return }
            coordinator?.attach(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: AdaptiveHeroScrollProbeUIView, coordinator: Coordinator) {
        uiView.hierarchyDidChange = nil
        coordinator.detach()
    }

    final class Coordinator {
        var forceVerticalBounce: Bool
        var onChange: (CGFloat) -> Void
        private weak var scrollView: UIScrollView?
        private var contentOffsetObservation: NSKeyValueObservation?
        private var originalBounces: Bool?
        private var originalAlwaysBounceVertical: Bool?

        init(forceVerticalBounce: Bool, onChange: @escaping (CGFloat) -> Void) {
            self.forceVerticalBounce = forceVerticalBounce
            self.onChange = onChange
        }

        func attach(from probe: UIView) {
            guard let scrollView = ancestorScrollView(from: probe) else { return }
            guard self.scrollView !== scrollView else {
                applyBouncePolicy()
                emit(scrollView)
                return
            }
            restoreBouncePolicy()
            contentOffsetObservation?.invalidate()
            self.scrollView = scrollView
            originalBounces = scrollView.bounces
            originalAlwaysBounceVertical = scrollView.alwaysBounceVertical
            applyBouncePolicy()
            contentOffsetObservation = scrollView.observe(\.contentOffset, options: [.initial, .new]) { [weak self] scrollView, _ in self?.emit(scrollView) }
        }

        func detach() {
            contentOffsetObservation?.invalidate()
            contentOffsetObservation = nil
            restoreBouncePolicy()
            scrollView = nil
            originalBounces = nil
            originalAlwaysBounceVertical = nil
        }

        func applyBouncePolicy() {
            guard forceVerticalBounce, let scrollView else { return }
            scrollView.bounces = true
            scrollView.alwaysBounceVertical = true
        }

        private func restoreBouncePolicy() {
            guard let scrollView else { return }
            if let originalBounces { scrollView.bounces = originalBounces }
            if let originalAlwaysBounceVertical { scrollView.alwaysBounceVertical = originalAlwaysBounceVertical }
        }

        private func ancestorScrollView(from probe: UIView) -> UIScrollView? {
            var current: UIView? = probe
            while let view = current {
                if let scrollView = view as? UIScrollView { return scrollView }
                current = view.superview
            }
            return nil
        }

        private func emit(_ scrollView: UIScrollView) {
            let rawDisplacement = -(scrollView.contentOffset.y + scrollView.adjustedContentInset.top)
            if Thread.isMainThread { onChange(rawDisplacement) }
            else { DispatchQueue.main.async { [weak self] in self?.onChange(rawDisplacement) } }
        }
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
