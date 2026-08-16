import Foundation
import QuartzCore
import SwiftUI
import UIKit

final class MPVSurfaceUIView: UIView {
    private var displayLayer: CAMetalLayer?
    private var lastGeometryLog = ""
    private var lastReportedGeometry: RendererSurfaceGeometry?
    private var layoutGeneration: UInt64 = 0
    private var presentationGateObserver: NSObjectProtocol?
    var onGeometrySettled: ((RendererSurfaceGeometry) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        presentationGateObserver = NotificationCenter.default.addObserver(forName: .onePlayerSurfacePresentationGateChanged, object: nil, queue: .main) { [weak self] _ in self?.presentationGateDidChange() }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        presentationGateObserver = NotificationCenter.default.addObserver(forName: .onePlayerSurfacePresentationGateChanged, object: nil, queue: .main) { [weak self] _ in self?.presentationGateDidChange() }
    }

    func attach(_ layer: CAMetalLayer) {
        if displayLayer !== layer {
            displayLayer?.removeFromSuperlayer()
            displayLayer = layer
            layer.masksToBounds = true
            layer.isHidden = PlayerSurfacePresentationGate.shared.isHolding
            self.layer.addSublayer(layer)
            lastReportedGeometry = nil
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
        lastReportedGeometry = nil
    }

    deinit {
        if let presentationGateObserver { NotificationCenter.default.removeObserver(presentationGateObserver) }
        detach()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        presentationGateDidChange()
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
        displayLayer.isHidden = PlayerSurfacePresentationGate.shared.isHolding
        displayLayer.setNeedsDisplay()
        CATransaction.commit()

        if let geometry = logGeometry(stage: "layout", generation: generation) {
            let settled = reportGeometryIfReady(geometry)
            if settled { return }
        }
        scheduleGeometryProbe(generation: generation, attempt: 0)
    }

    private func presentationGateDidChange() {
        guard Thread.isMainThread else { DispatchQueue.main.async { [weak self] in self?.presentationGateDidChange() }; return }
        let hidden = PlayerSurfacePresentationGate.shared.isHolding
        if displayLayer?.isHidden != hidden { displayLayer?.isHidden = hidden }
        setNeedsLayout()
        if window != nil { layoutIfNeeded() }
    }

    private func scheduleGeometryProbe(generation: UInt64, attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            guard let self, self.layoutGeneration == generation, self.window != nil else { return }
            let geometry = self.logGeometry(stage: attempt == 0 ? "settled" : "probe\(attempt)", generation: generation, force: true)
            guard let geometry else { return }
            if self.reportGeometryIfReady(geometry) { return }
            if attempt < 8 { self.scheduleGeometryProbe(generation: generation, attempt: attempt + 1) }
        }
    }

    private func reportGeometryIfReady(_ geometry: RendererSurfaceGeometry) -> Bool {
        let backingMatches = geometry.hasObservedBacking && RendererSurfaceGeometry.matches(geometry.observedBackingSize, geometry.expectedBackingSize, tolerance: 3)
        if geometry != lastReportedGeometry {
            lastReportedGeometry = geometry
            onGeometrySettled?(geometry)
        }
        return backingMatches
    }

    @discardableResult
    private func logGeometry(stage: String, generation: UInt64, force: Bool = false) -> RendererSurfaceGeometry? {
        guard let displayLayer else { return nil }
        let scale = displayLayer.contentsScale > 0 ? displayLayer.contentsScale : (window?.screen.nativeScale ?? UIScreen.main.nativeScale)
        let expectedDrawable = CGSize(width: max(2, (bounds.width * scale).rounded()), height: max(2, (bounds.height * scale).rounded()))
        let windowSize = window?.bounds.size ?? .zero
        let orientation = window?.windowScene?.interfaceOrientation.rawValue ?? 0
        let actualDrawable = displayLayer.drawableSize
        let geometry = "surface=\(ObjectIdentifier(self)) stage=\(stage) generation=\(generation) view=\(Int(bounds.width))x\(Int(bounds.height)) layer=\(Int(displayLayer.bounds.width))x\(Int(displayLayer.bounds.height)) drawable=\(Int(actualDrawable.width))x\(Int(actualDrawable.height)) expected=\(Int(expectedDrawable.width))x\(Int(expectedDrawable.height)) window=\(Int(windowSize.width))x\(Int(windowSize.height)) orientation=\(orientation) scale=\(String(format: "%.2f", scale)) lifecycle=persistent drawableOwner=moltenvk delegateOwner=unchanged hidden=\(displayLayer.isHidden)"
        if force || geometry != lastGeometryLog {
            lastGeometryLog = geometry
            DiagnosticsLogger.shared.log("MPVSurface", geometry)
        }
        return RendererSurfaceGeometry(pointSize: bounds.size, expectedBackingSize: expectedDrawable, observedBackingSize: actualDrawable, scale: scale)
    }
}

struct MPVPlayerSurface: UIViewRepresentable {
    let displayLayer: CAMetalLayer
    var onGeometrySettled: (RendererSurfaceGeometry) -> Void = { _ in }

    func makeUIView(context: Context) -> MPVSurfaceUIView {
        let view = MPVSurfaceUIView()
        view.backgroundColor = .black
        view.isOpaque = true
        view.clipsToBounds = true
        view.onGeometrySettled = onGeometrySettled
        view.attach(displayLayer)
        return view
    }

    func updateUIView(_ uiView: MPVSurfaceUIView, context: Context) {
        uiView.onGeometrySettled = onGeometrySettled
        uiView.attach(displayLayer)
        uiView.setNeedsLayout()
    }

    static func dismantleUIView(_ uiView: MPVSurfaceUIView, coordinator: ()) { uiView.detach() }
}
