import AVFoundation
import SwiftUI
import UIKit

final class MPVSurfaceUIView: UIView {
    private var displayLayer: AVSampleBufferDisplayLayer?
    private var statusObservation: NSKeyValueObservation?

    func attach(_ layer: AVSampleBufferDisplayLayer) {
        if displayLayer !== layer {
            statusObservation?.invalidate()
            displayLayer?.removeFromSuperlayer()
            displayLayer = layer
            self.layer.addSublayer(layer)
            statusObservation = layer.observe(\.status, options: [.initial, .new]) { observedLayer, _ in
                if observedLayer.status == .failed {
                    let error = observedLayer.error?.localizedDescription ?? "unknown"
                    DiagnosticsLogger.shared.log("MPV", "AVSampleBufferDisplayLayer failed: \(error)")
                }
            }
        }
        setNeedsLayout()
    }

    deinit {
        statusObservation?.invalidate()
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
