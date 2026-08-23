import SwiftUI
import UIKit

final class KSAVIOSurfaceUIView: UIView {
    weak var attachedView: UIView?
    private var playerViewHostedExternally = false

    func attach(_ playerView: UIView) {
        if attachedView !== playerView {
            attachedView?.removeFromSuperview()
            attachedView = playerView
            playerViewHostedExternally = false
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
        DiagnosticsLogger.shared.playback("PiP", "MDK renderer detached after PiP content became visible")
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
        DiagnosticsLogger.shared.playback("PiP", "MDK renderer restored to inline surface")
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
