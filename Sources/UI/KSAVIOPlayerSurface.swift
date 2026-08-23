import SwiftUI
import UIKit

final class KSAVIOSurfaceUIView: UIView, PlayerPiPInlineRendererControlling {
    weak var attachedView: UIView?
    private var playerViewHostedExternally = false
    private weak var pictureInPictureDetachedView: UIView?

    func attach(_ playerView: UIView) {
        if attachedView !== playerView {
            attachedView?.removeFromSuperview()
            attachedView = playerView
            playerViewHostedExternally = false
            pictureInPictureDetachedView = nil
            playerView.removeFromSuperview()
            playerView.frame = bounds
            playerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(playerView)
            return
        }
        guard !playerViewHostedExternally else { return }
        if playerView.superview !== self {
            playerView.removeFromSuperview()
            playerView.frame = bounds
            playerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(playerView)
        }
    }

    func takePlayerViewForPictureInPicture() -> UIView? {
        guard let attachedView, !playerViewHostedExternally else { return nil }
        playerViewHostedExternally = true
        attachedView.removeFromSuperview()
        DiagnosticsLogger.shared.playback("PiPRenderer", "MDK inline view detached surface=\(ObjectIdentifier(self))")
        return attachedView
    }

    func restorePlayerViewAfterPictureInPicture(_ playerView: UIView) {
        guard attachedView === playerView else { return }
        playerViewHostedExternally = false
        playerView.removeFromSuperview()
        playerView.frame = bounds
        playerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(playerView)
        setNeedsLayout()
        if window != nil { layoutIfNeeded() }
        DiagnosticsLogger.shared.playback("PiPRenderer", "MDK inline view restored surface=\(ObjectIdentifier(self))")
    }

    func suspendInlineRendererForPictureInPicture(completion: @escaping (Bool) -> Void) {
        if pictureInPictureDetachedView != nil, playerViewHostedExternally { completion(true); return }
        guard let playerView = takePlayerViewForPictureInPicture() else {
            DiagnosticsLogger.shared.playback("PiPRenderer", "MDK suspend failed reason=no-inline-view")
            completion(false)
            return
        }
        pictureInPictureDetachedView = playerView
        completion(true)
    }

    func resumeInlineRendererAfterPictureInPicture(completion: @escaping (Bool) -> Void) {
        guard let playerView = pictureInPictureDetachedView else { completion(!playerViewHostedExternally); return }
        pictureInPictureDetachedView = nil
        restorePlayerViewAfterPictureInPicture(playerView)
        completion(!playerViewHostedExternally && playerView.superview === self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !playerViewHostedExternally else { return }
        attachedView?.frame = bounds
    }
}

struct KSAVIOPlayerSurface: UIViewRepresentable {
    let playerView: UIView

    func makeUIView(context: Context) -> KSAVIOSurfaceUIView {
        let view = KSAVIOSurfaceUIView()
        view.backgroundColor = .black
        view.attach(playerView)
        return view
    }

    func updateUIView(_ uiView: KSAVIOSurfaceUIView, context: Context) { uiView.attach(playerView) }
    static func dismantleUIView(_ uiView: KSAVIOSurfaceUIView, coordinator: ()) { uiView.attachedView?.removeFromSuperview() }
}
