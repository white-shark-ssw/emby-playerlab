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

struct EmbySession: Codable, Equatable {
    let serverURL: URL
    let serverId: String
    let serverName: String
    let serverVersion: String
    let user: EmbyUser
    let tokenAccount: String
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
    let mediaSource: MediaSource
    let playSessionId: String?
    let url: URL
    let headers: [String: String]
}
