import Foundation

protocol PlayerPiPInlineRendererControlling: AnyObject {
    func suspendInlineRendererForPictureInPicture(completion: @escaping (Bool) -> Void)
    func resumeInlineRendererAfterPictureInPicture(completion: @escaping (Bool) -> Void)
    func resumeInlineRendererAfterPictureInPicture(targetPosition: Double, completion: @escaping (Bool, Double?) -> Void)
}

extension PlayerPiPInlineRendererControlling {
    func resumeInlineRendererAfterPictureInPicture(targetPosition: Double, completion: @escaping (Bool, Double?) -> Void) {
        resumeInlineRendererAfterPictureInPicture { success in completion(success, nil) }
    }
}

struct PlayerPiPSeekDispatchInfo: Sendable {
    let seekID: UInt64
    let requestedTarget: Double
    let dispatchTarget: Double
    let previousKeyframe: Double?
    let nextKeyframe: Double?

    var stagingTarget: Double {
        if abs(dispatchTarget - requestedTarget) > 0.001 { return dispatchTarget }
        return previousKeyframe ?? requestedTarget
    }
}

protocol PlayerPiPSeekLandingProviding: AnyObject {
    var pictureInPictureSeekDispatchHandler: ((PlayerPiPSeekDispatchInfo) -> Void)? { get set }
    var pictureInPictureSeekLandingHandler: ((SeekResult) -> Void)? { get set }
}
