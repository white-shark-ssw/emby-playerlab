import Foundation

extension AVPlayerEngine: PlaybackPresentationEngineAdapter {
    func applyPresentationPlan(_ plan: PlaybackPresentationPlan, completion: @escaping (PlaybackPresentationAcknowledgement) -> Void) {
        setPlaybackRate(plan.requestedRate)
        completion(PlaybackPresentationAcknowledgement(activeMotionFPS: nil, activeEnhancementFeatures: [], detail: "avplayer-rate-only"))
    }
}

extension KTVAVPlayerEngine: PlaybackPresentationEngineAdapter {
    func applyPresentationPlan(_ plan: PlaybackPresentationPlan, completion: @escaping (PlaybackPresentationAcknowledgement) -> Void) {
        setPlaybackRate(plan.requestedRate)
        completion(PlaybackPresentationAcknowledgement(activeMotionFPS: nil, activeEnhancementFeatures: [], detail: "legacy-avplayer-rate-only"))
    }
}
