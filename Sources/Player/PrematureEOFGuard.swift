import Foundation

struct EOFDecision {
    let isPremature: Bool
    let reason: String
}

enum PrematureEOFGuard {
    static func evaluate(current: Double, avDuration: Double, embyDuration: Double?) -> EOFDecision {
        let trustedEmby = (embyDuration ?? 0) > 0 ? embyDuration : nil

        if let trustedEmby, current + 2.0 < trustedEmby {
            return EOFDecision(
                isPremature: true,
                reason: "当前 \(current.rounded())s，明显早于 Emby 时长 \(trustedEmby.rounded())s"
            )
        }

        if avDuration > 0, current + 1.5 < avDuration {
            return EOFDecision(
                isPremature: true,
                reason: "当前 \(current.rounded())s，明显早于 AVPlayer 时长 \(avDuration.rounded())s"
            )
        }

        if current < 1, (trustedEmby ?? avDuration) > 5 {
            return EOFDecision(
                isPremature: true,
                reason: "播放开始不足 1 秒即收到结束事件"
            )
        }

        return EOFDecision(isPremature: false, reason: "当前位置接近可信结尾")
    }
}
