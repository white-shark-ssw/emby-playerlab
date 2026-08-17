import Foundation

extension AVPlayerEngine: PlaybackPresentationEngineAdapter {
    func applyPresentationPlan(_ plan: PlaybackPresentationPlan, completion: @escaping (PlaybackPresentationAcknowledgement) -> Void) {
        setPlaybackRate(plan.requestedRate)
        completion(PlaybackPresentationAcknowledgement(activeMotionSmoothing: false, activeEnhancementFeatures: [], detail: "avplayer-rate-only"))
    }
}

extension KTVAVPlayerEngine: PlaybackPresentationEngineAdapter {
    func applyPresentationPlan(_ plan: PlaybackPresentationPlan, completion: @escaping (PlaybackPresentationAcknowledgement) -> Void) {
        setPlaybackRate(plan.requestedRate)
        completion(PlaybackPresentationAcknowledgement(activeMotionSmoothing: false, activeEnhancementFeatures: [], detail: "legacy-avplayer-rate-only"))
    }
}

extension MPVPlayerEngine: PlaybackPresentationEngineAdapter {
    func applyPresentationPlan(_ plan: PlaybackPresentationPlan, completion: @escaping (PlaybackPresentationAcknowledgement) -> Void) {
        setPlaybackRate(plan.requestedRate)
        completion(PlaybackPresentationAcknowledgement(activeMotionSmoothing: false, activeEnhancementFeatures: [], detail: "mpv-rate-v1-adapter"))
    }
}
