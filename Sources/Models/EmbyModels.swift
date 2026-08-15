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

struct EmbyNamedItem: Decodable, Identifiable, Hashable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
    }
}

struct EmbyPerson: Decodable, Identifiable, Hashable {
    let itemId: String?
    let name: String
    let role: String?
    let type: String?
    let primaryImageTag: String?

    var id: String { itemId ?? "\(name)|\(role ?? "")|\(type ?? "")" }

    enum CodingKeys: String, CodingKey {
        case itemId = "Id"
        case name = "Name"
        case role = "Role"
        case type = "Type"
        case primaryImageTag = "PrimaryImageTag"
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
    let officialRating: String?
    let premiereDate: String?
    let dateCreated: String?
    let seriesName: String?
    let seriesId: String?
    let seasonId: String?
    let parentId: String?
    let indexNumber: Int?
    let parentIndexNumber: Int?
    let childCount: Int?
    let collectionType: String?
    let primaryImageTag: String?
    let primaryImageItemId: String?
    let seriesPrimaryImageTag: String?
    let backdropImageTags: [String]
    let genres: [String]
    let tags: [String]
    let studios: [EmbyNamedItem]
    let people: [EmbyPerson]
    let userData: EmbyUserItemData?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case overview = "Overview"
        case productionYear = "ProductionYear"
        case runTimeTicks = "RunTimeTicks"
        case communityRating = "CommunityRating"
        case officialRating = "OfficialRating"
        case premiereDate = "PremiereDate"
        case dateCreated = "DateCreated"
        case seriesName = "SeriesName"
        case seriesId = "SeriesId"
        case seasonId = "SeasonId"
        case parentId = "ParentId"
        case indexNumber = "IndexNumber"
        case parentIndexNumber = "ParentIndexNumber"
        case childCount = "ChildCount"
        case collectionType = "CollectionType"
        case imageTags = "ImageTags"
        case primaryImageItemId = "PrimaryImageItemId"
        case seriesPrimaryImageTag = "SeriesPrimaryImageTag"
        case backdropImageTags = "BackdropImageTags"
        case genres = "Genres"
        case tags = "Tags"
        case studios = "Studios"
        case people = "People"
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
        officialRating = try? container.decode(String.self, forKey: .officialRating)
        premiereDate = try? container.decode(String.self, forKey: .premiereDate)
        dateCreated = try? container.decode(String.self, forKey: .dateCreated)
        seriesName = try? container.decode(String.self, forKey: .seriesName)
        seriesId = try? container.decode(String.self, forKey: .seriesId)
        seasonId = try? container.decode(String.self, forKey: .seasonId)
        parentId = try? container.decode(String.self, forKey: .parentId)
        indexNumber = try? container.decode(Int.self, forKey: .indexNumber)
        parentIndexNumber = try? container.decode(Int.self, forKey: .parentIndexNumber)
        childCount = try? container.decode(Int.self, forKey: .childCount)
        collectionType = try? container.decode(String.self, forKey: .collectionType)
        let imageTags = (try? container.decode([String: String].self, forKey: .imageTags)) ?? [:]
        primaryImageTag = imageTags["Primary"]
        primaryImageItemId = try? container.decode(String.self, forKey: .primaryImageItemId)
        seriesPrimaryImageTag = try? container.decode(String.self, forKey: .seriesPrimaryImageTag)
        backdropImageTags = (try? container.decode([String].self, forKey: .backdropImageTags)) ?? []
        genres = (try? container.decode([String].self, forKey: .genres)) ?? []
        tags = (try? container.decode([String].self, forKey: .tags)) ?? []
        studios = (try? container.decode([EmbyNamedItem].self, forKey: .studios)) ?? []
        people = (try? container.decode([EmbyPerson].self, forKey: .people)) ?? []
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

    var preferredPrimaryImageItemId: String {
        if primaryImageTag != nil { return id }
        if let primaryImageItemId, !primaryImageItemId.isEmpty { return primaryImageItemId }
        if let seriesId, !seriesId.isEmpty, seriesPrimaryImageTag != nil { return seriesId }
        return id
    }

    var preferredPrimaryImageTag: String? { primaryImageTag ?? seriesPrimaryImageTag }
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

    var normalizedContainer: String { container?.lowercased() ?? "" }
    var videoCodec: String? { mediaStreams?.first(where: { $0.type?.caseInsensitiveCompare("Video") == .orderedSame })?.codec }
    var audioCodec: String? { mediaStreams?.first(where: { $0.type?.caseInsensitiveCompare("Audio") == .orderedSame })?.codec }
}

struct MediaStream: Decodable, Hashable {
    let index: Int?
    let type: String?
    let codec: String?
    let language: String?
    let displayTitle: String?
    let title: String?
    let profile: String?
    let level: Double?
    let width: Int?
    let height: Int?
    let aspectRatio: String?
    let rotation: Int?
    let isInterlaced: Bool?
    let realFrameRate: Double?
    let averageFrameRate: Double?
    let bitRate: Int?
    let videoRange: String?
    let videoRangeType: String?
    let colorPrimaries: String?
    let colorSpace: String?
    let colorTransfer: String?
    let bitDepth: Int?
    let pixelFormat: String?
    let refFrames: Int?
    let channels: Int?
    let channelLayout: String?
    let sampleRate: Int?
    let isDefault: Bool?
    let isForced: Bool?
    let isExternal: Bool?

    enum CodingKeys: String, CodingKey {
        case index = "Index"
        case type = "Type"
        case codec = "Codec"
        case language = "Language"
        case displayTitle = "DisplayTitle"
        case title = "Title"
        case profile = "Profile"
        case level = "Level"
        case width = "Width"
        case height = "Height"
        case aspectRatio = "AspectRatio"
        case rotation = "Rotation"
        case isInterlaced = "IsInterlaced"
        case realFrameRate = "RealFrameRate"
        case averageFrameRate = "AverageFrameRate"
        case bitRate = "BitRate"
        case videoRange = "VideoRange"
        case videoRangeType = "VideoRangeType"
        case colorPrimaries = "ColorPrimaries"
        case colorSpace = "ColorSpace"
        case colorTransfer = "ColorTransfer"
        case bitDepth = "BitDepth"
        case pixelFormat = "PixelFormat"
        case refFrames = "RefFrames"
        case channels = "Channels"
        case channelLayout = "ChannelLayout"
        case sampleRate = "SampleRate"
        case isDefault = "IsDefault"
        case isForced = "IsForced"
        case isExternal = "IsExternal"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        index = try? container.decode(Int.self, forKey: .index)
        type = try? container.decode(String.self, forKey: .type)
        codec = try? container.decode(String.self, forKey: .codec)
        language = try? container.decode(String.self, forKey: .language)
        displayTitle = try? container.decode(String.self, forKey: .displayTitle)
        title = try? container.decode(String.self, forKey: .title)
        profile = try? container.decode(String.self, forKey: .profile)
        level = try? container.decode(Double.self, forKey: .level)
        width = try? container.decode(Int.self, forKey: .width)
        height = try? container.decode(Int.self, forKey: .height)
        aspectRatio = try? container.decode(String.self, forKey: .aspectRatio)
        if let value = try? container.decode(Int.self, forKey: .rotation) { rotation = value }
        else if let value = try? container.decode(String.self, forKey: .rotation) { rotation = Int(value) }
        else { rotation = nil }
        isInterlaced = try? container.decode(Bool.self, forKey: .isInterlaced)
        realFrameRate = try? container.decode(Double.self, forKey: .realFrameRate)
        averageFrameRate = try? container.decode(Double.self, forKey: .averageFrameRate)
        bitRate = try? container.decode(Int.self, forKey: .bitRate)
        videoRange = try? container.decode(String.self, forKey: .videoRange)
        videoRangeType = try? container.decode(String.self, forKey: .videoRangeType)
        colorPrimaries = try? container.decode(String.self, forKey: .colorPrimaries)
        colorSpace = try? container.decode(String.self, forKey: .colorSpace)
        colorTransfer = try? container.decode(String.self, forKey: .colorTransfer)
        bitDepth = try? container.decode(Int.self, forKey: .bitDepth)
        pixelFormat = try? container.decode(String.self, forKey: .pixelFormat)
        refFrames = try? container.decode(Int.self, forKey: .refFrames)
        channels = try? container.decode(Int.self, forKey: .channels)
        channelLayout = try? container.decode(String.self, forKey: .channelLayout)
        sampleRate = try? container.decode(Int.self, forKey: .sampleRate)
        isDefault = try? container.decode(Bool.self, forKey: .isDefault)
        isForced = try? container.decode(Bool.self, forKey: .isForced)
        isExternal = try? container.decode(Bool.self, forKey: .isExternal)
    }

    var displayAspectRatio: Double? {
        var ratio: Double?
        if let aspectRatio {
            let parts = aspectRatio.split(separator: ":")
            if parts.count == 2, let width = Double(parts[0]), let height = Double(parts[1]), width > 0, height > 0 { ratio = width / height }
        }
        if ratio == nil, let width, let height, width > 0, height > 0 { ratio = Double(width) / Double(height) }
        guard let ratio else { return nil }
        let normalizedRotation = abs(rotation ?? 0) % 180
        return normalizedRotation == 90 ? 1 / ratio : ratio
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
