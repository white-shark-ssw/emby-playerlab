import SwiftUI
import UIKit

final class KSAVIOSurfaceUIView: UIView {
    weak var attachedView: UIView?

    func attach(_ playerView: UIView) {
        guard attachedView !== playerView else { return }
        attachedView?.removeFromSuperview()
        attachedView = playerView
        playerView.removeFromSuperview()
        playerView.frame = bounds
        playerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(playerView)
    }

    func takePlayerViewForPictureInPicture() -> UIView? {
        guard let attachedView else { return nil }
        attachedView.removeFromSuperview()
        DiagnosticsLogger.shared.playback("PiP", "MDK renderer detached from inline surface")
        return attachedView
    }

    func restorePlayerViewAfterPictureInPicture(_ playerView: UIView) {
        attach(playerView)
        setNeedsLayout()
        if window != nil { layoutIfNeeded() }
        DiagnosticsLogger.shared.playback("PiP", "MDK renderer restored to inline surface")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
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
