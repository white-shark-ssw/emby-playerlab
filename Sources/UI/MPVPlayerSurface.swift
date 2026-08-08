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
            DiagnosticsLogger.shared.log("MPVSurface", "attach layer=CAMetalLayer")
        }
        setNeedsLayout()
    }

    func detach() {
        displayLayer?.removeFromSuperlayer()
        displayLayer = nil
        lastGeometryLog = ""
    }

    deinit { detach() }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let displayLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.transform = CATransform3DIdentity
        displayLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        displayLayer.bounds = CGRect(origin: .zero, size: bounds.size)
        displayLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        displayLayer.contentsScale = window?.screen.nativeScale ?? UIScreen.main.nativeScale
        CATransaction.commit()

        let windowSize = window?.bounds.size ?? .zero
        let orientation = window?.windowScene?.interfaceOrientation.rawValue ?? 0
        let geometry = "view=\(Int(bounds.width))x\(Int(bounds.height)) layer=\(Int(displayLayer.bounds.width))x\(Int(displayLayer.bounds.height)) drawable=\(Int(displayLayer.drawableSize.width))x\(Int(displayLayer.drawableSize.height)) window=\(Int(windowSize.width))x\(Int(windowSize.height)) orientation=\(orientation) scale=\(String(format: "%.2f", displayLayer.contentsScale))"
        if geometry != lastGeometryLog {
            lastGeometryLog = geometry
            DiagnosticsLogger.shared.log("MPVSurface", geometry)
        }
    }
}

final class MPVSurfaceViewController: UIViewController {
    private let surfaceView = MPVSurfaceUIView()

    override func loadView() {
        surfaceView.backgroundColor = .black
        surfaceView.isOpaque = true
        surfaceView.clipsToBounds = true
        view = surfaceView
    }

    func attach(_ layer: CAMetalLayer) { surfaceView.attach(layer) }
    func detach() { surfaceView.detach() }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        surfaceView.setNeedsLayout()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        DiagnosticsLogger.shared.log("MPVSurface", "transition target=\(Int(size.width))x\(Int(size.height))")
        coordinator.animate(alongsideTransition: { [weak self] _ in self?.surfaceView.setNeedsLayout() }) { [weak self] _ in
            self?.surfaceView.setNeedsLayout()
            self?.surfaceView.layoutIfNeeded()
        }
        super.viewWillTransition(to: size, with: coordinator)
    }
}

struct MPVPlayerSurface: UIViewControllerRepresentable {
    let displayLayer: CAMetalLayer

    func makeUIViewController(context: Context) -> MPVSurfaceViewController {
        let controller = MPVSurfaceViewController()
        controller.loadViewIfNeeded()
        controller.attach(displayLayer)
        return controller
    }

    func updateUIViewController(_ uiViewController: MPVSurfaceViewController, context: Context) { uiViewController.attach(displayLayer) }
    static func dismantleUIViewController(_ uiViewController: MPVSurfaceViewController, coordinator: ()) { uiViewController.detach() }
}
