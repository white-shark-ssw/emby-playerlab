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

    private var displayLink: CADisplayLink?
    private var lastDisplayTimestamp: CFTimeInterval?
    private var visiblePosterCount = 0
    private var lastCellAppear: PosterEvent?
    private var lastImageCommitAt: CFTimeInterval?
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

    func imageDidCommit() {
        precondition(Thread.isMainThread)
        lastImageCommitAt = CACurrentMediaTime()
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
        let imageAge = lastImageCommitAt.map { max(0, (now - $0) * 1000) } ?? -1
        let loadAheadAge = lastLoadAhead.map { max(0, (now - $0.timestamp) * 1000) } ?? -1
        let gapText = String(format: "%.1f", gap * 1000)
        let offsetText = String(format: "%.2f", scrollView.contentOffset.y)
        let deltaText = String(format: "%.2f", deltaY)
        let velocityText = String(format: "%.1f", scrollView.panGestureRecognizer.velocity(in: scrollView).y)
        let cellAgeText = String(format: "%.1f", cellAge)
        let imageAgeText = String(format: "%.1f", imageAge)
        let loadAheadAgeText = String(format: "%.1f", loadAheadAge)
        let phase = scrollView.isDragging ? "dragging" : (scrollView.isDecelerating ? "decelerating" : "moving")
        let lastCellID = lastCellAppear?.itemID ?? "none"
        let lastCellRoute = lastCellAppear?.route ?? "none"
        let lastLoadAheadID = lastLoadAhead?.itemID ?? "none"
        DiagnosticsLogger.shared.log("PosterScrollHitch", "frame_gap_ms=\(gapText) scroll_route=\(sample.route) phase=\(phase) offset_y=\(offsetText) delta_y=\(deltaText) velocity_y=\(velocityText) registered_scrolls=\(scrollObservations.count) moving_scrolls=\(movingSamples.count) visible=\(visiblePosterCount) last_cell=\(lastCellID) cell_route=\(lastCellRoute) cell_age_ms=\(cellAgeText) image_age_ms=\(imageAgeText) load_ahead=\(lastLoadAheadID) load_ahead_age_ms=\(loadAheadAgeText)")
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
    @Published var image: UIImage?
    @Published var isLoading = false
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

    func load(_ url: URL?, reportsLoadingState: Bool) {
        guard currentURL != url || image == nil else { return }
        currentURL = url
        task?.cancel()
        guard let url else {
            if image != nil { image = nil }
            setLoading(false, reportsLoadingState: reportsLoadingState)
            return
        }
        if let rendered = EmbyDecodedImageRenderPool.shared.image(for: url) {
            image = rendered
            EmbyPosterScrollHitchDiagnostics.shared.imageDidCommit()
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
                            guard self?.currentURL == url else { return }
                            self?.image = cachedImage
                            EmbyPosterScrollHitchDiagnostics.shared.imageDidCommit()
                            self?.setLoading(false, reportsLoadingState: reportsLoadingState)
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
                    guard self?.currentURL == url else { return }
                    self?.image = loaded
                    EmbyPosterScrollHitchDiagnostics.shared.imageDidCommit()
                    self?.setLoading(false, reportsLoadingState: reportsLoadingState)
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

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { super.touchesBegan(touches, with: event); reportTouchCount(event) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { super.touchesMoved(touches, with: event); reportTouchCount(event) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { super.touchesEnded(touches, with: event); reportTouchCount(event) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { super.touchesCancelled(touches, with: event); reportTouchCount(event) }
}

private struct EmbyPosterTouchGate: UIViewRepresentable {
    let ownerID: UUID
    let onTap: () -> Void

    final class Coordinator {
        let ownerID: UUID
        let onTap: () -> Void
        private var ownsTouch = false

        init(ownerID: UUID, onTap: @escaping () -> Void) { self.ownerID = ownerID; self.onTap = onTap }

        @objc func touchDown(_ sender: EmbyPosterTouchControl) {
            ownsTouch = EmbyPosterPressLock.shared.begin(ownerID)
            if !ownsTouch { EmbyPosterPressLock.shared.contaminate() }
        }

        @objc func touchUpInside(_ sender: EmbyPosterTouchControl) {
            let shouldTrigger = ownsTouch && EmbyPosterPressLock.shared.end(ownerID, trigger: true)
            ownsTouch = false
            if shouldTrigger { onTap() }
        }

        @objc func touchCancelled(_ sender: EmbyPosterTouchControl) {
            if ownsTouch { EmbyPosterPressLock.shared.end(ownerID, trigger: false) }
            ownsTouch = false
        }

        func activeTouchCountChanged(_ count: Int) {
            if count > 1 { EmbyPosterPressLock.shared.contaminate() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(ownerID: ownerID, onTap: onTap) }

    func makeUIView(context: Context) -> EmbyPosterTouchControl {
        let control = EmbyPosterTouchControl(frame: .zero)
        control.backgroundColor = .clear
        control.isMultipleTouchEnabled = true
        control.addTarget(context.coordinator, action: #selector(Coordinator.touchDown(_:)), for: .touchDown)
        control.addTarget(context.coordinator, action: #selector(Coordinator.touchUpInside(_:)), for: .touchUpInside)
        control.addTarget(context.coordinator, action: #selector(Coordinator.touchCancelled(_:)), for: [.touchCancel, .touchDragExit, .touchUpOutside])
        control.onActiveTouchCountChanged = { [weak coordinator = context.coordinator] count in coordinator?.activeTouchCountChanged(count) }
        return control
    }

    func updateUIView(_ uiView: EmbyPosterTouchControl, context: Context) {}
}

struct EmbyPosterDetailDestination: View {
    let item: LibraryItem
    let client: EmbyAPIClient

    var body: some View { EmbyMediaDetailView(item: item, client: client) }
}

struct EmbyPosterDetailLink<Label: View>: View {
    @Environment(\.embyPosterGridNavigationState) private var gridNavigationState
    let item: LibraryItem
    let client: EmbyAPIClient
    private let label: () -> Label
    @State private var isPresented = false
    @State private var touchOwnerID = UUID()
    @State private var navigationOwnerID = UUID().uuidString

    init(item: LibraryItem, client: EmbyAPIClient, @ViewBuilder label: @escaping () -> Label) {
        self.item = item
        self.client = client
        self.label = label
    }

    private var posterLabel: some View { label().contentShape(Rectangle()) }

    var body: some View {
        ZStack {
            posterLabel
            EmbyPosterTouchGate(ownerID: touchOwnerID) { open() }
        }
        .background(
            NavigationLink(destination: EmbyPosterDetailDestination(item: item, client: client), isActive: $isPresented) { EmptyView() }
                .hidden()
        )
        .onAppear { EmbyPosterScrollHitchDiagnostics.shared.posterDidAppear(itemID: item.id, route: gridNavigationState == nil ? "row" : "grid") }
        .onDisappear { EmbyPosterScrollHitchDiagnostics.shared.posterDidDisappear() }
        .onChange(of: isPresented) { presented in
            if !presented {
                gridNavigationState?.didReturnToGrid(itemID: item.id)
                EmbyPosterNavigationGate.shared.release(navigationOwnerID)
            }
        }
        .onChange(of: gridNavigationState?.selectedItemID) { selectedID in
            guard !isPresented, selectedID == item.id else { return }
            activateNavigation()
        }
    }

    private func open() {
        if let gridNavigationState {
            gridNavigationState.requestNavigation(itemID: item.id) { activateNavigation() }
        } else {
            activateNavigation()
        }
    }

    private func activateNavigation() {
        guard !isPresented else { return }
        guard EmbyPosterNavigationGate.shared.acquire(navigationOwnerID) else { return }
        isPresented = true
    }
}
