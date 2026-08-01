import Foundation

enum EmbyAPIError: LocalizedError {
    case invalidServerURL
    case invalidResponse
    case http(Int, String)
    case noMediaSource
    case invalidPlaybackURL
    case missingSession

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "服务器地址无效。"
        case .invalidResponse:
            return "服务器响应格式无效。"
        case .http(let status, let message):
            return "HTTP \(status)：\(message)"
        case .noMediaSource:
            return "PlaybackInfo 没有返回可用媒体源。"
        case .invalidPlaybackURL:
            return "无法生成播放地址。"
        case .missingSession:
            return "Emby 登录会话不存在。"
        }
    }
}
