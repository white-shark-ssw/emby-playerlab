import Foundation
import UIKit

enum V3SearchRecommendationPolicy {
    static let itemTypes = ["Movie", "Series"]
    static let preloadLimit = 9

    static var posterImageMaxWidth: Int {
        let available = UIScreen.main.bounds.width - EmbyPosterGridMetrics.horizontalPadding * 2 - EmbyPosterGridMetrics.columnSpacing * CGFloat(EmbyPosterGridMetrics.columnCount - 1)
        let gridWidth = floor(max(1, available) / CGFloat(EmbyPosterGridMetrics.columnCount))
        return min(440, max(1, Int(ceil(gridWidth * UIScreen.main.scale))))
    }
}

@MainActor
final class V3SearchRecommendationPreloader {
    static let shared = V3SearchRecommendationPreloader()

    private struct LoadedRecommendations {
        let items: [LibraryItem]
        let client: EmbyAPIClient
    }

    private var itemsBySessionID: [String: [LibraryItem]] = [:]
    private var tasksBySessionID: [String: Task<LoadedRecommendations, Error>] = [:]
    private var didStartAppWarm = false

    private init() {}

    func start(sessions: [EmbySession], sessionStore: SessionStore) {
        guard !didStartAppWarm else { return }
        didStartAppWarm = true
        for stored in sessions { beginStartupWarm(for: stored, sessionStore: sessionStore) }
    }

    func recommendations(for stored: EmbySession, client: EmbyAPIClient) async throws -> [LibraryItem] {
        if let items = itemsBySessionID[stored.id] { return items }
        if let task = tasksBySessionID[stored.id] {
            let loaded = try await task.value
            accept(loaded, sessionID: stored.id)
            return loaded.items
        }

        let task = Task { try await Self.fetchRecommendations(client: client) }
        tasksBySessionID[stored.id] = task
        do {
            let loaded = try await task.value
            accept(loaded, sessionID: stored.id)
            return loaded.items
        } catch {
            tasksBySessionID[stored.id] = nil
            throw error
        }
    }

    private func beginStartupWarm(for stored: EmbySession, sessionStore: SessionStore) {
        guard itemsBySessionID[stored.id] == nil, tasksBySessionID[stored.id] == nil else { return }
        let task = Task {
            let client = try await sessionStore.clientForBestRoute(for: stored)
            return try await Self.fetchRecommendations(client: client)
        }
        tasksBySessionID[stored.id] = task
        Task {
            do {
                let loaded = try await task.value
                accept(loaded, sessionID: stored.id)
            } catch {
                tasksBySessionID[stored.id] = nil
                if !isEmbyRequestCancellation(error) { DiagnosticsLogger.shared.log("Search", "startup recommendation warm failed server=\(stored.serverName): \(error.localizedDescription)") }
            }
        }
    }

    private func accept(_ loaded: LoadedRecommendations, sessionID: String) {
        itemsBySessionID[sessionID] = loaded.items
        tasksBySessionID[sessionID] = nil
        let urls = loaded.items.compactMap { item in
            loaded.client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: V3SearchRecommendationPolicy.posterImageMaxWidth, tag: item.preferredPrimaryImageTag)
        }
        warmPosterImages(urls)
    }

    private static func fetchRecommendations(client: EmbyAPIClient) async throws -> LoadedRecommendations {
        let requestedTypes = V3SearchRecommendationPolicy.itemTypes
        let items = try await client.searchLandingRecommendations(limit: V3SearchRecommendationPolicy.preloadLimit, includeItemTypes: requestedTypes)
        let types = Dictionary(grouping: items, by: { $0.type ?? "nil" }).mapValues(\.count).sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
        DiagnosticsLogger.shared.log("Search", "recommendation warm random-items requested=\(requestedTypes.joined(separator: ",")) returned=\(items.count) types=\(types)")
        return LoadedRecommendations(items: Array(items.prefix(V3SearchRecommendationPolicy.preloadLimit)), client: client)
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
