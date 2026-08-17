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

#if canImport(KSPlayer)
extension KSAVIOPlayerEngine: PlaybackPresentationEngineAdapter {
    func applyPresentationPlan(_ plan: PlaybackPresentationPlan, completion: @escaping (PlaybackPresentationAcknowledgement) -> Void) {
        setPlaybackRate(plan.requestedRate)
        #if MDK_LAB
        completion(PlaybackPresentationAcknowledgement(activeMotionFPS: nil, activeEnhancementFeatures: [], detail: "mdk-metal-rate-only"))
        #else
        completion(PlaybackPresentationAcknowledgement(activeMotionFPS: nil, activeEnhancementFeatures: [], detail: "ksplayer-ksme-rate-only"))
        #endif
    }
}
#endif
