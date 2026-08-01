import Combine
import Foundation

@MainActor
final class PlaybackLabViewModel: ObservableObject {
    @Published var itemId = ""
    @Published private(set) var playbackInfo: PlaybackInfoResponse?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedSource: ResolvedPlaybackSource?

    func load(client: EmbyAPIClient) async {
        let itemId = itemId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !itemId.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        selectedSource = nil
        defer { isLoading = false }

        do {
            let info = try await client.playbackInfo(itemId: itemId)
            playbackInfo = info
            DiagnosticsLogger.shared.log("PlaybackInfo", "item=\(itemId) sources=\(info.mediaSources.count)")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resolve(client: EmbyAPIClient, mediaSource: MediaSource) {
        do {
            selectedSource = try client.resolvePlaybackSource(
                itemId: itemId.trimmingCharacters(in: .whitespacesAndNewlines),
                mediaSource: mediaSource,
                playSessionId: playbackInfo?.playSessionId
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
