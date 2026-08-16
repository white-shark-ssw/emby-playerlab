import AVFoundation
import SwiftUI
import UIKit

final class PlayerSurfaceUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct AVPlayerSurface: UIViewRepresentable {
    let player: AVPlayer
    let layoutPlan: VideoLayoutPlan
    let onPlayerLayerReady: ((AVPlayerLayer) -> Void)?

    init(player: AVPlayer, layoutPlan: VideoLayoutPlan, onPlayerLayerReady: ((AVPlayerLayer) -> Void)? = nil) {
        self.player = player
        self.layoutPlan = layoutPlan
        self.onPlayerLayerReady = onPlayerLayerReady
    }

    func makeUIView(context: Context) -> PlayerSurfaceUIView {
        let view = PlayerSurfaceUIView()
        view.backgroundColor = .black
        view.playerLayer.player = player
        applyLayout(layoutPlan, to: view.playerLayer)
        DispatchQueue.main.async { onPlayerLayerReady?(view.playerLayer) }
        return view
    }

    func updateUIView(_ uiView: PlayerSurfaceUIView, context: Context) {
        uiView.playerLayer.player = player
        applyLayout(layoutPlan, to: uiView.playerLayer)
        DispatchQueue.main.async { onPlayerLayerReady?(uiView.playerLayer) }
    }

    private func applyLayout(_ plan: VideoLayoutPlan, to layer: AVPlayerLayer) {
        switch plan.contentMode {
        case .aspectFit: layer.videoGravity = .resizeAspect
        case .aspectFill: layer.videoGravity = .resizeAspectFill
        case .stretch: layer.videoGravity = .resize
        }
    }
}
