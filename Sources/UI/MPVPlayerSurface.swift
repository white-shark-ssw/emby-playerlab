import Foundation
import QuartzCore
import SwiftUI
import UIKit

final class MPVSurfaceUIView: UIView {
    private var displayLayer: CAMetalLayer?
    private var lastGeometryLog = ""

    func attach(_ layer: CAMetalLayer) {
        if displayLayer !== layer {
            displayLayer?.delegate = nil
            displayLayer?.removeFromSuperlayer()
            displayLayer = layer
            layer.delegate = self
            layer.masksToBounds = true
            self.layer.addSublayer(layer)
            DiagnosticsLogger.shared.log("MPVSurface", "attach layer=CAMetalLayer host=UIViewRepresentable delegate=host-view")
        } else if layer.delegate == nil {
            layer.delegate = self
        }
        setNeedsLayout()
    }

    func detach() {
        displayLayer?.delegate = nil
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

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.transform = CATransform3DIdentity
        displayLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        displayLayer.frame = bounds
        displayLayer.contentsScale = scale
        CATransaction.commit()

        // Do not force CAMetalLayer.drawableSize here. MPV owns a Vulkan/MoltenVK swapchain for
        // this layer; mutating drawableSize behind that swapchain can leave the layer dimensions
        // and the renderer's swapchain extent describing different orientations. The containing
        // UIView is installed as the CAMetalLayer delegate so MoltenVK can observe bounds/display
        // changes and rebuild its presentation geometry itself.
        let windowSize = window?.bounds.size ?? .zero
        let orientation = window?.windowScene?.interfaceOrientation.rawValue ?? 0
        let actualDrawable = displayLayer.drawableSize
        let geometry = "view=\(Int(bounds.width))x\(Int(bounds.height)) layer=\(Int(displayLayer.bounds.width))x\(Int(displayLayer.bounds.height)) drawable=\(Int(actualDrawable.width))x\(Int(actualDrawable.height)) expected=\(Int(expectedDrawable.width))x\(Int(expectedDrawable.height)) window=\(Int(windowSize.width))x\(Int(windowSize.height)) orientation=\(orientation) scale=\(String(format: "%.2f", displayLayer.contentsScale)) drawableOwner=moltenvk"
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
