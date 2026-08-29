import Foundation
import UIKit

enum V3SearchRecommendationPolicy {
    static let itemTypes = ["Movie", "Series"]
    static let preloadLimit = 9
    static let loadMoreLimit = 6

    static var posterImageMaxWidth: Int {
        let available = UIScreen.main.bounds.width - EmbyPosterGridMetrics.horizontalPadding * 2 - EmbyPosterGridMetrics.columnSpacing * CGFloat(EmbyPosterGridMetrics.columnCount - 1)
        let gridWidth = floor(max(1, available) / CGFloat(EmbyPosterGridMetrics.columnCount))
        return min(440, max(1, Int(ceil(gridWidth * UIScreen.main.scale))))
    }
}

@MainActor
final class V3SearchRecommendationPreloader {
    static let shared = V3SearchRecommendationPreloader()

    private init() {}

    func recommendations(for stored: EmbySession, client: EmbyAPIClient) async throws -> [LibraryItem] {
        let items = try await client.searchLandingRecommendations(limit: V3SearchRecommendationPolicy.preloadLimit, includeItemTypes: V3SearchRecommendationPolicy.itemTypes)
        let types = Dictionary(grouping: items, by: { $0.type ?? "nil" }).mapValues(\.count).sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
        let accepted = Array(items.prefix(V3SearchRecommendationPolicy.preloadLimit))
        warmPosterImages(accepted.compactMap { item in client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: V3SearchRecommendationPolicy.posterImageMaxWidth, tag: item.preferredPrimaryImageTag) })
        DiagnosticsLogger.shared.log("Search", "recommendation initial random-items server=\(stored.serverName) requested=\(V3SearchRecommendationPolicy.itemTypes.joined(separator: ",")) returned=\(items.count) types=\(types)")
        return accepted
    }

    func moreRecommendations(client: EmbyAPIClient, excluding itemIDs: [String]) async throws -> [LibraryItem] {
        let requestedTypes = V3SearchRecommendationPolicy.itemTypes
        let items = try await client.searchLandingRecommendations(limit: V3SearchRecommendationPolicy.loadMoreLimit, includeItemTypes: requestedTypes, excludeItemIds: itemIDs)
        let urls = items.compactMap { item in client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: V3SearchRecommendationPolicy.posterImageMaxWidth, tag: item.preferredPrimaryImageTag) }
        warmPosterImages(urls)
        DiagnosticsLogger.shared.log("Search", "recommendation load-more random-items excluded=\(itemIDs.count) returned=\(items.count)")
        return Array(items.prefix(V3SearchRecommendationPolicy.loadMoreLimit))
    }

    private func warmPosterImages(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                for url in urls {
                    group.addTask {
                        var data = await EmbyImageDiskCache.shared.data(for: url)
                        if data == nil, let response = try? await URLSession.shared.data(from: url) {
                            data = response.0
                            await EmbyImageDiskCache.shared.store(response.0, for: url)
                        }
                        if let data, let image = UIImage(data: data) { EmbyDecodedImageRenderPool.shared.store(image, for: url) }
                    }
                }
                await group.waitForAll()
            }
        }
    }
}
