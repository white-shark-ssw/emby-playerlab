import Foundation
import QuartzCore
import SwiftUI
import UIKit

final class MPVSurfaceUIView: UIView {
    private var displayLayer: CAMetalLayer?
    private var lastGeometryLog = ""

    func attach(_ layer: CAMetalLayer) {
        if displayLayer !== layer {
            displayLayer?.removeFromSuperlayer()
            displayLayer = layer
            self.layer.addSublayer(layer)
            DiagnosticsLogger.shared.log("MPVSurface", "attach layer=CAMetalLayer host=UIViewRepresentable")
        }
        setNeedsLayout()
    }

    func detach() {
        displayLayer?.removeFromSuperlayer()
        displayLayer = nil
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
        let scale = window?.screen.nativeScale ?? UIScreen.main.nativeScale
        let expectedDrawable = CGSize(width: max(2, (bounds.width * scale).rounded()), height: max(2, (bounds.height * scale).rounded()))
        let previousDrawable = displayLayer.drawableSize
        let drawableNeedsSync = abs(previousDrawable.width - expectedDrawable.width) > 1 || abs(previousDrawable.height - expectedDrawable.height) > 1

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.transform = CATransform3DIdentity
        displayLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        displayLayer.bounds = CGRect(origin: .zero, size: bounds.size)
        displayLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        displayLayer.contentsScale = scale
        if drawableNeedsSync { displayLayer.drawableSize = expectedDrawable }
        CATransaction.commit()

        let windowSize = window?.bounds.size ?? .zero
        let orientation = window?.windowScene?.interfaceOrientation.rawValue ?? 0
        let repair = drawableNeedsSync ? " repair=size-sync previous=\(Int(previousDrawable.width))x\(Int(previousDrawable.height)) expected=\(Int(expectedDrawable.width))x\(Int(expectedDrawable.height)) actual=\(Int(displayLayer.drawableSize.width))x\(Int(displayLayer.drawableSize.height))" : ""
        let geometry = "view=\(Int(bounds.width))x\(Int(bounds.height)) layer=\(Int(displayLayer.bounds.width))x\(Int(displayLayer.bounds.height)) drawable=\(Int(displayLayer.drawableSize.width))x\(Int(displayLayer.drawableSize.height)) window=\(Int(windowSize.width))x\(Int(windowSize.height)) orientation=\(orientation) scale=\(String(format: "%.2f", displayLayer.contentsScale))\(repair)"
        if geometry != lastGeometryLog {
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
