import Foundation
import UIKit

enum V3SearchRecommendationPolicy {
    static let itemTypes = ["Movie", "Series"]
    static let preloadLimit = 9

    static func allows(_ item: LibraryItem, requestedTypes: [String]) -> Bool {
        if let type = item.type { return itemTypes.contains { type.caseInsensitiveCompare($0) == .orderedSame } }
        return !requestedTypes.isEmpty && requestedTypes.allSatisfy { requested in itemTypes.contains { $0.caseInsensitiveCompare(requested) == .orderedSame } }
    }

    static func includeItemTypes(for library: LibraryItem) -> [String]? {
        switch library.collectionType?.lowercased() {
        case "movies": return ["Movie"]
        case "tvshows": return ["Series"]
        case "mixed": return itemTypes
        default: return nil
        }
    }

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
        let libraries = try await client.userViews()
        let eligibleLibraries = libraries.compactMap { library -> (LibraryItem, [String])? in
            guard let includeTypes = V3SearchRecommendationPolicy.includeItemTypes(for: library) else { return nil }
            return (library, includeTypes)
        }
        DiagnosticsLogger.shared.log("Search", "recommendation warm libraries total=\(libraries.count) eligible=\(eligibleLibraries.count)")

        var seen = Set<String>()
        var result: [LibraryItem] = []
        for (library, includeTypes) in eligibleLibraries {
            let remaining = V3SearchRecommendationPolicy.preloadLimit - result.count
            guard remaining > 0 else { break }
            let suggestions = try await client.librarySuggestions(parentId: library.id, limit: remaining, includeItemTypes: includeTypes)
            let accepted = suggestions.filter { V3SearchRecommendationPolicy.allows($0, requestedTypes: includeTypes) }
            let nilTypeCount = suggestions.filter { $0.type == nil }.count
            DiagnosticsLogger.shared.log("Search", "recommendation warm library=\(library.name) collection=\(library.collectionType ?? "nil") requested=\(includeTypes.joined(separator: ",")) returned=\(suggestions.count) nilType=\(nilTypeCount) accepted=\(accepted.count)")
            for item in accepted where seen.insert(item.id).inserted {
                result.append(item)
                if result.count == V3SearchRecommendationPolicy.preloadLimit { break }
            }
        }
        DiagnosticsLogger.shared.log("Search", "recommendation warm completed items=\(result.count)")
        return LoadedRecommendations(items: result, client: client)
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
