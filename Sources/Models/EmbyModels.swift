import Foundation

struct PublicSystemInfo: Decodable {
    let serverName: String?
    let version: String?
    let id: String?

    enum CodingKeys: String, CodingKey {
        case serverName = "ServerName"
        case version = "Version"
        case id = "Id"
    }
}

struct EmbyUser: Codable, Equatable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
    }
}

struct AuthenticationResult: Decodable {
    let user: EmbyUser
    let accessToken: String
    let serverId: String?

    enum CodingKeys: String, CodingKey {
        case user = "User"
        case accessToken = "AccessToken"
        case serverId = "ServerId"
    }
}

struct EmbySession: Codable, Equatable, Identifiable {
    let serverURL: URL
    let serverId: String
    let serverName: String
    let serverVersion: String
    let user: EmbyUser
    let tokenAccount: String

    var id: String { tokenAccount }
}

struct BaseItem: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: String?
    let runTimeTicks: Int64?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case runTimeTicks = "RunTimeTicks"
    }
}

struct EmbyItemPage: Decodable {
    let items: [LibraryItem]
    let totalRecordCount: Int?

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
    }
}

struct LibraryItem: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: String?
    let overview: String?
    let productionYear: Int?
    let runTimeTicks: Int64?
    let communityRating: Double?
    let seriesName: String?
    let seriesId: String?
    let indexNumber: Int?
    let parentIndexNumber: Int?
    let childCount: Int?
    let collectionType: String?
    let primaryImageTag: String?
    let backdropImageTags: [String]
    let userData: EmbyUserItemData?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case overview = "Overview"
        case productionYear = "ProductionYear"
        case runTimeTicks = "RunTimeTicks"
        case communityRating = "CommunityRating"
        case seriesName = "SeriesName"
        case seriesId = "SeriesId"
        case indexNumber = "IndexNumber"
        case parentIndexNumber = "ParentIndexNumber"
        case childCount = "ChildCount"
        case collectionType = "CollectionType"
        case imageTags = "ImageTags"
        case backdropImageTags = "BackdropImageTags"
        case userData = "UserData"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = (try? container.decode(String.self, forKey: .name)) ?? "未命名"
        type = try? container.decode(String.self, forKey: .type)
        overview = try? container.decode(String.self, forKey: .overview)
        productionYear = try? container.decode(Int.self, forKey: .productionYear)
        runTimeTicks = try? container.decode(Int64.self, forKey: .runTimeTicks)
        communityRating = try? container.decode(Double.self, forKey: .communityRating)
        seriesName = try? container.decode(String.self, forKey: .seriesName)
        seriesId = try? container.decode(String.self, forKey: .seriesId)
        indexNumber = try? container.decode(Int.self, forKey: .indexNumber)
        parentIndexNumber = try? container.decode(Int.self, forKey: .parentIndexNumber)
        childCount = try? container.decode(Int.self, forKey: .childCount)
        collectionType = try? container.decode(String.self, forKey: .collectionType)
        let imageTags = (try? container.decode([String: String].self, forKey: .imageTags)) ?? [:]
        primaryImageTag = imageTags["Primary"]
        backdropImageTags = (try? container.decode([String].self, forKey: .backdropImageTags)) ?? []
        userData = try? container.decode(EmbyUserItemData.self, forKey: .userData)
    }

    var durationSeconds: Double? {
        guard let runTimeTicks, runTimeTicks > 0 else { return nil }
        return Double(runTimeTicks) / AppIdentity.ticksPerSecond
    }

    var playbackProgress: Double {
        guard let runTimeTicks, runTimeTicks > 0, let position = userData?.playbackPositionTicks, position > 0 else { return 0 }
        return min(1, max(0, Double(position) / Double(runTimeTicks)))
    }

    var isFavorite: Bool { userData?.isFavorite == true }
    var isPlayed: Bool { userData?.played == true }
}

struct EmbyUserItemData: Decodable, Hashable {
    let playbackPositionTicks: Int64?
    let playCount: Int?
    let isFavorite: Bool?
    let played: Bool?
    let unplayedItemCount: Int?

    enum CodingKeys: String, CodingKey {
        case playbackPositionTicks = "PlaybackPositionTicks"
        case playCount = "PlayCount"
        case isFavorite = "IsFavorite"
        case played = "Played"
        case unplayedItemCount = "UnplayedItemCount"
    }
}

struct PlaybackInfoResponse: Decodable {
    let mediaSources: [MediaSource]
    let playSessionId: String?

    enum CodingKeys: String, CodingKey {
        case mediaSources = "MediaSources"
        case playSessionId = "PlaySessionId"
    }
}

struct MediaSource: Decodable, Identifiable, Hashable {
    let id: String
    let name: String?
    let path: String?
    let container: String?
    let directStreamURL: String?
    let supportsDirectPlay: Bool?
    let supportsDirectStream: Bool?
    let runTimeTicks: Int64?
    let size: Int64?
    let requiredHTTPHeaders: [String: String]?
    let mediaStreams: [MediaStream]?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case path = "Path"
        case container = "Container"
        case directStreamURL = "DirectStreamUrl"
        case supportsDirectPlay = "SupportsDirectPlay"
        case supportsDirectStream = "SupportsDirectStream"
        case runTimeTicks = "RunTimeTicks"
        case size = "Size"
        case requiredHTTPHeaders = "RequiredHttpHeaders"
        case mediaStreams = "MediaStreams"
    }

    var durationSeconds: Double? {
        guard let runTimeTicks, runTimeTicks > 0 else { return nil }
        return Double(runTimeTicks) / AppIdentity.ticksPerSecond
    }

    var normalizedContainer: String {
        container?.lowercased() ?? ""
    }

    var videoCodec: String? {
        mediaStreams?.first(where: { $0.type?.caseInsensitiveCompare("Video") == .orderedSame })?.codec
    }

    var audioCodec: String? {
        mediaStreams?.first(where: { $0.type?.caseInsensitiveCompare("Audio") == .orderedSame })?.codec
    }
}

struct MediaStream: Decodable, Hashable {
    let index: Int?
    let type: String?
    let codec: String?
    let language: String?
    let displayTitle: String?
    let isExternal: Bool?

    enum CodingKeys: String, CodingKey {
        case index = "Index"
        case type = "Type"
        case codec = "Codec"
        case language = "Language"
        case displayTitle = "DisplayTitle"
        case isExternal = "IsExternal"
    }
}

struct ResolvedPlaybackSource: Identifiable, Hashable {
    let id = UUID()
    let itemId: String
    let itemName: String
    let mediaSource: MediaSource
    let playSessionId: String?
    let url: URL
    let headers: [String: String]
}
