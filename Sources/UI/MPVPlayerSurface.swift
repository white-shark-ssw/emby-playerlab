import QuartzCore
import SwiftUI
import UIKit

final class MPVSurfaceUIView: UIView {
    private var displayLayer: CAMetalLayer?

    func attach(_ layer: CAMetalLayer) {
        if displayLayer !== layer {
            displayLayer?.removeFromSuperlayer()
            displayLayer = layer
            self.layer.addSublayer(layer)
        }
        setNeedsLayout()
    }

    func detach() {
        displayLayer?.removeFromSuperlayer()
        displayLayer = nil
    }

    deinit { detach() }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let displayLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.frame = bounds
        displayLayer.contentsScale = window?.screen.nativeScale ?? UIScreen.main.nativeScale
        displayLayer.drawableSize = CGSize(width: max(1, bounds.width * displayLayer.contentsScale), height: max(1, bounds.height * displayLayer.contentsScale))
        CATransaction.commit()
    }
}

struct MPVPlayerSurface: UIViewRepresentable {
    let displayLayer: CAMetalLayer

    func makeUIView(context: Context) -> MPVSurfaceUIView {
        let view = MPVSurfaceUIView()
        view.backgroundColor = .black
        view.attach(displayLayer)
        return view
    }

    func updateUIView(_ uiView: MPVSurfaceUIView, context: Context) { uiView.attach(displayLayer) }

    static func dismantleUIView(_ uiView: MPVSurfaceUIView, coordinator: ()) { uiView.detach() }
}
