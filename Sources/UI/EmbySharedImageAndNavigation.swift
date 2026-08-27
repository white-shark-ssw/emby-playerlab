import SwiftUI
import UIKit
import Foundation
import Combine
import CoreImage
import ImageIO
import QuartzCore

final class EmbyDecodedImageRenderPool: @unchecked Sendable {
    static let shared = EmbyDecodedImageRenderPool()
    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 64
        cache.totalCostLimit = 96 * 1024 * 1024
    }

    func image(for url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }

    func store(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    func clear() { cache.removeAllObjects() }
}

final class EmbyPosterScrollHitchDiagnostics: NSObject {
    static let shared = EmbyPosterScrollHitchDiagnostics()

    private struct PosterEvent {
        let itemID: String
        let route: String
        let timestamp: CFTimeInterval
    }

    private struct ImageEvent {
        let itemID: String
        let imageType: String
        let maxWidth: String
        let source: String
        let role: String
        let timestamp: CFTimeInterval
    }

    private struct TimedImageEvent {
        let itemID: String
        let imageType: String
        let maxWidth: String
        let source: String
        let durationMS: Double
        let timestamp: CFTimeInterval
    }

    private var displayLink: CADisplayLink?
    private var lastDisplayTimestamp: CFTimeInterval?
    private var visiblePosterCount = 0
    private var lastCellAppear: PosterEvent?
    private var lastImageCommit: ImageEvent?
    private var lastImageCallback: TimedImageEvent?
    private var lastContrastDurationMS: Double?
    private var lastContrastCompletedAt: CFTimeInterval?
    private var lastLoadAhead: PosterEvent?
    private final class ScrollObservation {
        weak var scrollView: UIScrollView?
        var route: String
        var lastOffsetY: CGFloat

        init(scrollView: UIScrollView, route: String) {
            self.scrollView = scrollView
            self.route = route
            lastOffsetY = scrollView.contentOffset.y
        }
    }

    private var scrollObservations: [UUID: ScrollObservation] = [:]

    private override init() {}

    func posterDidAppear(itemID: String, route: String) {
        precondition(Thread.isMainThread)
        visiblePosterCount += 1
        lastCellAppear = PosterEvent(itemID: itemID, route: route, timestamp: CACurrentMediaTime())
        ensureDisplayLink()
    }

    func posterDidDisappear() {
        precondition(Thread.isMainThread)
        visiblePosterCount = max(0, visiblePosterCount - 1)
        if visiblePosterCount == 0 { stopDisplayLink() }
    }

    func imageDidCommit(url: URL, source: String, role: String) {
        precondition(Thread.isMainThread)
        let context = imageContext(url)
        lastImageCommit = ImageEvent(itemID: context.itemID, imageType: context.imageType, maxWidth: context.maxWidth, source: source, role: role, timestamp: CACurrentMediaTime())
    }

    func imageCallbackDidComplete(url: URL?, source: String, durationMS: Double) {
        precondition(Thread.isMainThread)
        guard let url else { return }
        let context = imageContext(url)
        lastImageCallback = TimedImageEvent(itemID: context.itemID, imageType: context.imageType, maxWidth: context.maxWidth, source: source, durationMS: durationMS, timestamp: CACurrentMediaTime())
    }

    func contrastDidComplete(durationMS: Double) {
        precondition(Thread.isMainThread)
        lastContrastDurationMS = durationMS
        lastContrastCompletedAt = CACurrentMediaTime()
    }

    func loadAheadDidTrigger(itemID: String) {
        precondition(Thread.isMainThread)
        lastLoadAhead = PosterEvent(itemID: itemID, route: "grid-load-ahead", timestamp: CACurrentMediaTime())
    }

    func observeVerticalScrollView(_ scrollView: UIScrollView, ownerID: UUID, route: String) {
        precondition(Thread.isMainThread)
        if let observation = scrollObservations[ownerID], observation.scrollView === scrollView {
            observation.route = route
        } else {
            scrollObservations[ownerID] = ScrollObservation(scrollView: scrollView, route: route)
        }
    }

    func stopObservingVerticalScrollView(ownerID: UUID) {
        precondition(Thread.isMainThread)
        scrollObservations.removeValue(forKey: ownerID)
    }

    private func ensureDisplayLink() {
        guard displayLink == nil else { return }
        lastDisplayTimestamp = nil
        let link = CADisplayLink(target: self, selector: #selector(displayLinkTick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        lastDisplayTimestamp = nil
    }

    @objc private func displayLinkTick(_ link: CADisplayLink) {
        var movingSamples: [(scrollView: UIScrollView, route: String, deltaY: CGFloat)] = []
        var staleOwnerIDs: [UUID] = []
        for (ownerID, observation) in scrollObservations {
            guard let scrollView = observation.scrollView else {
                staleOwnerIDs.append(ownerID)
                continue
            }
            let currentOffsetY = scrollView.contentOffset.y
            let deltaY = currentOffsetY - observation.lastOffsetY
            observation.lastOffsetY = currentOffsetY
            if deltaY != 0 { movingSamples.append((scrollView, observation.route, deltaY)) }
        }
        for ownerID in staleOwnerIDs { scrollObservations.removeValue(forKey: ownerID) }

        guard let previous = lastDisplayTimestamp else {
            lastDisplayTimestamp = link.timestamp
            return
        }
        let gap = link.timestamp - previous
        lastDisplayTimestamp = link.timestamp
        guard gap >= 0.030 else { return }
        guard let sample = movingSamples.max(by: { lhs, rhs in
            let lhsPhase = lhs.scrollView.isDragging ? 2 : (lhs.scrollView.isDecelerating ? 1 : 0)
            let rhsPhase = rhs.scrollView.isDragging ? 2 : (rhs.scrollView.isDecelerating ? 1 : 0)
            if lhsPhase != rhsPhase { return lhsPhase < rhsPhase }
            return abs(lhs.deltaY) < abs(rhs.deltaY)
        }) else { return }

        let scrollView = sample.scrollView
        let deltaY = sample.deltaY
        let now = link.timestamp
        let cellAge = lastCellAppear.map { max(0, (now - $0.timestamp) * 1000) } ?? -1
        let imageAge = lastImageCommit.map { max(0, (now - $0.timestamp) * 1000) } ?? -1
        let callbackAge = lastImageCallback.map { max(0, (now - $0.timestamp) * 1000) } ?? -1
        let contrastAge = lastContrastCompletedAt.map { max(0, (now - $0) * 1000) } ?? -1
        let loadAheadAge = lastLoadAhead.map { max(0, (now - $0.timestamp) * 1000) } ?? -1
        let gapText = String(format: "%.1f", gap * 1000)
        let offsetText = String(format: "%.2f", scrollView.contentOffset.y)
        let deltaText = String(format: "%.2f", deltaY)
        let velocityText = String(format: "%.1f", scrollView.panGestureRecognizer.velocity(in: scrollView).y)
        let cellAgeText = String(format: "%.1f", cellAge)
        let imageAgeText = String(format: "%.1f", imageAge)
        let callbackAgeText = String(format: "%.1f", callbackAge)
        let callbackDurationText = String(format: "%.1f", lastImageCallback?.durationMS ?? -1)
        let contrastAgeText = String(format: "%.1f", contrastAge)
        let contrastDurationText = String(format: "%.1f", lastContrastDurationMS ?? -1)
        let loadAheadAgeText = String(format: "%.1f", loadAheadAge)
        let phase = scrollView.isDragging ? "dragging" : (scrollView.isDecelerating ? "decelerating" : "moving")
        let lastCellID = lastCellAppear?.itemID ?? "none"
        let lastCellRoute = lastCellAppear?.route ?? "none"
        let lastImageItemID = lastImageCommit?.itemID ?? "none"
        let lastImageType = lastImageCommit?.imageType ?? "none"
        let lastImageMaxWidth = lastImageCommit?.maxWidth ?? "none"
        let lastImageSource = lastImageCommit?.source ?? "none"
        let lastImageRole = lastImageCommit?.role ?? "none"
        let lastCallbackItemID = lastImageCallback?.itemID ?? "none"
        let lastCallbackImageType = lastImageCallback?.imageType ?? "none"
        let lastCallbackMaxWidth = lastImageCallback?.maxWidth ?? "none"
        let lastCallbackSource = lastImageCallback?.source ?? "none"
        let lastLoadAheadID = lastLoadAhead?.itemID ?? "none"
        DiagnosticsLogger.shared.log("PosterScrollHitch", "frame_gap_ms=\(gapText) scroll_route=\(sample.route) phase=\(phase) offset_y=\(offsetText) delta_y=\(deltaText) velocity_y=\(velocityText) registered_scrolls=\(scrollObservations.count) moving_scrolls=\(movingSamples.count) visible=\(visiblePosterCount) last_cell=\(lastCellID) cell_route=\(lastCellRoute) cell_age_ms=\(cellAgeText) image_item=\(lastImageItemID) image_type=\(lastImageType) image_max_width=\(lastImageMaxWidth) image_source=\(lastImageSource) image_role=\(lastImageRole) image_age_ms=\(imageAgeText) callback_item=\(lastCallbackItemID) callback_type=\(lastCallbackImageType) callback_max_width=\(lastCallbackMaxWidth) callback_source=\(lastCallbackSource) callback_age_ms=\(callbackAgeText) callback_duration_ms=\(callbackDurationText) contrast_age_ms=\(contrastAgeText) contrast_duration_ms=\(contrastDurationText) load_ahead=\(lastLoadAheadID) load_ahead_age_ms=\(loadAheadAgeText)")
    }

    private func imageContext(_ url: URL) -> (itemID: String, imageType: String, maxWidth: String) {
        let components = url.pathComponents
        let itemID: String
        if let itemsIndex = components.firstIndex(of: "Items"), components.indices.contains(itemsIndex + 1) { itemID = components[itemsIndex + 1] }
        else { itemID = "unknown" }
        let imageType: String
        if let imagesIndex = components.firstIndex(of: "Images"), components.indices.contains(imagesIndex + 1) { imageType = components[imagesIndex + 1] }
        else { imageType = "unknown" }
        let maxWidth = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name.caseInsensitiveCompare("MaxWidth") == .orderedSame })?.value ?? "none"
        return (itemID, imageType, maxWidth)
    }

}

final class EmbyPosterScrollMotionProbeView: UIView {
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

struct EmbyPosterScrollMotionProbe: UIViewRepresentable {
    let route: String

    func makeCoordinator() -> Coordinator { Coordinator(route: route) }

    func makeUIView(context: Context) -> EmbyPosterScrollMotionProbeView {
        let view = EmbyPosterScrollMotionProbeView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.hierarchyDidChange = { [weak coordinator = context.coordinator] probe in coordinator?.attach(from: probe) }
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak view] in
            guard let view else { return }
            coordinator?.attach(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: EmbyPosterScrollMotionProbeView, context: Context) {
        context.coordinator.route = route
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak uiView] in
            guard let uiView else { return }
            coordinator?.attach(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: EmbyPosterScrollMotionProbeView, coordinator: Coordinator) {
        uiView.hierarchyDidChange = nil
        coordinator.detach()
    }

    final class Coordinator {
        let ownerID = UUID()
        var route: String
        private weak var scrollView: UIScrollView?

        init(route: String) { self.route = route }

        func attach(from probe: UIView) {
            guard let scrollView = ancestorVerticalScrollView(from: probe) else { return }
            if self.scrollView !== scrollView {
                if self.scrollView != nil { EmbyPosterScrollHitchDiagnostics.shared.stopObservingVerticalScrollView(ownerID: ownerID) }
                self.scrollView = scrollView
            }
            EmbyPosterScrollHitchDiagnostics.shared.observeVerticalScrollView(scrollView, ownerID: ownerID, route: route)
        }

        func detach() {
            EmbyPosterScrollHitchDiagnostics.shared.stopObservingVerticalScrollView(ownerID: ownerID)
            scrollView = nil
        }

        private func ancestorVerticalScrollView(from probe: UIView) -> UIScrollView? {
            var current: UIView? = probe
            while let view = current {
                if let scrollView = view as? UIScrollView, !scrollView.isPagingEnabled { return scrollView }
                current = view.superview
            }
            return nil
        }
    }
}

private final class EmbyCachedImageLoader: ObservableObject {
    struct PublishContext {
        let url: URL
        let source: String
        let role: String
    }

    @Published var image: UIImage?
    @Published var isLoading = false
    private(set) var lastPublishContext: PublishContext?
    private var currentURL: URL?
    private var task: Task<Void, Never>?

    init(initialURL: URL? = nil) {
        currentURL = initialURL
        image = initialURL.flatMap { EmbyDecodedImageRenderPool.shared.image(for: $0) }
    }

    private func setLoading(_ value: Bool, reportsLoadingState: Bool) {
        if !reportsLoadingState {
            if isLoading { isLoading = false }
            return
        }
        guard isLoading != value else { return }
        isLoading = value
    }

    func load(_ url: URL?, reportsLoadingState: Bool, diagnosticRole: String) {
        guard currentURL != url || image == nil else { return }
        currentURL = url
        task?.cancel()
        guard let url else {
            if image != nil { image = nil }
            setLoading(false, reportsLoadingState: reportsLoadingState)
            return
        }
        if let rendered = EmbyDecodedImageRenderPool.shared.image(for: url) {
            lastPublishContext = PublishContext(url: url, source: "memory", role: diagnosticRole)
            image = rendered
            EmbyPosterScrollHitchDiagnostics.shared.imageDidCommit(url: url, source: "memory", role: diagnosticRole)
            setLoading(false, reportsLoadingState: reportsLoadingState)
            return
        }
        if image != nil { image = nil }
        setLoading(true, reportsLoadingState: reportsLoadingState)
        task = Task { [weak self] in
            do {
                var data = await EmbyImageDiskCache.shared.data(for: url)
                if let cachedData = data {
                    let cachedImage = await Task.detached(priority: .utility) { EmbyImageDecoder.decode(data: cachedData, url: url) }.value
                    if let cachedImage {
                        guard !Task.isCancelled else { return }
                        EmbyDecodedImageRenderPool.shared.store(cachedImage, for: url)
                        await MainActor.run {
                            guard let self, self.currentURL == url else { return }
                            self.lastPublishContext = PublishContext(url: url, source: "disk", role: diagnosticRole)
                            self.image = cachedImage
                            EmbyPosterScrollHitchDiagnostics.shared.imageDidCommit(url: url, source: "disk", role: diagnosticRole)
                            self.setLoading(false, reportsLoadingState: reportsLoadingState)
                        }
                        return
                    }
                    await EmbyImageDiskCache.shared.remove(url)
                    data = nil
                }

                if data == nil {
                    let response = try await URLSession.shared.data(from: url)
                    data = response.0
                    await EmbyImageDiskCache.shared.store(response.0, for: url)
                }
                guard !Task.isCancelled, let data else { return }
                let loaded = await Task.detached(priority: .utility) { EmbyImageDecoder.decode(data: data, url: url) }.value
                guard !Task.isCancelled, let loaded else { return }
                EmbyDecodedImageRenderPool.shared.store(loaded, for: url)
                await MainActor.run {
                    guard let self, self.currentURL == url else { return }
                    self.lastPublishContext = PublishContext(url: url, source: "network", role: diagnosticRole)
                    self.image = loaded
                    EmbyPosterScrollHitchDiagnostics.shared.imageDidCommit(url: url, source: "network", role: diagnosticRole)
                    self.setLoading(false, reportsLoadingState: reportsLoadingState)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self?.currentURL == url else { return }
                    self?.setLoading(false, reportsLoadingState: reportsLoadingState)
                }
            }
        }
    }

    func cancel(reportsLoadingState: Bool) {
        task?.cancel()
        task = nil
        if image == nil { setLoading(false, reportsLoadingState: reportsLoadingState) }
    }
}

private enum EmbyImageDecoder {
    static func decode(data: Data, url: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return UIImage(data: data) }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let pixelWidth = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0
        let pixelHeight = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0
        let requestedWidth = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name.caseInsensitiveCompare("MaxWidth") == .orderedSame }).flatMap { Double($0.value ?? "") }
        let sourceMax = max(pixelWidth, pixelHeight)
        let targetMax: Double
        if let requestedWidth, requestedWidth > 0, pixelWidth > 0, pixelHeight > 0 {
            let scale = min(1, requestedWidth / pixelWidth)
            targetMax = max(1, ceil(sourceMax * scale))
        } else {
            targetMax = max(1, sourceMax)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(targetMax),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return UIImage(data: data) }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }
}

private final class EmbyPosterNavigationGate {
    static let shared = EmbyPosterNavigationGate()
    private let lock = NSLock()
    private var owner: String?
    private var acquiredAt = Date.distantPast
    private let timeout: TimeInterval = 1.25

    private init() {}

    func acquire(_ owner: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        if self.owner != nil && now.timeIntervalSince(acquiredAt) < timeout { return false }
        self.owner = owner
        acquiredAt = now
        return true
    }

    func release(_ owner: String) {
        lock.lock()
        defer { lock.unlock() }
        guard self.owner == owner else { return }
        self.owner = nil
        acquiredAt = .distantPast
    }
}

private final class EmbyPosterPressLock {
    static let shared = EmbyPosterPressLock()
    private var owner: UUID?
    private var contaminated = false
    private var acquiredAt = Date.distantPast
    private let timeout: TimeInterval = 2.0

    private init() {}

    func begin(_ id: UUID) -> Bool {
        precondition(Thread.isMainThread)
        let now = Date()
        if let owner {
            if now.timeIntervalSince(acquiredAt) >= timeout {
                self.owner = id
                contaminated = false
                acquiredAt = now
                return true
            }
            if owner != id { contaminated = true }
            return owner == id
        }
        owner = id
        contaminated = false
        acquiredAt = now
        return true
    }

    func contaminate() {
        precondition(Thread.isMainThread)
        if owner != nil { contaminated = true }
    }

    func end(_ id: UUID, trigger: Bool) -> Bool {
        precondition(Thread.isMainThread)
        guard owner == id else { return false }
        let shouldTrigger = trigger && !contaminated
        owner = nil
        contaminated = false
        acquiredAt = .distantPast
        return shouldTrigger
    }

    func abandon(_ id: UUID) {
        precondition(Thread.isMainThread)
        guard owner == id else { return }
        owner = nil
        contaminated = false
        acquiredAt = .distantPast
    }
}

private final class EmbyPosterTouchControl: UIControl {
    var onActiveTouchCountChanged: ((Int) -> Void)?

    private func reportTouchCount(_ event: UIEvent?) {
        let count = event?.allTouches?.reduce(into: 0) { partialResult, touch in
            if touch.phase != .ended && touch.phase != .cancelled { partialResult += 1 }
        } ?? 1
        onActiveTouchCountChanged?(count)
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        reportTouchCount(event)
        return super.beginTracking(touch, with: event)
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        reportTouchCount(event)
        return super.continueTracking(touch, with: event)
    }
}

private struct EmbyExclusivePosterTapControl: UIViewRepresentable {
    let action: () -> Void

    final class Coordinator: NSObject {
        let id = UUID()
        var action: () -> Void
        var ownsPressLock = false

        init(action: @escaping () -> Void) { self.action = action }

        deinit {
            if ownsPressLock { EmbyPosterPressLock.shared.abandon(id) }
        }

        @objc func touchDown() {
            guard !ownsPressLock else { return }
            ownsPressLock = EmbyPosterPressLock.shared.begin(id)
        }

        @objc func touchUpInside() {
            guard ownsPressLock else { return }
            ownsPressLock = false
            if EmbyPosterPressLock.shared.end(id, trigger: true) { action() }
        }

        @objc func touchEnded() {
            guard ownsPressLock else { return }
            ownsPressLock = false
            _ = EmbyPosterPressLock.shared.end(id, trigger: false)
        }

        func activeTouchCountChanged(_ count: Int) {
            if count > 1 { EmbyPosterPressLock.shared.contaminate() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> UIControl {
        let control = EmbyPosterTouchControl(frame: .zero)
        control.backgroundColor = .clear
        control.isOpaque = false
        control.isExclusiveTouch = false
        control.isMultipleTouchEnabled = false
        control.onActiveTouchCountChanged = { [weak coordinator = context.coordinator] count in coordinator?.activeTouchCountChanged(count) }
        control.addTarget(context.coordinator, action: #selector(Coordinator.touchDown), for: .touchDown)
        control.addTarget(context.coordinator, action: #selector(Coordinator.touchUpInside), for: .touchUpInside)
        control.addTarget(context.coordinator, action: #selector(Coordinator.touchEnded), for: [.touchCancel, .touchUpOutside])
        return control
    }

    func updateUIView(_ uiView: UIControl, context: Context) { context.coordinator.action = action }
}

private final class EmbyCachedDisplayImageSurfaceView: UIView {
    let imageView = UIImageView(frame: .zero)
    let placeholderView = UIImageView(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        isUserInteractionEnabled = false
        imageView.backgroundColor = .clear
        imageView.clipsToBounds = true
        imageView.frame = bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        placeholderView.contentMode = .center
        placeholderView.frame = bounds
        placeholderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(placeholderView)
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { nil }

    func configure(contentMode: SwiftUI.ContentMode, placeholderSystemImage: String) {
        imageView.contentMode = contentMode == .fill ? .scaleAspectFill : .scaleAspectFit
        placeholderView.image = UIImage(systemName: placeholderSystemImage, withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .medium))
        placeholderView.tintColor = UIColor.secondaryLabel.withAlphaComponent(0.62)
    }

    func setImage(_ image: UIImage?) {
        imageView.image = image
        backgroundColor = image == nil ? .secondarySystemBackground : .clear
        placeholderView.isHidden = image != nil
    }
}

private struct EmbyCachedDisplayImageSurface: UIViewRepresentable {
    let loader: EmbyCachedImageLoader
    let contentMode: ContentMode
    let placeholderSystemImage: String

    func makeCoordinator() -> Coordinator { Coordinator(loader: loader) }

    func makeUIView(context: Context) -> EmbyCachedDisplayImageSurfaceView {
        let view = EmbyCachedDisplayImageSurfaceView(frame: .zero)
        view.configure(contentMode: contentMode, placeholderSystemImage: placeholderSystemImage)
        context.coordinator.attach(view)
        return view
    }

    func updateUIView(_ uiView: EmbyCachedDisplayImageSurfaceView, context: Context) {
        uiView.configure(contentMode: contentMode, placeholderSystemImage: placeholderSystemImage)
    }

    static func dismantleUIView(_ uiView: EmbyCachedDisplayImageSurfaceView, coordinator: Coordinator) { coordinator.detach() }

    final class Coordinator {
        private let loader: EmbyCachedImageLoader
        private weak var surface: EmbyCachedDisplayImageSurfaceView?
        private var imageCancellable: AnyCancellable?

        init(loader: EmbyCachedImageLoader) {
            self.loader = loader
            imageCancellable = loader.$image.sink { [weak self] image in self?.surface?.setImage(image) }
        }

        func attach(_ surface: EmbyCachedDisplayImageSurfaceView) {
            self.surface = surface
            surface.setImage(loader.image)
        }

        func detach() {
            surface = nil
            imageCancellable?.cancel()
            imageCancellable = nil
        }
    }
}

private struct EmbyCachedDisplayRemoteImage: View {
    let url: URL?
    let contentMode: ContentMode
    let placeholderSystemImage: String
    @State private var loader: EmbyCachedImageLoader

    init(url: URL?, contentMode: ContentMode, placeholderSystemImage: String) {
        self.url = url
        self.contentMode = contentMode
        self.placeholderSystemImage = placeholderSystemImage
        _loader = State(initialValue: EmbyCachedImageLoader(initialURL: url))
    }

    var body: some View {
        EmbyCachedDisplayImageSurface(loader: loader, contentMode: contentMode, placeholderSystemImage: placeholderSystemImage)
            .onAppear { loader.load(url, reportsLoadingState: false, diagnosticRole: "display") }
            .onDisappear { loader.cancel(reportsLoadingState: false) }
            .onChange(of: url) { loader.load($0, reportsLoadingState: false, diagnosticRole: "display") }
    }
}

struct EmbyCachedRemoteImage: View {
    let url: URL?
    let contentMode: ContentMode
    let placeholderSystemImage: String
    let showsLoadingIndicator: Bool
    let onImageLoaded: ((UIImage) -> Void)?
    @StateObject private var loader: EmbyCachedImageLoader
    @State private var reportedImageIdentifier: ObjectIdentifier?

    init(url: URL?, contentMode: ContentMode, placeholderSystemImage: String = "photo", showsLoadingIndicator: Bool = true, onImageLoaded: ((UIImage) -> Void)? = nil) {
        self.url = url
        self.contentMode = contentMode
        self.placeholderSystemImage = placeholderSystemImage
        self.showsLoadingIndicator = showsLoadingIndicator
        self.onImageLoaded = onImageLoaded
        _loader = StateObject(wrappedValue: EmbyCachedImageLoader(initialURL: onImageLoaded == nil && showsLoadingIndicator ? url : nil))
    }

    var body: some View {
        if onImageLoaded == nil && !showsLoadingIndicator {
            EmbyCachedDisplayRemoteImage(url: url, contentMode: contentMode, placeholderSystemImage: placeholderSystemImage)
        } else if let onImageLoaded {
            imageBody.onReceive(loader.$image.compactMap { $0 }) { image in
                let identifier = ObjectIdentifier(image)
                guard reportedImageIdentifier != identifier else { return }
                reportedImageIdentifier = identifier
                let startedAt = CACurrentMediaTime()
                onImageLoaded(image)
                let durationMS = (CACurrentMediaTime() - startedAt) * 1000
                let publishContext = loader.lastPublishContext
                EmbyPosterScrollHitchDiagnostics.shared.imageCallbackDidComplete(url: publishContext?.url ?? url, source: publishContext?.source ?? "unknown", durationMS: durationMS)
            }
        } else {
            imageBody
        }
    }

    private var imageBody: some View {
        ZStack {
            if let image = loader.image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else {
                Color(uiColor: .secondarySystemBackground)
                Image(systemName: placeholderSystemImage).font(.system(size: 24, weight: .medium)).foregroundColor(.secondary.opacity(0.62))
                if showsLoadingIndicator && loader.isLoading { ProgressView() }
            }
        }
        .onAppear { loader.load(url, reportsLoadingState: showsLoadingIndicator, diagnosticRole: onImageLoaded == nil ? "display" : "callback") }
        .onDisappear { loader.cancel(reportsLoadingState: showsLoadingIndicator) }
        .onChange(of: url) {
            if onImageLoaded != nil { reportedImageIdentifier = nil }
            loader.load($0, reportsLoadingState: showsLoadingIndicator, diagnosticRole: onImageLoaded == nil ? "display" : "callback")
        }
    }
}

enum EmbyImageContrastAnalyzer {
    private static let context = CIContext()

    static func prefersLightForeground(for image: UIImage) -> Bool {
        guard let input = CIImage(image: image) else { return true }
        let extent = input.extent
        guard extent.width > 1, extent.height > 1 else { return true }
        let sample = CGRect(
            x: extent.minX + extent.width * 0.14,
            y: extent.minY + extent.height * 0.06,
            width: extent.width * 0.72,
            height: extent.height * 0.34
        ).intersection(extent)
        guard !sample.isNull, sample.width > 0, sample.height > 0,
              let filter = CIFilter(name: "CIAreaAverage") else { return true }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: sample), forKey: kCIInputExtentKey)
        guard let output = filter.outputImage else { return true }
        var pixel = [UInt8](repeating: 0, count: 4)
        let startedAt = CACurrentMediaTime()
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        if Thread.isMainThread { EmbyPosterScrollHitchDiagnostics.shared.contrastDidComplete(durationMS: (CACurrentMediaTime() - startedAt) * 1000) }
        let r = CGFloat(pixel[0]) / 255
        let g = CGFloat(pixel[1]) / 255
        let b = CGFloat(pixel[2]) / 255
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance < 0.56
    }
}

private struct EmbyPosterDetailDestination: View {
    let item: LibraryItem
    let client: EmbyAPIClient

    var body: some View {
        if item.type?.caseInsensitiveCompare("Episode") == .orderedSame, let seriesID = item.seriesId, !seriesID.isEmpty {
            EmbyEpisodeSeriesDestinationView(episode: item, seriesID: seriesID, client: client)
        } else {
            EmbyMediaDetailView(item: item, client: client)
        }
    }
}

private struct EmbyEpisodeSeriesDestinationView: View {
    let episode: LibraryItem
    let seriesID: String
    let client: EmbyAPIClient
    @State private var seriesItem: LibraryItem?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let seriesItem {
                EmbyMediaDetailView(item: seriesItem, client: client, initialEpisodeID: episode.id)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text("无法打开对应剧集").font(.headline)
                    Text(errorMessage).font(.footnote).foregroundColor(.secondary).multilineTextAlignment(.center)
                    Button("重试") { self.errorMessage = nil; Task { await loadSeries() } }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("正在打开剧集…").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .task { if seriesItem == nil && errorMessage == nil { await loadSeries() } }
    }

    @MainActor
    private func loadSeries() async {
        do { seriesItem = try await client.libraryItem(itemId: seriesID) }
        catch { if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription } }
    }
}

private struct EmbyGridPosterNavigationLink<Content: View>: View {
    @ObservedObject var state: EmbyPosterGridNavigationState
    let item: LibraryItem
    let client: EmbyAPIClient
    let content: Content

    var body: some View {
        NavigationLink(
            destination: EmbyPosterDetailDestination(item: item, client: client)
                .onAppear { state.destinationDidAppear(itemID: item.id) }
                .onDisappear { state.destinationDidDisappear(itemID: item.id) },
            tag: item.id,
            selection: state.selectionBinding(for: item.id)
        ) {
            content.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct EmbyPosterDetailLink<Content: View>: View {
    @Environment(\.embyPosterGridNavigationState) private var gridNavigationState
    let item: LibraryItem
    let client: EmbyAPIClient
    private let content: Content
    @State private var isActive = false

    init(item: LibraryItem, client: EmbyAPIClient, @ViewBuilder content: () -> Content) {
        self.item = item
        self.client = client
        self.content = content()
    }

    var body: some View {
        Group {
            if let gridNavigationState {
                EmbyGridPosterNavigationLink(state: gridNavigationState, item: item, client: client, content: content)
            } else {
                content
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !isActive, EmbyPosterNavigationGate.shared.acquire(item.id) else { return }
                        isActive = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) { EmbyPosterNavigationGate.shared.release(item.id) }
                    }
                    .background(
                        NavigationLink(destination: EmbyPosterDetailDestination(item: item, client: client), isActive: $isActive) { EmptyView() }
                            .frame(width: 0, height: 0)
                            .hidden()
                    )
                    .onChange(of: isActive) { active in
                        if !active { EmbyPosterNavigationGate.shared.release(item.id) }
                    }
            }
        }
        .onAppear { EmbyPosterScrollHitchDiagnostics.shared.posterDidAppear(itemID: item.id, route: gridNavigationState == nil ? "row" : "grid") }
        .onDisappear { EmbyPosterScrollHitchDiagnostics.shared.posterDidDisappear() }
    }
}
