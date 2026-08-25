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
    private let fileManager = FileManager.default
    private let schemaVersion = 1

    private init() {}

    func snapshot(client: EmbyAPIClient, itemID: String) -> EmbyMediaDetailWarmSnapshot? {
        let cacheKey = key(client: client, itemID: itemID)
        if let snapshot = cache.object(forKey: cacheKey as NSString)?.snapshot { return snapshot }
        guard let snapshot = diskSnapshot(forKey: cacheKey) else { return nil }
        cache.setObject(Box(snapshot), forKey: cacheKey as NSString)
        return snapshot
    }

    func store(_ snapshot: EmbyMediaDetailWarmSnapshot, client: EmbyAPIClient, itemID: String) {
        let cacheKey = key(client: client, itemID: itemID)
        cache.setObject(Box(snapshot), forKey: cacheKey as NSString)
        storeDiskSnapshot(snapshot, forKey: cacheKey)
    }

    private func key(client: EmbyAPIClient, itemID: String) -> String {
        "\(client.baseURL.absoluteString)|\(client.userId ?? "")|\(itemID)"
    }

    private func diskSnapshot(forKey key: String) -> EmbyMediaDetailWarmSnapshot? {
        guard let url = cacheFileURL(forKey: key), let data = try? Data(contentsOf: url) else { return nil }
        do {
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], root["SchemaVersion"] as? Int == schemaVersion else { return nil }
            let episodes = try decodeLibraryItems(root["Episodes"])
            let seasons = try decodeLibraryItems(root["Seasons"])
            let imageInfos = try decodeImageInfos(root["ImageInfos"])
            let similarItems = try decodeLibraryItems(root["SimilarItems"])
            return EmbyMediaDetailWarmSnapshot(episodes: episodes, seasons: seasons, imageInfos: imageInfos, similarItems: similarItems)
        } catch {
            DiagnosticsLogger.shared.log("EmbyDetailWarmCache", "disk read failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func storeDiskSnapshot(_ snapshot: EmbyMediaDetailWarmSnapshot, forKey key: String) {
        guard let url = cacheFileURL(forKey: key) else { return }
        let root: [String: Any] = [
            "SchemaVersion": schemaVersion,
            "Episodes": snapshot.episodes.map(libraryItemJSONObject),
            "Seasons": snapshot.seasons.map(libraryItemJSONObject),
            "ImageInfos": snapshot.imageInfos.map(imageInfoJSONObject),
            "SimilarItems": snapshot.similarItems.map(libraryItemJSONObject),
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: root)
            try data.write(to: url, options: .atomic)
        } catch {
            DiagnosticsLogger.shared.log("EmbyDetailWarmCache", "disk write failed: \(error.localizedDescription)")
        }
    }

    private func cacheFileURL(forKey key: String) -> URL? {
        guard let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let directory = base.appendingPathComponent("OnePlayer", isDirectory: true).appendingPathComponent("DetailPresentation", isDirectory: true)
        do { try fileManager.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch {
            DiagnosticsLogger.shared.log("EmbyDetailWarmCache", "cache directory failed: \(error.localizedDescription)")
            return nil
        }
        let encoded = Data(key.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return directory.appendingPathComponent("v\(schemaVersion)-\(encoded).json", isDirectory: false)
    }

    private func decodeLibraryItems(_ object: Any?) throws -> [LibraryItem] {
        guard let object else { return [] }
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode([LibraryItem].self, from: data)
    }

    private func decodeImageInfos(_ object: Any?) throws -> [EmbyImageInfo] {
        guard let object else { return [] }
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode([EmbyImageInfo].self, from: data)
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

    private func imageInfoJSONObject(_ image: EmbyImageInfo) -> [String: Any] {
        var object: [String: Any] = ["ImageType": image.imageType]
        if let value = image.imageIndex { object["ImageIndex"] = value }
        if let value = image.path { object["Path"] = value }
        if let value = image.filename { object["Filename"] = value }
        if let value = image.height { object["Height"] = value }
        if let value = image.width { object["Width"] = value }
        if let value = image.size { object["Size"] = value }
        return object
    }
}
