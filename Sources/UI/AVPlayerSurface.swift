import AVFoundation
import SwiftUI
import UIKit

final class PlayerSurfaceUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct AVPlayerSurface: UIViewRepresentable {
    let player: AVPlayer
    let scaleMode: PlayerVideoScaleMode

    func makeUIView(context: Context) -> PlayerSurfaceUIView {
        let view = PlayerSurfaceUIView()
        view.backgroundColor = .black
        view.playerLayer.player = player
        applyScaleMode(scaleMode, to: view.playerLayer)
        return view
    }

    func updateUIView(_ uiView: PlayerSurfaceUIView, context: Context) {
        uiView.playerLayer.player = player
        applyScaleMode(scaleMode, to: uiView.playerLayer)
    }

    private func applyScaleMode(_ mode: PlayerVideoScaleMode, to layer: AVPlayerLayer) {
        switch mode {
        case .fill:
            layer.videoGravity = .resizeAspectFill
        case .ratio16x9, .ratio4x3:
            layer.videoGravity = .resize
        case .fit, .source:
            layer.videoGravity = .resizeAspect
        }
    }
}
