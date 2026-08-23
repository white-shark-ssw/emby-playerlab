import Foundation

protocol PlayerPiPInlineRendererControlling: AnyObject {
    func suspendInlineRendererForPictureInPicture(completion: @escaping (Bool) -> Void)
    func resumeInlineRendererAfterPictureInPicture(completion: @escaping (Bool) -> Void)
}
