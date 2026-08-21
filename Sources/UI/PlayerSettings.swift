import Foundation

enum PlayerPreferenceKeys {
    static let enginePreference = "player.enginePreference"
    static let backwardSeconds = "seek.backwardSeconds"
    static let forwardSeconds = "seek.forwardSeconds"
    static let bufferPreset = "buffer.preset"
    static let orientationPolicy = "player.orientationPolicy"
    static let temporaryPlaybackRate = "player.temporaryPlaybackRate"
    static let volumeHapticsEnabled = "player.volumeHapticsEnabled"
    static let independentBrightnessEnabled = "player.independentBrightnessEnabled"
    static let independentBrightnessValue = "player.independentBrightnessValue"
    static let pauseWhenBackgrounded = "player.pauseWhenBackgrounded"
    static let resumeWhenForegrounded = "player.resumeWhenForegrounded"
    static let defaultScaleMode = "player.defaultScaleMode"
    static let controlsAutoHideSeconds = "player.controlsAutoHideSeconds"
    static let mdkAVIORequestSize2MiBEnabled = "player.mdkAVIORequestSize2MiBEnabled"
}

enum PlaybackOrientationPolicy: String, CaseIterable, Identifiable {
    case adaptive
    case landscape
    case portrait

    var id: String { rawValue }
    var title: String {
        switch self {
        case .adaptive: return "自适应"
        case .landscape: return "横屏"
        case .portrait: return "竖屏"
        }
    }
}

enum PlayerVideoScaleMode: String, CaseIterable, Identifiable {
    case fit
    case fill
    case source
    case ratio16x9
    case ratio4x3

    var id: String { rawValue }
    var title: String {
        switch self {
        case .fit: return "适应"
        case .fill: return "填充"
        case .source: return "原始比例"
        case .ratio16x9: return "16:9"
        case .ratio4x3: return "4:3"
        }
    }
}

enum BufferPreset: String, CaseIterable, Identifiable {
    case automatic
    case saving
    case balanced
    case aggressive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "自动"
        case .saving: return "节省"
        case .balanced: return "均衡"
        case .aggressive: return "激进"
        }
    }

    var seconds: Double {
        switch self {
        case .automatic: return 0
        case .saving: return 30
        case .balanced: return 90
        case .aggressive: return 180
        }
    }
}
