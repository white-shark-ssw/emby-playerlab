import SwiftUI
import UIKit
import Foundation

private final class EmbyCachedImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    private var currentURL: URL?
    private var task: Task<Void, Never>?

    func load(_ url: URL?) {
        guard currentURL != url || image == nil else { return }
        currentURL = url
        task?.cancel()
        guard let url else {
            image = nil
            isLoading = false
            return
        }
        if let cached = EmbyImageMemoryCache.shared.object(forKey: url as NSURL) {
            image = cached
            isLoading = false
            return
        }
        image = nil
        isLoading = true
        task = Task { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, let loaded = UIImage(data: data) else { return }
                EmbyImageMemoryCache.shared.setObject(loaded, forKey: url as NSURL)
                await MainActor.run {
                    guard self?.currentURL == url else { return }
                    self?.image = loaded
                    self?.isLoading = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self?.currentURL == url else { return }
                    self?.isLoading = false
                }
            }
        }
    }
}

private final class EmbyImageMemoryCache {
    static let shared = EmbyImageMemoryCache()
    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 420
        cache.totalCostLimit = 180 * 1024 * 1024
    }

    func object(forKey key: NSURL) -> UIImage? { cache.object(forKey: key) }

    func setObject(_ image: UIImage, forKey key: NSURL) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: key, cost: cost)
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
    @StateObject private var loader = EmbyCachedImageLoader()

    init(url: URL?, contentMode: ContentMode, placeholderSystemImage: String = "photo") {
        self.url = url
        self.contentMode = contentMode
        self.placeholderSystemImage = placeholderSystemImage
    }

    var body: some View {
        ZStack {
            if let image = loader.image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else {
                Color(uiColor: .secondarySystemBackground)
                Image(systemName: placeholderSystemImage).font(.system(size: 24, weight: .medium)).foregroundColor(.secondary.opacity(0.62))
                if loader.isLoading { ProgressView() }
            }
        }
        .onAppear { loader.load(url) }
        .onChange(of: url) { loader.load($0) }
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
                content
                    .contentShape(Rectangle())
                    .overlay(EmbyExclusivePosterTapControl { gridNavigationState.open(item: item, client: client) })
            } else {
                content
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !isActive, EmbyPosterNavigationGate.shared.acquire(item.id) else { return }
                        isActive = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) { EmbyPosterNavigationGate.shared.release(item.id) }
                    }
                    .background(
                        NavigationLink(destination: EmbyMediaDetailView(item: item, client: client), isActive: $isActive) { EmptyView() }
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
