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
        DiagnosticsLogger.shared.log("Search", "recommendation initial random-items server=\(stored.serverName) requested=\(V3SearchRecommendationPolicy.itemTypes.joined(separator: ",")) returned=\(items.count) types=\(types)")
        return accepted
    }

    func moreRecommendations(client: EmbyAPIClient, excluding itemIDs: [String]) async throws -> [LibraryItem] {
        let requestedTypes = V3SearchRecommendationPolicy.itemTypes
        let items = try await client.searchLandingRecommendations(limit: V3SearchRecommendationPolicy.loadMoreLimit, includeItemTypes: requestedTypes, excludeItemIds: itemIDs)
        DiagnosticsLogger.shared.log("Search", "recommendation load-more random-items excluded=\(itemIDs.count) returned=\(items.count)")
        return Array(items.prefix(V3SearchRecommendationPolicy.loadMoreLimit))
    }
}
