import AVFoundation
import SwiftUI
import UIKit

final class MPVSurfaceUIView: UIView {
    private var displayLayer: AVSampleBufferDisplayLayer?

    func attach(_ layer: AVSampleBufferDisplayLayer) {
        if displayLayer !== layer {
            displayLayer?.removeFromSuperlayer()
            displayLayer = layer
            self.layer.addSublayer(layer)
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer?.frame = bounds
        CATransaction.commit()
    }
}

struct MPVPlayerSurface: UIViewRepresentable {
    let displayLayer: AVSampleBufferDisplayLayer

    func makeUIView(context: Context) -> MPVSurfaceUIView {
        let view = MPVSurfaceUIView()
        view.backgroundColor = .black
        view.attach(displayLayer)
        return view
    }

    func updateUIView(_ uiView: MPVSurfaceUIView, context: Context) {
        uiView.attach(displayLayer)
    }
}
