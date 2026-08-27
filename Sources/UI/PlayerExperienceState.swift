import Combine
import Foundation
import UIKit

final class PlaybackSessionOverrides: ObservableObject {
    @Published var scaleMode: PlayerVideoScaleMode
    @Published var basePlaybackRate: Double = 1.0
    @Published var temporaryPlaybackRate: Double?
    @Published var manualOrientation: UIInterfaceOrientation?

    init(defaultScaleMode: PlayerVideoScaleMode) {
        scaleMode = defaultScaleMode
    }

    var effectivePlaybackRate: Double { temporaryPlaybackRate ?? basePlaybackRate }
}

struct PlayerCapabilities {
    let supportsSystemRoutePicker: Bool
    let supportsPictureInPicture: Bool
    let supportsRotation: Bool
    let supportsPictureSize: Bool
    let supportsAudioTrackSelection: Bool
    let supportsSubtitleSelection: Bool

    static func resolve(for kind: PlayerEngineKind) -> PlayerCapabilities {
        switch kind {
        case .resourceLoaderAVPlayer, .transportAVPlayer, .avPlayer, .ktvAVPlayer:
            return PlayerCapabilities(
                supportsSystemRoutePicker: true,
                supportsPictureInPicture: true,
                supportsRotation: true,
                supportsPictureSize: true,
                supportsAudioTrackSelection: true,
                supportsSubtitleSelection: true
            )
        case .mpv:
            return PlayerCapabilities(
                supportsSystemRoutePicker: true,
                supportsPictureInPicture: true,
                supportsRotation: true,
                supportsPictureSize: true,
                supportsAudioTrackSelection: false,
                supportsSubtitleSelection: false
            )
        case .aether:
            return PlayerCapabilities(
                supportsSystemRoutePicker: false,
                supportsPictureInPicture: false,
                supportsRotation: true,
                supportsPictureSize: true,
                supportsAudioTrackSelection: false,
                supportsSubtitleSelection: false
            )
        case .ksAVIO:
            return PlayerCapabilities(
                supportsSystemRoutePicker: true,
                supportsPictureInPicture: true,
                supportsRotation: true,
                supportsPictureSize: false,
                supportsAudioTrackSelection: false,
                supportsSubtitleSelection: false
            )
        }
    }
}
