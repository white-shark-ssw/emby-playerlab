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

protocol PlayerPiPSeekLandingProviding: AnyObject {
    var pictureInPictureSeekLandingHandler: ((SeekResult) -> Void)? { get set }
}
