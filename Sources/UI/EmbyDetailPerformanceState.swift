import SwiftUI
import Combine
import Foundation

final class EmbyDetailHeroScrollState: ObservableObject {
    @Published private(set) var rawMinY: CGFloat = 0

    func update(_ value: CGFloat) {
        guard abs(rawMinY - value) > 0.10 else { return }
        rawMinY = value
    }
}

struct EmbyDetailHeroScrollScope<Content: View>: View {
    @ObservedObject var state: EmbyDetailHeroScrollState
    let content: (CGFloat) -> Content

    init(state: EmbyDetailHeroScrollState, @ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.state = state
        self.content = content
    }

    var body: some View { content(state.rawMinY) }
}

struct EmbyMediaDetailWarmSnapshot {
    let episodes: [LibraryItem]
    let seasons: [LibraryItem]
    let imageInfos: [EmbyImageInfo]
    let similarItems: [LibraryItem]
}

final class EmbyMediaDetailWarmCache {
    static let shared = EmbyMediaDetailWarmCache()

    private final class Box: NSObject {
        let snapshot: EmbyMediaDetailWarmSnapshot
        init(_ snapshot: EmbyMediaDetailWarmSnapshot) { self.snapshot = snapshot }
    }

    private let cache = NSCache<NSString, Box>()

    private init() { cache.countLimit = 12 }

    func snapshot(client: EmbyAPIClient, itemID: String) -> EmbyMediaDetailWarmSnapshot? {
        cache.object(forKey: key(client: client, itemID: itemID))?.snapshot
    }

    func store(_ snapshot: EmbyMediaDetailWarmSnapshot, client: EmbyAPIClient, itemID: String) {
        cache.setObject(Box(snapshot), forKey: key(client: client, itemID: itemID))
    }

    private func key(client: EmbyAPIClient, itemID: String) -> NSString {
        "\(client.baseURL.absoluteString)|\(client.userId ?? "")|\(itemID)" as NSString
    }
}
