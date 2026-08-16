import Foundation
import QuartzCore
import SwiftUI
import UIKit

final class MPVSurfaceUIView: UIView {
    private var displayLayer: CAMetalLayer?
    private var lastGeometryLog = ""
    private var layoutGeneration: UInt64 = 0

    func attach(_ layer: CAMetalLayer) {
        if displayLayer !== layer {
            displayLayer?.removeFromSuperlayer()
            displayLayer = layer
            layer.masksToBounds = true
            self.layer.addSublayer(layer)
            DiagnosticsLogger.shared.log("MPVSurface", "attach surface=\(ObjectIdentifier(self)) layer=CAMetalLayer host=UIViewRepresentable lifecycle=persistent drawableOwner=moltenvk")
        }
        setNeedsLayout()
    }

    func detach() {
        guard let displayLayer else { return }
        DiagnosticsLogger.shared.log("MPVSurface", "detach surface=\(ObjectIdentifier(self)) generation=\(layoutGeneration)")
        displayLayer.removeFromSuperlayer()
        self.displayLayer = nil
        lastGeometryLog = ""
    }

    deinit { detach() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let displayLayer else { return }
        layoutGeneration &+= 1
        let generation = layoutGeneration
        let scale = window?.screen.nativeScale ?? UIScreen.main.nativeScale

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.transform = CATransform3DIdentity
        displayLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        displayLayer.frame = bounds
        displayLayer.contentsScale = scale
        displayLayer.setNeedsDisplay()
        CATransaction.commit()

        logGeometry(stage: "layout", generation: generation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, self.layoutGeneration == generation, self.window != nil else { return }
            self.logGeometry(stage: "settled", generation: generation, force: true)
        }
    }

    private func logGeometry(stage: String, generation: UInt64, force: Bool = false) {
        guard let displayLayer else { return }
        let scale = displayLayer.contentsScale > 0 ? displayLayer.contentsScale : (window?.screen.nativeScale ?? UIScreen.main.nativeScale)
        let expectedDrawable = CGSize(width: max(2, (bounds.width * scale).rounded()), height: max(2, (bounds.height * scale).rounded()))
        let windowSize = window?.bounds.size ?? .zero
        let orientation = window?.windowScene?.interfaceOrientation.rawValue ?? 0
        let actualDrawable = displayLayer.drawableSize
        let geometry = "surface=\(ObjectIdentifier(self)) stage=\(stage) generation=\(generation) view=\(Int(bounds.width))x\(Int(bounds.height)) layer=\(Int(displayLayer.bounds.width))x\(Int(displayLayer.bounds.height)) drawable=\(Int(actualDrawable.width))x\(Int(actualDrawable.height)) expected=\(Int(expectedDrawable.width))x\(Int(expectedDrawable.height)) window=\(Int(windowSize.width))x\(Int(windowSize.height)) orientation=\(orientation) scale=\(String(format: "%.2f", scale)) lifecycle=persistent drawableOwner=moltenvk delegateOwner=unchanged"
        if force || geometry != lastGeometryLog {
            lastGeometryLog = geometry
            DiagnosticsLogger.shared.log("MPVSurface", geometry)
        }
    }
}

struct MPVPlayerSurface: UIViewRepresentable {
    let displayLayer: CAMetalLayer

    func makeUIView(context: Context) -> MPVSurfaceUIView {
        let view = MPVSurfaceUIView()
        view.backgroundColor = .black
        view.isOpaque = true
        view.clipsToBounds = true
        view.attach(displayLayer)
        return view
    }

    func updateUIView(_ uiView: MPVSurfaceUIView, context: Context) {
        uiView.attach(displayLayer)
        uiView.setNeedsLayout()
    }

    static func dismantleUIView(_ uiView: MPVSurfaceUIView, coordinator: ()) { uiView.detach() }
}
