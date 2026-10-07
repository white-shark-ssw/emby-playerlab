import Foundation
import UIKit

final class DiagnosticsLogger {
    static let shared = DiagnosticsLogger()
    private let lock = NSLock()
    private var messages: [String] = []
    func log(_ category: String, _ message: String) { lock.lock(); messages.append(message); lock.unlock() }
    func playback(_ category: String, _ message: String) { log(category, message) }
    func records() -> [String] { lock.lock(); defer { lock.unlock() }; return messages }
}

// Only network/effect boundaries are fixtures; the whole original detail model and cache are compiled.
@MainActor
final class EmbyAPIClient {
    let baseURL: URL
    let userId: String?
    struct Request { let kind: String; let itemID: String; let continuation: CheckedContinuation<Data, Error> }
    var requests: [(String, String)] = []
    var pending: [Request] = []
    var paused = Set<String>()
    var responses: [String: Data] = [:]
    var similarTypes: [String] = []
    var resolvedSessions: [String?] = []
    init(baseURL: URL, userId: String = "test") { self.baseURL = baseURL; self.userId = userId }

    private func response(_ kind: String, itemID: String) async throws -> Data {
        try Task.checkCancellation()
        requests.append((kind, itemID))
        if !paused.contains(kind) { return responses[kind]! }
        return try await withCheckedThrowingContinuation { pending.append(Request(kind: kind, itemID: itemID, continuation: $0)) }
    }
    func finish(_ kind: String, error: Error? = nil) {
        let index = pending.firstIndex { $0.kind == kind }!
        let request = pending.remove(at: index)
        if let error { request.continuation.resume(throwing: error) }
        else { request.continuation.resume(returning: responses[kind]!) }
    }
    func finishAll() { while let kind = pending.first?.kind { finish(kind) } }
    func libraryItem(itemId: String) async throws -> LibraryItem { try JSONDecoder().decode(LibraryItem.self, from: await response("item", itemID: itemId)) }
    func seriesEpisodes(seriesId: String) async throws -> [LibraryItem] { try JSONDecoder().decode([LibraryItem].self, from: await response("episodes", itemID: seriesId)) }
    func seriesSeasons(seriesId: String) async throws -> [LibraryItem] { try JSONDecoder().decode([LibraryItem].self, from: await response("seasons", itemID: seriesId)) }
    func imageInfos(itemId: String) async throws -> [EmbyImageInfo] { try JSONDecoder().decode([EmbyImageInfo].self, from: await response("images", itemID: itemId)) }
    func similarItems(itemId: String, includeItemTypes: [String]) async throws -> [LibraryItem] { similarTypes = includeItemTypes; return try JSONDecoder().decode([LibraryItem].self, from: await response("similar", itemID: itemId)) }
    func playbackInfo(itemId: String) async throws -> PlaybackInfoResponse { try JSONDecoder().decode(PlaybackInfoResponse.self, from: await response("media", itemID: itemId)) }
    func setFavorite(itemId: String, favorite: Bool) async throws {}
    func setPlayed(itemId: String, played: Bool) async throws {}
    func resolvePlaybackSource(itemId: String, itemName: String, mediaSource: MediaSource, playSessionId: String?, initialPlaybackPositionTicks: Int64? = nil) throws -> ResolvedPlaybackSource {
        resolvedSessions.append(playSessionId)
        return ResolvedPlaybackSource(itemId: itemId, itemName: itemName, mediaSource: mediaSource, playSessionId: playSessionId, initialPlaybackPositionTicks: initialPlaybackPositionTicks, url: baseURL, headers: [:])
    }
}

enum DetailHaptics { static func selection() {} }
final class PlaybackClickResolveRegistry { static let shared = PlaybackClickResolveRegistry(); func arm(source: ResolvedPlaybackSource) {} }
