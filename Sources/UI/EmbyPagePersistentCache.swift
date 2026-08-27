import Foundation

struct V3PersistedPageState {
    let nextStartIndex: Int
    let hasMore: Bool
}

struct V3LibraryPersistentSnapshot {
    let tabItems: [String: [LibraryItem]]
    let suggestionResumeItems: [LibraryItem]
    let suggestionLatestItems: [LibraryItem]
    let genericSuggestionItems: [LibraryItem]
    let recommendationSections: [EmbyLibraryRecommendationSection]
    let genres: [LibraryItem]
    let folderItems: [LibraryItem]
    let sortBy: String
    let loadedTabs: Set<String>
    let pageStates: [String: V3PersistedPageState]
}

struct V3FavoritesPersistentSnapshot {
    let movies: [LibraryItem]
    let series: [LibraryItem]
    let episodes: [LibraryItem]
    let people: [LibraryItem]
}

final class V3PagePersistentCache {
    static let shared = V3PagePersistentCache()

    private let fileManager = FileManager.default
    private let schemaVersion = 1

    private init() {}

    func librarySnapshot(client: EmbyAPIClient, libraryID: String) -> V3LibraryPersistentSnapshot? {
        guard let root = rootObject(scope: "library|\(libraryID)", client: client) else { return nil }
        do {
            let tabItemsObject = root["TabItems"] as? [String: Any] ?? [:]
            var tabItems: [String: [LibraryItem]] = [:]
            for (key, value) in tabItemsObject { tabItems[key] = try decodeLibraryItems(value) }

            let pageStatesObject = root["PageStates"] as? [String: Any] ?? [:]
            var pageStates: [String: V3PersistedPageState] = [:]
            for (key, value) in pageStatesObject {
                guard let state = value as? [String: Any] else { continue }
                pageStates[key] = V3PersistedPageState(nextStartIndex: (state["NextStartIndex"] as? NSNumber)?.intValue ?? 0, hasMore: state["HasMore"] as? Bool ?? false)
            }

            return V3LibraryPersistentSnapshot(
                tabItems: tabItems,
                suggestionResumeItems: try decodeLibraryItems(root["SuggestionResumeItems"]),
                suggestionLatestItems: try decodeLibraryItems(root["SuggestionLatestItems"]),
                genericSuggestionItems: try decodeLibraryItems(root["GenericSuggestionItems"]),
                recommendationSections: try decodeRecommendationSections(root["RecommendationSections"]),
                genres: try decodeLibraryItems(root["Genres"]),
                folderItems: try decodeLibraryItems(root["FolderItems"]),
                sortBy: root["SortBy"] as? String ?? "DateCreated",
                loadedTabs: Set(root["LoadedTabs"] as? [String] ?? []),
                pageStates: pageStates
            )
        } catch {
            DiagnosticsLogger.shared.log("PagePersistentCache", "library disk read failed: \(error.localizedDescription)")
            return nil
        }
    }

    func storeLibrarySnapshot(_ snapshot: V3LibraryPersistentSnapshot, client: EmbyAPIClient, libraryID: String) {
        var tabItemsObject: [String: Any] = [:]
        for (key, items) in snapshot.tabItems { tabItemsObject[key] = items.map(libraryItemJSONObject) }

        var pageStatesObject: [String: Any] = [:]
        for (key, state) in snapshot.pageStates { pageStatesObject[key] = ["NextStartIndex": state.nextStartIndex, "HasMore": state.hasMore] }

        let root: [String: Any] = [
            "SchemaVersion": schemaVersion,
            "TabItems": tabItemsObject,
            "SuggestionResumeItems": snapshot.suggestionResumeItems.map(libraryItemJSONObject),
            "SuggestionLatestItems": snapshot.suggestionLatestItems.map(libraryItemJSONObject),
            "GenericSuggestionItems": snapshot.genericSuggestionItems.map(libraryItemJSONObject),
            "RecommendationSections": snapshot.recommendationSections.map(recommendationSectionJSONObject),
            "Genres": snapshot.genres.map(libraryItemJSONObject),
            "FolderItems": snapshot.folderItems.map(libraryItemJSONObject),
            "SortBy": snapshot.sortBy,
            "LoadedTabs": Array(snapshot.loadedTabs).sorted(),
            "PageStates": pageStatesObject,
        ]
        store(root, scope: "library|\(libraryID)", client: client)
    }

    func favoritesSnapshot(client: EmbyAPIClient) -> V3FavoritesPersistentSnapshot? {
        guard let root = rootObject(scope: "favorites", client: client) else { return nil }
        do {
            return V3FavoritesPersistentSnapshot(
                movies: try decodeLibraryItems(root["Movies"]),
                series: try decodeLibraryItems(root["Series"]),
                episodes: try decodeLibraryItems(root["Episodes"]),
                people: try decodeLibraryItems(root["People"])
            )
        } catch {
            DiagnosticsLogger.shared.log("PagePersistentCache", "favorites disk read failed: \(error.localizedDescription)")
            return nil
        }
    }

    func storeFavoritesSnapshot(_ snapshot: V3FavoritesPersistentSnapshot, client: EmbyAPIClient) {
        let root: [String: Any] = [
            "SchemaVersion": schemaVersion,
            "Movies": snapshot.movies.map(libraryItemJSONObject),
            "Series": snapshot.series.map(libraryItemJSONObject),
            "Episodes": snapshot.episodes.map(libraryItemJSONObject),
            "People": snapshot.people.map(libraryItemJSONObject),
        ]
        store(root, scope: "favorites", client: client)
    }

    private func rootObject(scope: String, client: EmbyAPIClient) -> [String: Any]? {
        guard let url = cacheFileURL(scope: scope, client: client), let data = try? Data(contentsOf: url) else { return nil }
        do {
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], root["SchemaVersion"] as? Int == schemaVersion else { return nil }
            return root
        } catch {
            DiagnosticsLogger.shared.log("PagePersistentCache", "disk decode failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func store(_ root: [String: Any], scope: String, client: EmbyAPIClient) {
        guard let url = cacheFileURL(scope: scope, client: client) else { return }
        do {
            let data = try JSONSerialization.data(withJSONObject: root)
            try data.write(to: url, options: .atomic)
        } catch {
            DiagnosticsLogger.shared.log("PagePersistentCache", "disk write failed: \(error.localizedDescription)")
        }
    }

    private func cacheFileURL(scope: String, client: EmbyAPIClient) -> URL? {
        guard let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let directory = base.appendingPathComponent("OnePlayer", isDirectory: true).appendingPathComponent("PagePresentation", isDirectory: true)
        do { try fileManager.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch {
            DiagnosticsLogger.shared.log("PagePersistentCache", "cache directory failed: \(error.localizedDescription)")
            return nil
        }
        let key = "\(client.baseURL.absoluteString)|\(client.userId ?? "")|\(scope)"
        let encoded = Data(key.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return directory.appendingPathComponent("v\(schemaVersion)-\(encoded).json", isDirectory: false)
    }

    private func decodeLibraryItems(_ object: Any?) throws -> [LibraryItem] {
        guard let object else { return [] }
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode([LibraryItem].self, from: data)
    }

    private func decodeRecommendationSections(_ object: Any?) throws -> [EmbyLibraryRecommendationSection] {
        guard let values = object as? [[String: Any]] else { return [] }
        return try values.map { value in
            EmbyLibraryRecommendationSection(
                items: try decodeLibraryItems(value["Items"]),
                recommendationType: value["RecommendationType"] as? String,
                baselineItemName: value["BaselineItemName"] as? String,
                categoryId: (value["CategoryId"] as? NSNumber)?.int64Value
            )
        }
    }

    private func recommendationSectionJSONObject(_ section: EmbyLibraryRecommendationSection) -> [String: Any] {
        var object: [String: Any] = ["Items": section.items.map(libraryItemJSONObject)]
        if let value = section.recommendationType { object["RecommendationType"] = value }
        if let value = section.baselineItemName { object["BaselineItemName"] = value }
        if let value = section.categoryId { object["CategoryId"] = value }
        return object
    }

    private func libraryItemJSONObject(_ item: LibraryItem) -> [String: Any] {
        var object: [String: Any] = [
            "Id": item.id,
            "Name": item.name,
            "BackdropImageTags": item.backdropImageTags,
            "Genres": item.genres,
            "Tags": item.tags,
            "Studios": item.studios.map(namedItemJSONObject),
            "People": item.people.map(personJSONObject),
        ]
        if let value = item.type { object["Type"] = value }
        if let value = item.overview { object["Overview"] = value }
        if let value = item.productionYear { object["ProductionYear"] = value }
        if let value = item.runTimeTicks { object["RunTimeTicks"] = value }
        if let value = item.communityRating { object["CommunityRating"] = value }
        if let value = item.officialRating { object["OfficialRating"] = value }
        if let value = item.premiereDate { object["PremiereDate"] = value }
        if let value = item.dateCreated { object["DateCreated"] = value }
        if let value = item.seriesName { object["SeriesName"] = value }
        if let value = item.seriesId { object["SeriesId"] = value }
        if let value = item.seasonId { object["SeasonId"] = value }
        if let value = item.parentId { object["ParentId"] = value }
        if let value = item.indexNumber { object["IndexNumber"] = value }
        if let value = item.parentIndexNumber { object["ParentIndexNumber"] = value }
        if let value = item.childCount { object["ChildCount"] = value }
        if let value = item.collectionType { object["CollectionType"] = value }
        if let value = item.primaryImageTag { object["ImageTags"] = ["Primary": value] }
        if let value = item.primaryImageItemId { object["PrimaryImageItemId"] = value }
        if let value = item.seriesPrimaryImageTag { object["SeriesPrimaryImageTag"] = value }
        if let value = item.userData { object["UserData"] = userDataJSONObject(value) }
        return object
    }

    private func namedItemJSONObject(_ item: EmbyNamedItem) -> [String: Any] { ["Id": item.id, "Name": item.name] }

    private func personJSONObject(_ person: EmbyPerson) -> [String: Any] {
        var object: [String: Any] = ["Name": person.name]
        if let value = person.itemId { object["Id"] = value }
        if let value = person.role { object["Role"] = value }
        if let value = person.type { object["Type"] = value }
        if let value = person.primaryImageTag { object["PrimaryImageTag"] = value }
        return object
    }

    private func userDataJSONObject(_ userData: EmbyUserItemData) -> [String: Any] {
        var object: [String: Any] = [:]
        if let value = userData.playbackPositionTicks { object["PlaybackPositionTicks"] = value }
        if let value = userData.playCount { object["PlayCount"] = value }
        if let value = userData.isFavorite { object["IsFavorite"] = value }
        if let value = userData.played { object["Played"] = value }
        if let value = userData.unplayedItemCount { object["UnplayedItemCount"] = value }
        return object
    }
}
