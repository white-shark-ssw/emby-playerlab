import Combine
import Foundation

@MainActor
final class PlaybackLabViewModel: ObservableObject {
    @Published var itemId = ""
    @Published private(set) var item: BaseItem?
    @Published private(set) var playbackInfo: PlaybackInfoResponse?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedSource: ResolvedPlaybackSource?
    @Published var selectedAVIOSource: ResolvedPlaybackSource?

    func load(client: EmbyAPIClient) async {
        let itemId = itemId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !itemId.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        selectedSource = nil
        selectedAVIOSource = nil
        item = nil
        playbackInfo = nil
        defer { isLoading = false }

        do {
            async let itemRequest = client.item(itemId: itemId)
            async let playbackRequest = client.playbackInfo(itemId: itemId)
            let (loadedItem, info) = try await (itemRequest, playbackRequest)
            item = loadedItem
            playbackInfo = info
            DiagnosticsLogger.shared.log(
                "PlaybackInfo",
                "item=\(itemId) title=\(loadedItem.name) sources=\(info.mediaSources.count)"
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resolve(client: EmbyAPIClient, mediaSource: MediaSource) {
        do {
            selectedSource = try resolvedSource(client: client, mediaSource: mediaSource)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resolveAVIO(client: EmbyAPIClient, mediaSource: MediaSource) {
        do {
            selectedAVIOSource = try resolvedSource(client: client, mediaSource: mediaSource)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolvedSource(client: EmbyAPIClient, mediaSource: MediaSource) throws -> ResolvedPlaybackSource {
        let id = itemId.trimmingCharacters(in: .whitespacesAndNewlines)
        return try client.resolvePlaybackSource(
            itemId: id,
            itemName: item?.name ?? id,
            mediaSource: mediaSource,
            playSessionId: playbackInfo?.playSessionId
        )
    }
}
