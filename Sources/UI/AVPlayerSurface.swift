import AVFoundation
import SwiftUI
import UIKit

final class PlayerSurfaceUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private let presentationCoverView = UIView()
    private var presentationGateObserver: NSObjectProtocol?
    var expectedPointSize: CGSize = .zero
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configurePresentationCover()
        presentationGateObserver = NotificationCenter.default.addObserver(forName: .onePlayerSurfacePresentationGateChanged, object: nil, queue: .main) { [weak self] _ in self?.presentationGateDidChange() }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configurePresentationCover()
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
        presentationCoverView.frame = bounds
        bringSubviewToFront(presentationCoverView)
        let expectedMatches = expectedPointSize.width > 0 && RendererSurfaceGeometry.matches(bounds.size, expectedPointSize, tolerance: 1.5)
        if window != nil, expectedMatches { PlayerSurfacePresentationGate.shared.passiveSurfaceDidSettle() }
    }

    private func configurePresentationCover() {
        presentationCoverView.backgroundColor = .black
        presentationCoverView.isUserInteractionEnabled = false
        presentationCoverView.isHidden = !PlayerSurfacePresentationGate.shared.isHolding
        addSubview(presentationCoverView)
    }

    private func presentationGateDidChange() {
        guard Thread.isMainThread else { DispatchQueue.main.async { [weak self] in self?.presentationGateDidChange() }; return }
        presentationCoverView.isHidden = !PlayerSurfacePresentationGate.shared.isHolding
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
        view.expectedPointSize = layoutPlan.surfaceFrame.size
        view.playerLayer.player = player
        applyLayout(layoutPlan, to: view.playerLayer)
        DispatchQueue.main.async { onPlayerLayerReady?(view.playerLayer) }
        return view
    }

    func updateUIView(_ uiView: PlayerSurfaceUIView, context: Context) {
        uiView.expectedPointSize = layoutPlan.surfaceFrame.size
        uiView.playerLayer.player = player
        applyLayout(layoutPlan, to: uiView.playerLayer)
        uiView.setNeedsLayout()
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
