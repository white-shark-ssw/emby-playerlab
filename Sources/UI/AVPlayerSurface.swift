import AVFoundation
import SwiftUI
import UIKit

final class PlayerSurfaceUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var presentationGateObserver: NSObjectProtocol?
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        presentationGateObserver = NotificationCenter.default.addObserver(forName: .onePlayerSurfacePresentationGateChanged, object: nil, queue: .main) { [weak self] _ in self?.presentationGateDidChange() }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        presentationGateObserver = NotificationCenter.default.addObserver(forName: .onePlayerSurfacePresentationGateChanged, object: nil, queue: .main) { [weak self] _ in self?.presentationGateDidChange() }
    }

    deinit {
        if let presentationGateObserver { NotificationCenter.default.removeObserver(presentationGateObserver) }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        presentationGateDidChange()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.isHidden = PlayerSurfacePresentationGate.shared.isHolding
        if window != nil { PlayerSurfacePresentationGate.shared.passiveSurfaceDidSettle() }
    }

    private func presentationGateDidChange() {
        guard Thread.isMainThread else { DispatchQueue.main.async { [weak self] in self?.presentationGateDidChange() }; return }
        playerLayer.isHidden = PlayerSurfacePresentationGate.shared.isHolding
        setNeedsLayout()
        if window != nil { layoutIfNeeded() }
    }
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
        view.playerLayer.isHidden = PlayerSurfacePresentationGate.shared.isHolding
        applyLayout(layoutPlan, to: view.playerLayer)
        DispatchQueue.main.async { onPlayerLayerReady?(view.playerLayer) }
        return view
    }

    func updateUIView(_ uiView: PlayerSurfaceUIView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.isHidden = PlayerSurfacePresentationGate.shared.isHolding
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
