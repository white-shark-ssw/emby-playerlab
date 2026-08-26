import SwiftUI
import UIKit
import Foundation
import Combine
import CoreImage
import ImageIO

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

private final class EmbyCachedImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    private var currentURL: URL?
    private var task: Task<Void, Never>?

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

struct EmbyCachedRemoteImage: View {
    let url: URL?
    let contentMode: ContentMode
    let placeholderSystemImage: String
    let showsLoadingIndicator: Bool
    let onImageLoaded: ((UIImage) -> Void)?
    @StateObject private var loader = EmbyCachedImageLoader()
    @State private var reportedImageIdentifier: ObjectIdentifier?

    init(url: URL?, contentMode: ContentMode, placeholderSystemImage: String = "photo", showsLoadingIndicator: Bool = true, onImageLoaded: ((UIImage) -> Void)? = nil) {
        self.url = url
        self.contentMode = contentMode
        self.placeholderSystemImage = placeholderSystemImage
        self.showsLoadingIndicator = showsLoadingIndicator
        self.onImageLoaded = onImageLoaded
    }

    var body: some View {
        ZStack {
            if let image = loader.image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else {
                Color(uiColor: .secondarySystemBackground)
                Image(systemName: placeholderSystemImage).font(.system(size: 24, weight: .medium)).foregroundColor(.secondary.opacity(0.62))
                if showsLoadingIndicator && loader.isLoading { ProgressView() }
            }
        }
        .onAppear { loader.load(url, reportsLoadingState: showsLoadingIndicator) }
        .onDisappear { loader.cancel(reportsLoadingState: showsLoadingIndicator) }
        .onChange(of: url) {
            if onImageLoaded != nil { reportedImageIdentifier = nil }
            loader.load($0, reportsLoadingState: showsLoadingIndicator)
        }
        .onReceive(loader.$image.compactMap { $0 }) { image in
            guard let onImageLoaded else { return }
            let identifier = ObjectIdentifier(image)
            guard reportedImageIdentifier != identifier else { return }
            reportedImageIdentifier = identifier
            onImageLoaded(image)
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
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
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
    }
}