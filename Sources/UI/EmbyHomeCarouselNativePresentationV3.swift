import SwiftUI
import UIKit
import CoreImage

struct V3HomeCarouselPresentationItem: Identifiable, Equatable {
    let id: String
    let title: String
    let overview: String?
    let rating: Double?
    let year: Int?
    let officialRating: String?
    let typeTitle: String
    let heroURL: URL?
    let logoURL: URL?
}

struct V3HomeCarouselTransitionVisualState {
    let currentID: String?
    let fromID: String?
    let toID: String?
    let direction: Int
    let progress: CGFloat
}

enum V3HomeCarouselNativeLayout {
    static func displayHeightAdjustment(displayRange: Double, viewportHeight: CGFloat) -> CGFloat {
        let value = CGFloat(min(1, max(0, displayRange)))
        if value >= 0.30 {
            let progress = (value - 0.30) / 0.70
            return min(132, viewportHeight * 0.16) * progress
        }
        let progress = (0.30 - value) / 0.30
        return -min(52, viewportHeight * 0.06) * progress
    }

    static func initialArtworkSize(imageSize: CGSize?, viewportSize: CGSize) -> CGSize {
        guard let imageSize, imageSize.width > 1, imageSize.height > 1, viewportSize.width > 1, viewportSize.height > 1 else {
            return CGSize(width: viewportSize.width, height: max(viewportSize.height, viewportSize.width * 1.5))
        }
        let scale = max(viewportSize.width / imageSize.width, viewportSize.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    static func fullRevealArtworkSize(imageSize: CGSize?, viewportSize: CGSize) -> CGSize {
        guard let imageSize, imageSize.width > 1, imageSize.height > 1, viewportSize.width > 1 else {
            return initialArtworkSize(imageSize: imageSize, viewportSize: viewportSize)
        }
        let scale = viewportSize.width / imageSize.width
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    static func displayRangeArtworkSize(defaultSize: CGSize, fullRevealSize: CGSize, displayRange: Double) -> CGSize {
        let value = CGFloat(min(1, max(0, displayRange)))
        if value >= 0.30 {
            let progress = min(1, ((value - 0.30) / 0.70) * 0.82)
            return CGSize(width: defaultSize.width + (fullRevealSize.width - defaultSize.width) * progress, height: defaultSize.height + (fullRevealSize.height - defaultSize.height) * progress)
        }
        let progress = (0.30 - value) / 0.30
        let scale = 1 + 0.12 * progress
        return CGSize(width: defaultSize.width * scale, height: defaultSize.height * scale)
    }

    static func backdropBlendProgress(_ rawProgress: CGFloat) -> CGFloat {
        let progress = min(1, max(0, rawProgress))
        let remaining = 1 - progress
        let earlyWeight = remaining * remaining * remaining * remaining * remaining * remaining
        return progress * (1 - 0.85 * earlyWeight)
    }
}

struct V3HomeCarouselImageAnalysis {
    let sourceSize: CGSize
    let prefersLightForeground: Bool
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat

    static func analyze(_ image: UIImage) -> V3HomeCarouselImageAnalysis {
        let prefersLight = EmbyImageContrastAnalyzer.prefersLightForeground(for: image)
        guard let input = CIImage(image: image) else { return V3HomeCarouselImageAnalysis(sourceSize: image.size, prefersLightForeground: prefersLight, red: 0.18, green: 0.18, blue: 0.18) }
        let extent = input.extent
        let sample = CGRect(x: extent.minX + extent.width * 0.10, y: extent.minY + extent.height * 0.10, width: extent.width * 0.80, height: extent.height * 0.80).intersection(extent)
        guard !sample.isNull, sample.width > 0, sample.height > 0, let filter = CIFilter(name: "CIAreaAverage") else { return V3HomeCarouselImageAnalysis(sourceSize: image.size, prefersLightForeground: prefersLight, red: 0.18, green: 0.18, blue: 0.18) }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: sample), forKey: kCIInputExtentKey)
        guard let output = filter.outputImage else { return V3HomeCarouselImageAnalysis(sourceSize: image.size, prefersLightForeground: prefersLight, red: 0.18, green: 0.18, blue: 0.18) }
        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext().render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return V3HomeCarouselImageAnalysis(sourceSize: image.size, prefersLightForeground: prefersLight, red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255, blue: CGFloat(pixel[2]) / 255)
    }
}

final class V3HomeCarouselPresentationBridge {
    private struct Resource {
        var heroURL: URL?
        var heroImage: UIImage?
        var logoURL: URL?
        var logoImage: UIImage?
        var analysis: V3HomeCarouselImageAnalysis?
        var analysisURL: URL?
    }

    private(set) var items: [V3HomeCarouselPresentationItem] = []
    private var resources: [String: Resource] = [:]
    private var visualState = V3HomeCarouselTransitionVisualState(currentID: nil, fromID: nil, toID: nil, direction: 1, progress: 0)
    private var width: CGFloat = 0
    private var viewportHeight: CGFloat = 0
    private var surfaceHeight: CGFloat = 0
    private var displayRange: Double = 0.30
    private var rawScrollMinY: CGFloat = 0
    private weak var view: V3HomeCarouselNativeView?

    func configure(items: [V3HomeCarouselPresentationItem]) {
        self.items = items
        let ids = Set(items.map(\.id))
        resources = resources.filter { ids.contains($0.key) }
        for item in items {
            var resource = resources[item.id] ?? Resource()
            if resource.heroURL != item.heroURL { resource.heroURL = item.heroURL; resource.heroImage = nil; resource.analysis = nil; resource.analysisURL = nil }
            if resource.logoURL != item.logoURL { resource.logoURL = item.logoURL; resource.logoImage = nil }
            resources[item.id] = resource
        }
        view?.configure(items: items, resources: resourcesSnapshot())
        view?.applyVisualState(visualState, animated: false)
    }

    func updateGeometry(width: CGFloat, viewportHeight: CGFloat, surfaceHeight: CGFloat, displayRange: Double) {
        self.width = width
        self.viewportHeight = viewportHeight
        self.surfaceHeight = surfaceHeight
        self.displayRange = displayRange
        view?.updateGeometry(width: width, viewportHeight: viewportHeight, surfaceHeight: surfaceHeight, displayRange: displayRange, rawScrollMinY: rawScrollMinY)
    }

    func updateRawScrollMinY(_ value: CGFloat) {
        rawScrollMinY = value
        view?.updateRawScrollMinY(value)
    }

    func acceptHeroImage(_ image: UIImage, itemID: String, url: URL?) {
        guard let item = items.first(where: { $0.id == itemID }), item.heroURL == url else { return }
        var resource = resources[itemID] ?? Resource()
        resource.heroURL = url
        resource.heroImage = image
        resources[itemID] = resource
        V3HomeCarouselCadenceDiagnostics.shared.recordImageCallback(role: "prepared-hero", itemID: itemID)
        view?.setHeroImage(image, itemID: itemID)
        guard resource.analysisURL != url || resource.analysis == nil else { return }
        resource.analysisURL = url
        resources[itemID] = resource
        Task.detached(priority: .utility) {
            let analysis = V3HomeCarouselImageAnalysis.analyze(image)
            await MainActor.run { [weak self] in
                guard let self, let current = self.items.first(where: { $0.id == itemID }), current.heroURL == url else { return }
                var latest = self.resources[itemID] ?? Resource()
                guard latest.heroURL == url else { return }
                latest.analysis = analysis
                latest.analysisURL = url
                self.resources[itemID] = latest
                self.view?.setImageAnalysis(analysis, itemID: itemID)
            }
        }
    }

    func acceptLogoImage(_ image: UIImage, itemID: String, url: URL?) {
        guard let item = items.first(where: { $0.id == itemID }), item.logoURL == url else { return }
        var resource = resources[itemID] ?? Resource()
        resource.logoURL = url
        resource.logoImage = image
        resources[itemID] = resource
        V3HomeCarouselCadenceDiagnostics.shared.recordImageCallback(role: "prepared-logo", itemID: itemID)
        view?.setLogoImage(image, itemID: itemID)
    }

    func present(_ state: V3HomeCarouselTransitionVisualState) {
        visualState = state
        view?.applyVisualState(state, animated: false)
    }

    @discardableResult
    func animate(_ state: V3HomeCarouselTransitionVisualState, duration: TimeInterval, curve: UIView.AnimationCurve, completion: @escaping () -> Void) -> Bool {
        visualState = state
        guard let view else { return false }
        view.animateVisualState(state, duration: duration, curve: curve, completion: completion)
        return true
    }

    func interruptAndReadProgress(fromID: String?, toID: String?, direction: Int, fallback: CGFloat) -> CGFloat {
        guard let view else { return fallback }
        let progress = view.interruptAndReadProgress(fromID: fromID, toID: toID, direction: direction, fallback: fallback)
        visualState = V3HomeCarouselTransitionVisualState(currentID: visualState.currentID, fromID: fromID, toID: toID, direction: direction, progress: progress)
        return progress
    }

    func stopAnimationAndPresent(_ state: V3HomeCarouselTransitionVisualState) {
        visualState = state
        view?.stopAnimation()
        view?.applyVisualState(state, animated: false)
    }

    func bind(_ view: V3HomeCarouselNativeView) {
        self.view = view
        view.configure(items: items, resources: resourcesSnapshot())
        view.updateGeometry(width: width, viewportHeight: viewportHeight, surfaceHeight: surfaceHeight, displayRange: displayRange, rawScrollMinY: rawScrollMinY)
        view.applyVisualState(visualState, animated: false)
    }

    private func resourcesSnapshot() -> [String: V3HomeCarouselNativeResource] {
        Dictionary(uniqueKeysWithValues: resources.map { key, value in (key, V3HomeCarouselNativeResource(heroImage: value.heroImage, logoImage: value.logoImage, analysis: value.analysis)) })
    }
}

struct V3HomeCarouselNativeResource {
    let heroImage: UIImage?
    let logoImage: UIImage?
    let analysis: V3HomeCarouselImageAnalysis?
}

struct V3HomeCarouselNativeSurface: UIViewRepresentable {
    let bridge: V3HomeCarouselPresentationBridge
    let width: CGFloat
    let viewportHeight: CGFloat
    let surfaceHeight: CGFloat
    let displayRange: Double

    func makeUIView(context: Context) -> V3HomeCarouselNativeView {
        let view = V3HomeCarouselNativeView(frame: .zero)
        view.isUserInteractionEnabled = false
        bridge.bind(view)
        return view
    }

    func updateUIView(_ uiView: V3HomeCarouselNativeView, context: Context) {
        bridge.updateGeometry(width: width, viewportHeight: viewportHeight, surfaceHeight: surfaceHeight, displayRange: displayRange)
    }
}

struct V3HomeCarouselResourcePreparationView: View {
    let items: [V3HomeCarouselPresentationItem]
    let bridge: V3HomeCarouselPresentationBridge

    var body: some View {
        ZStack {
            ForEach(items) { item in
                EmbyCachedRemoteImage(url: item.heroURL, contentMode: .fill, placeholderSystemImage: "photo", showsLoadingIndicator: false, onImageLoaded: { image in bridge.acceptHeroImage(image, itemID: item.id, url: item.heroURL) })
                    .frame(width: 1, height: 1).clipped()
                if let logoURL = item.logoURL {
                    EmbyCachedRemoteImage(url: logoURL, contentMode: .fit, showsLoadingIndicator: false, onImageLoaded: { image in bridge.acceptLogoImage(image, itemID: item.id, url: logoURL) })
                        .frame(width: 1, height: 1).clipped()
                }
            }
        }
        .frame(width: 1, height: 1)
        .opacity(0.001)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct V3HomeCarouselForegroundStaticView: View {
    let item: V3HomeCarouselPresentationItem
    let logoImage: UIImage?
    let usesLight: Bool

    var body: some View {
        let primaryForeground = usesLight ? Color.white : Color.black
        let secondaryForeground = usesLight ? Color.white.opacity(0.90) : Color.black.opacity(0.80)
        let foregroundShadow = usesLight ? Color.black.opacity(0.52) : Color.white.opacity(0.24)
        VStack(alignment: .center, spacing: 10) {
            if let logoImage {
                Image(uiImage: logoImage).resizable().aspectRatio(contentMode: .fit).frame(maxWidth: 300, maxHeight: 76).frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text(item.title).font(.system(size: 30, weight: .bold)).foregroundColor(primaryForeground).multilineTextAlignment(.center).lineLimit(2).frame(maxWidth: .infinity, alignment: .center).shadow(color: foregroundShadow, radius: 3, y: 1)
            }
            HStack(spacing: 8) {
                if let rating = item.rating { Text("★ " + String(format: "%.1f", rating)).foregroundColor(.yellow) }
                if let year = item.year { Text(String(year)) }
                if let official = item.officialRating, !official.isEmpty { Text(official) }
                Text(item.typeTitle)
            }
            .font(.subheadline.weight(.semibold)).foregroundColor(secondaryForeground).frame(maxWidth: .infinity, alignment: .center)
            if let overview = item.overview, !overview.isEmpty {
                Text(overview).font(.subheadline).foregroundColor(secondaryForeground).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading).shadow(color: foregroundShadow, radius: 2, y: 1)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 56)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color.clear)
    }
}

final class V3HomeCarouselNativeView: UIView {
    private final class ArtworkView: UIView {
        let clipView = UIView()
        let imageView = UIImageView()
        let maskGradient = CAGradientLayer()
        let contrastGradient = CAGradientLayer()
        var analysis: V3HomeCarouselImageAnalysis?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            backgroundColor = .clear
            clipView.clipsToBounds = true
            clipView.backgroundColor = .clear
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = false
            clipView.addSubview(imageView)
            addSubview(clipView)
            clipView.layer.mask = maskGradient
            layer.addSublayer(contrastGradient)
        }

        required init?(coder: NSCoder) { nil }

        func updateContrast() {
            let usesLight = analysis?.prefersLightForeground ?? true
            let alpha: CGFloat = usesLight ? 0.22 : 0.16
            let color = usesLight ? UIColor.black : UIColor.white
            contrastGradient.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor, color.withAlphaComponent(alpha * 0.42).cgColor, color.withAlphaComponent(alpha).cgColor, UIColor.clear.cgColor]
            contrastGradient.locations = [0.00, 0.46, 0.66, 0.82, 1.00]
        }

        func layoutArtwork(width: CGFloat, viewportHeight: CGFloat, displayRange: Double, rawScrollMinY: CGFloat) {
            let adjustment = V3HomeCarouselNativeLayout.displayHeightAdjustment(displayRange: displayRange, viewportHeight: viewportHeight)
            let backdropBaseHeight = AdaptiveHeroRevealMetrics.detailBaseHeight(width: width) + adjustment
            let baseHeight = AdaptiveHeroRevealMetrics.detailForegroundBaseHeight(width: width, viewportHeight: viewportHeight) + adjustment
            let backdropViewportHeight = AdaptiveHeroRevealMetrics.detailBackdropViewportHeight(width: width)
            let sourceSize = analysis?.sourceSize ?? imageView.image?.size
            let viewport = CGSize(width: width, height: backdropViewportHeight)
            let defaultSize = V3HomeCarouselNativeLayout.initialArtworkSize(imageSize: sourceSize, viewportSize: viewport)
            let fullRevealSize = V3HomeCarouselNativeLayout.fullRevealArtworkSize(imageSize: sourceSize, viewportSize: viewport)
            let initialSize = V3HomeCarouselNativeLayout.displayRangeArtworkSize(defaultSize: defaultSize, fullRevealSize: fullRevealSize, displayRange: displayRange)
            let cropTravel = max(0, initialSize.height - fullRevealSize.height)
            let stretch = max(0, rawScrollMinY)
            let upwardScroll = max(0, -rawScrollMinY)
            let consumedCropScroll = min(upwardScroll * AdaptiveHeroRevealMetrics.detailCropResponseFactor, cropTravel)
            let cropPhaseDistance = cropTravel / AdaptiveHeroRevealMetrics.detailCropResponseFactor
            let backdropPinOffset = min(upwardScroll, cropPhaseDistance)
            let backdropVisualHeight = backdropBaseHeight + stretch
            let visualHeight = baseHeight + stretch
            let renderedSize: CGSize
            if stretch > 0 {
                let scale = 1 + min(0.22, stretch / 420)
                renderedSize = CGSize(width: initialSize.width * scale, height: initialSize.height * scale)
            } else {
                let targetHeight = max(fullRevealSize.height, initialSize.height - consumedCropScroll)
                let aspect = initialSize.height > 1 ? initialSize.width / initialSize.height : 1
                renderedSize = CGSize(width: targetHeight * aspect, height: targetHeight)
            }
            let clearImageBottom = AdaptiveHeroRevealMetrics.clearImageBottom(renderedImageSize: renderedSize, viewportHeight: backdropVisualHeight)
            let maskFadeSpan = min(0.34, clearImageBottom * 0.46)
            let maskStart = max(0.10, clearImageBottom - maskFadeSpan)
            let maskFirstMid = maskStart + (clearImageBottom - maskStart) * 0.29
            let maskSecondMid = maskStart + (clearImageBottom - maskStart) * 0.71
            frame = CGRect(x: 0, y: min(0, rawScrollMinY), width: width, height: visualHeight)
            clipView.frame = CGRect(x: 0, y: 0, width: width, height: backdropVisualHeight)
            imageView.frame = CGRect(x: (width - renderedSize.width) * 0.5, y: backdropPinOffset, width: renderedSize.width, height: renderedSize.height)
            maskGradient.frame = clipView.bounds
            maskGradient.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.black.withAlphaComponent(0.92).cgColor, UIColor.black.withAlphaComponent(0.52).cgColor, UIColor.clear.cgColor]
            maskGradient.locations = [NSNumber(value: 0.00), NSNumber(value: Double(maskStart)), NSNumber(value: Double(maskFirstMid)), NSNumber(value: Double(maskSecondMid)), NSNumber(value: Double(clearImageBottom))]
            contrastGradient.frame = bounds
            updateContrast()
        }
    }

    private final class PageNode {
        let itemID: String
        var item: V3HomeCarouselPresentationItem
        let artwork = ArtworkView()
        let foregroundController: UIHostingController<V3HomeCarouselForegroundStaticView>

        init(item: V3HomeCarouselPresentationItem, resource: V3HomeCarouselNativeResource) {
            itemID = item.id
            self.item = item
            artwork.imageView.image = resource.heroImage
            artwork.analysis = resource.analysis
            foregroundController = UIHostingController(rootView: V3HomeCarouselForegroundStaticView(item: item, logoImage: resource.logoImage, usesLight: resource.analysis?.prefersLightForeground ?? true))
            foregroundController.view.backgroundColor = .clear
            foregroundController.view.isUserInteractionEnabled = false
            artwork.updateContrast()
        }

        func update(item: V3HomeCarouselPresentationItem, resource: V3HomeCarouselNativeResource) {
            self.item = item
            artwork.imageView.image = resource.heroImage
            artwork.analysis = resource.analysis
            foregroundController.rootView = V3HomeCarouselForegroundStaticView(item: item, logoImage: resource.logoImage, usesLight: resource.analysis?.prefersLightForeground ?? true)
            artwork.updateContrast()
        }
    }

    private let baseColorView = UIView()
    private let artworkContainer = UIView()
    private let foregroundContainer = UIView()
    private let indicatorContainer = UIView()
    private var pages: [String: PageNode] = [:]
    private var orderedIDs: [String] = []
    private var indicatorViews: [String: UIView] = [:]
    private var resources: [String: V3HomeCarouselNativeResource] = [:]
    private var animator: UIViewPropertyAnimator?
    private var visualState = V3HomeCarouselTransitionVisualState(currentID: nil, fromID: nil, toID: nil, direction: 1, progress: 0)
    private var presentationWidth: CGFloat = 0
    private var viewportHeight: CGFloat = 0
    private var surfaceHeight: CGFloat = 0
    private var displayRange: Double = 0.30
    private var rawScrollMinY: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        addSubview(baseColorView)
        addSubview(artworkContainer)
        addSubview(foregroundContainer)
        addSubview(indicatorContainer)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        baseColorView.frame = bounds
        artworkContainer.frame = bounds
        foregroundContainer.frame = bounds
        layoutVisiblePages()
        layoutIndicators()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateBaseColor(progress: visualState.progress)
    }

    func configure(items: [V3HomeCarouselPresentationItem], resources: [String: V3HomeCarouselNativeResource]) {
        self.resources = resources
        let newIDs = items.map(\.id)
        let newIDSet = Set(newIDs)
        for (id, page) in pages where !newIDSet.contains(id) {
            page.artwork.removeFromSuperview()
            page.foregroundController.view.removeFromSuperview()
            pages[id] = nil
        }
        for item in items {
            let resource = resources[item.id] ?? V3HomeCarouselNativeResource(heroImage: nil, logoImage: nil, analysis: nil)
            if let page = pages[item.id] { page.update(item: item, resource: resource) }
            else {
                let page = PageNode(item: item, resource: resource)
                pages[item.id] = page
                artworkContainer.addSubview(page.artwork)
                foregroundContainer.addSubview(page.foregroundController.view)
            }
        }
        orderedIDs = newIDs
        rebuildIndicatorsIfNeeded()
        layoutVisiblePages()
        applyVisualState(visualState, animated: false)
    }

    func setHeroImage(_ image: UIImage, itemID: String) {
        resources[itemID] = V3HomeCarouselNativeResource(heroImage: image, logoImage: resources[itemID]?.logoImage, analysis: resources[itemID]?.analysis)
        pages[itemID]?.artwork.imageView.image = image
        layoutVisiblePages()
    }

    func setLogoImage(_ image: UIImage, itemID: String) {
        let old = resources[itemID]
        let resource = V3HomeCarouselNativeResource(heroImage: old?.heroImage, logoImage: image, analysis: old?.analysis)
        resources[itemID] = resource
        guard let page = pages[itemID] else { return }
        page.update(item: page.item, resource: resource)
    }

    func setImageAnalysis(_ analysis: V3HomeCarouselImageAnalysis, itemID: String) {
        let old = resources[itemID]
        let resource = V3HomeCarouselNativeResource(heroImage: old?.heroImage, logoImage: old?.logoImage, analysis: analysis)
        resources[itemID] = resource
        guard let page = pages[itemID] else { return }
        page.update(item: page.item, resource: resource)
        layoutVisiblePages()
        updateBaseColor(progress: visualState.progress)
    }

    func updateGeometry(width: CGFloat, viewportHeight: CGFloat, surfaceHeight: CGFloat, displayRange: Double, rawScrollMinY: CGFloat) {
        presentationWidth = width
        self.viewportHeight = viewportHeight
        self.surfaceHeight = surfaceHeight
        self.displayRange = displayRange
        self.rawScrollMinY = rawScrollMinY
        if bounds.size != CGSize(width: width, height: surfaceHeight) { frame.size = CGSize(width: width, height: surfaceHeight) }
        setNeedsLayout()
        layoutIfNeeded()
    }

    func updateRawScrollMinY(_ value: CGFloat) {
        rawScrollMinY = value
        layoutVisiblePages()
        layoutIndicators()
    }

    func applyVisualState(_ state: V3HomeCarouselTransitionVisualState, animated: Bool) {
        visualState = state
        let progress = min(1, max(0, state.progress))
        let blend = V3HomeCarouselNativeLayout.backdropBlendProgress(progress)
        let width = max(1, presentationWidth)
        for (id, page) in pages {
            if let fromID = state.fromID, let toID = state.toID {
                if id == fromID {
                    page.artwork.isHidden = false; page.foregroundController.view.isHidden = false
                    page.artwork.alpha = 1 - blend; page.foregroundController.view.alpha = 1
                    page.foregroundController.view.transform = CGAffineTransform(translationX: -CGFloat(state.direction) * progress * width, y: 0)
                } else if id == toID {
                    page.artwork.isHidden = false; page.foregroundController.view.isHidden = false
                    page.artwork.alpha = blend; page.foregroundController.view.alpha = 1
                    page.foregroundController.view.transform = CGAffineTransform(translationX: CGFloat(state.direction) * (1 - progress) * width, y: 0)
                } else {
                    page.artwork.isHidden = true; page.foregroundController.view.isHidden = true
                    page.artwork.alpha = 0; page.foregroundController.view.alpha = 0; page.foregroundController.view.transform = .identity
                }
            } else {
                let visible = id == state.currentID
                page.artwork.isHidden = !visible; page.foregroundController.view.isHidden = !visible
                page.artwork.alpha = visible ? 1 : 0; page.foregroundController.view.alpha = visible ? 1 : 0; page.foregroundController.view.transform = .identity
            }
        }
        layoutVisiblePages()
        updateBaseColor(progress: progress)
        updateIndicatorSelection(state.toID != nil && progress >= 0.5 ? state.toID : state.currentID)
        if !animated { V3HomeCarouselCadenceDiagnostics.shared.recordSwiftUIUpdate(progress) }
    }

    func animateVisualState(_ state: V3HomeCarouselTransitionVisualState, duration: TimeInterval, curve: UIView.AnimationCurve, completion: @escaping () -> Void) {
        stopAnimation()
        let targetProgress = min(1, max(0, state.progress))
        visualState = state
        layoutVisiblePages()
        let animator = UIViewPropertyAnimator(duration: duration, curve: curve) { [weak self] in self?.applyAnimatedTarget(state, targetProgress: targetProgress) }
        self.animator = animator
        animator.addCompletion { [weak self] position in
            guard let self else { return }
            self.animator = nil
            self.visualState = state
            self.applyVisualState(state, animated: false)
            if position == .end { completion() }
        }
        animator.startAnimation()
    }

    func interruptAndReadProgress(fromID: String?, toID: String?, direction: Int, fallback: CGFloat) -> CGFloat {
        let width = max(1, presentationWidth)
        var progress = min(1, max(0, fallback))
        if let fromID, let page = pages[fromID], let presentation = page.foregroundController.view.layer.presentation() {
            progress = min(1, max(0, abs(CGFloat(presentation.transform.m41)) / width))
        }
        stopAnimation()
        let state = V3HomeCarouselTransitionVisualState(currentID: visualState.currentID, fromID: fromID, toID: toID, direction: direction, progress: progress)
        applyVisualState(state, animated: false)
        return progress
    }

    func stopAnimation() {
        animator?.stopAnimation(true)
        animator = nil
    }

    private func applyAnimatedTarget(_ state: V3HomeCarouselTransitionVisualState, targetProgress: CGFloat) {
        let width = max(1, presentationWidth)
        let blend = V3HomeCarouselNativeLayout.backdropBlendProgress(targetProgress)
        if let fromID = state.fromID, let toID = state.toID {
            if let from = pages[fromID] { from.artwork.alpha = 1 - blend; from.foregroundController.view.transform = CGAffineTransform(translationX: -CGFloat(state.direction) * targetProgress * width, y: 0) }
            if let to = pages[toID] { to.artwork.alpha = blend; to.foregroundController.view.transform = CGAffineTransform(translationX: CGFloat(state.direction) * (1 - targetProgress) * width, y: 0) }
        }
        updateBaseColor(progress: targetProgress)
        updateIndicatorSelection(state.toID != nil && targetProgress >= 0.5 ? state.toID : state.currentID)
    }

    private func layoutVisiblePages() {
        guard presentationWidth > 0, viewportHeight > 0 else { return }
        let adjustment = V3HomeCarouselNativeLayout.displayHeightAdjustment(displayRange: displayRange, viewportHeight: viewportHeight)
        let baseHeight = AdaptiveHeroRevealMetrics.detailForegroundBaseHeight(width: presentationWidth, viewportHeight: viewportHeight) + adjustment
        let stretch = max(0, rawScrollMinY)
        let visualHeight = baseHeight + stretch
        let heroY = min(0, rawScrollMinY)
        for page in pages.values where !page.artwork.isHidden || !page.foregroundController.view.isHidden {
            page.artwork.layoutArtwork(width: presentationWidth, viewportHeight: viewportHeight, displayRange: displayRange, rawScrollMinY: rawScrollMinY)
            page.foregroundController.view.frame = CGRect(x: 0, y: heroY, width: presentationWidth, height: visualHeight)
        }
    }

    private func resolvedBaseColor(itemID: String?) -> UIColor {
        let system = traitCollection.userInterfaceStyle == .dark ? UIColor.black : UIColor.white
        guard let itemID, let analysis = resources[itemID]?.analysis else { return system }
        let sampled = UIColor(red: analysis.red, green: analysis.green, blue: analysis.blue, alpha: 1)
        return mix(sampled, system, amount: traitCollection.userInterfaceStyle == .dark ? 0.62 : 0.72)
    }

    private func updateBaseColor(progress: CGFloat) {
        guard let fromID = visualState.fromID, let toID = visualState.toID else { baseColorView.backgroundColor = resolvedBaseColor(itemID: visualState.currentID); return }
        let blend = V3HomeCarouselNativeLayout.backdropBlendProgress(progress)
        baseColorView.backgroundColor = mix(resolvedBaseColor(itemID: fromID), resolvedBaseColor(itemID: toID), amount: blend)
    }

    private func mix(_ a: UIColor, _ b: UIColor, amount: CGFloat) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        guard a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa), b.getRed(&br, green: &bg, blue: &bb, alpha: &ba) else { return b }
        let t = min(1, max(0, amount))
        return UIColor(red: ar + (br - ar) * t, green: ag + (bg - ag) * t, blue: ab + (bb - ab) * t, alpha: aa + (ba - aa) * t)
    }

    private func rebuildIndicatorsIfNeeded() {
        guard Set(indicatorViews.keys) != Set(orderedIDs) || indicatorViews.count != orderedIDs.count else { return }
        indicatorViews.values.forEach { $0.removeFromSuperview() }
        indicatorViews.removeAll()
        for id in orderedIDs { let dot = UIView(); dot.isUserInteractionEnabled = false; indicatorContainer.addSubview(dot); indicatorViews[id] = dot }
    }

    private func layoutIndicators() {
        guard presentationWidth > 0, viewportHeight > 0 else { return }
        let adjustment = V3HomeCarouselNativeLayout.displayHeightAdjustment(displayRange: displayRange, viewportHeight: viewportHeight)
        let baseHeight = AdaptiveHeroRevealMetrics.detailForegroundBaseHeight(width: presentationWidth, viewportHeight: viewportHeight) + adjustment
        let heroY = min(0, rawScrollMinY)
        let height: CGFloat = 18
        indicatorContainer.frame = CGRect(x: 0, y: heroY + baseHeight - 36, width: presentationWidth, height: height)
        let spacing: CGFloat = 8
        let widths = orderedIDs.map { indicatorViews[$0]?.bounds.width == 7 ? CGFloat(7) : CGFloat(6) }
        let totalWidth = widths.reduce(0, +) + spacing * CGFloat(max(0, widths.count - 1))
        var x = (presentationWidth - totalWidth) * 0.5
        for (index, id) in orderedIDs.enumerated() {
            let size = widths[index]
            let dot = indicatorViews[id]
            dot?.frame = CGRect(x: x, y: (height - size) * 0.5, width: size, height: size)
            dot?.layer.cornerRadius = size * 0.5
            x += size + spacing
        }
    }

    private func updateIndicatorSelection(_ selectedID: String?) {
        for (id, dot) in indicatorViews {
            let selected = id == selectedID
            let size: CGFloat = selected ? 7 : 6
            dot.backgroundColor = UIColor.label.withAlphaComponent(selected ? 0.88 : 0.26)
            dot.bounds.size = CGSize(width: size, height: size)
            dot.layer.cornerRadius = size * 0.5
        }
        layoutIndicators()
    }
}
