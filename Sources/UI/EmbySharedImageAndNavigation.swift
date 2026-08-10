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
        content
            .contentShape(Rectangle())
            .onTapGesture { isActive = true }
            .background(
                NavigationLink(destination: EmbyMediaDetailView(item: item, client: client), isActive: $isActive) { EmptyView() }
                    .frame(width: 0, height: 0)
                    .hidden()
            )
    }
}
