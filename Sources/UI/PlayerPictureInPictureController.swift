import AVFoundation
import AVKit
import Combine
import QuartzCore
import UIKit

@MainActor
final class PlayerPictureInPictureController: NSObject, ObservableObject, @preconcurrency AVPictureInPictureControllerDelegate {
    @Published private(set) var isPossible = AVPictureInPictureController.isPictureInPictureSupported()
    @Published private(set) var isActive = false

    private weak var playerLayer: AVPlayerLayer?
    private var controller: AVPictureInPictureController?
    private var possibleObservation: NSKeyValueObservation?
    private var customContentController: PlayerCustomPiPContentViewController?
    private var activateCustomRenderer: (() -> Void)?
    private var restoreCustomRenderer: (() -> Void)?
    private var customStartPending = false
    private var customStartTimeout: DispatchWorkItem?

    func attach(playerLayer: AVPlayerLayer) {
        guard self.playerLayer !== playerLayer else { return }
        stopAndDetach()
        self.playerLayer = playerLayer
        guard AVPictureInPictureController.isPictureInPictureSupported(), let pictureInPictureController = AVPictureInPictureController(playerLayer: playerLayer) else {
            isPossible = false
            return
        }

        pictureInPictureController.delegate = self
        if #available(iOS 14.2, *) { pictureInPictureController.canStartPictureInPictureAutomaticallyFromInline = true }
        observePossible(pictureInPictureController)
        controller = pictureInPictureController
    }

    func toggle() {
        if let controller, controller.isPictureInPictureActive {
            controller.stopPictureInPicture()
            return
        }
        if playerLayer != nil, let controller {
            if controller.isPictureInPicturePossible { controller.startPictureInPicture() }
            return
        }
        startCustomRendererPictureInPicture()
    }

    func stopAndDetach() {
        customStartTimeout?.cancel()
        customStartTimeout = nil
        customStartPending = false
        possibleObservation = nil
        if controller?.isPictureInPictureActive == true { controller?.stopPictureInPicture() }
        controller?.delegate = nil
        controller = nil
        playerLayer = nil
        activateCustomRenderer = nil
        restoreCustomRendererIfNeeded(reason: "detach")
        customContentController = nil
        isPossible = AVPictureInPictureController.isPictureInPictureSupported()
        isActive = false
    }

    private func observePossible(_ pictureInPictureController: AVPictureInPictureController) {
        possibleObservation = pictureInPictureController.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] controller, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isPossible = controller.isPictureInPicturePossible || (self.playerLayer == nil && AVPictureInPictureController.isPictureInPictureSupported())
                self.startCustomControllerIfReady(controller)
            }
        }
    }

    private func startCustomRendererPictureInPicture() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            isPossible = false
            return
        }
        guard #available(iOS 15.0, *) else { return }
        guard controller == nil, activateCustomRenderer == nil, restoreCustomRenderer == nil else { return }
        guard let window = activeKeyWindow() else {
            DiagnosticsLogger.shared.playback("PiP", "custom renderer start skipped reason=no-key-window")
            return
        }

        let contentController = PlayerCustomPiPContentViewController()
        let sourceView: UIView
        if let surface: MPVSurfaceUIView = findVisibleSubview(of: MPVSurfaceUIView.self, in: window) {
            sourceView = surface
            activateCustomRenderer = { [weak self, weak surface, weak contentController] in
                guard let self, self.restoreCustomRenderer == nil, let surface, let contentController, let layer = surface.takeDisplayLayerForPictureInPicture() else { return }
                contentController.host(layer: layer)
                self.restoreCustomRenderer = { [weak surface] in surface?.restoreDisplayLayerAfterPictureInPicture(layer) }
                DiagnosticsLogger.shared.playback("PiP", "custom renderer transferred source=MPV phase=content-visible")
            }
            DiagnosticsLogger.shared.playback("PiP", "custom renderer prepared source=MPV inline-preserved=true")
        } else if let surface: KSAVIOSurfaceUIView = findVisibleSubview(of: KSAVIOSurfaceUIView.self, in: window) {
            sourceView = surface
            activateCustomRenderer = { [weak self, weak surface, weak contentController] in
                guard let self, self.restoreCustomRenderer == nil, let surface, let contentController, let playerView = surface.takePlayerViewForPictureInPicture() else { return }
                contentController.host(view: playerView)
                self.restoreCustomRenderer = { [weak surface] in surface?.restorePlayerViewAfterPictureInPicture(playerView) }
                DiagnosticsLogger.shared.playback("PiP", "custom renderer transferred source=MDK phase=content-visible")
            }
            DiagnosticsLogger.shared.playback("PiP", "custom renderer prepared source=MDK inline-preserved=true")
        } else {
            DiagnosticsLogger.shared.playback("PiP", "custom renderer start skipped reason=no-supported-inline-surface")
            return
        }

        contentController.preferredContentSize = sourceView.bounds.size
        contentController.onContentVisible = { [weak self] in
            DiagnosticsLogger.shared.playback("PiP", "custom content view appeared")
            self?.activateCustomRendererIfNeeded()
        }
        contentController.onContentHidden = { DiagnosticsLogger.shared.playback("PiP", "custom content view disappeared") }
        customContentController = contentController

        let contentSource = AVPictureInPictureController.ContentSource(activeVideoCallSourceView: sourceView, contentViewController: contentController)
        let pictureInPictureController = AVPictureInPictureController(contentSource: contentSource)
        pictureInPictureController.delegate = self
        pictureInPictureController.requiresLinearPlayback = false
        if #available(iOS 14.2, *) { pictureInPictureController.canStartPictureInPictureAutomaticallyFromInline = true }
        controller = pictureInPictureController
        customStartPending = true
        observePossible(pictureInPictureController)
        DiagnosticsLogger.shared.playback("PiP", "custom controller created possible=\(pictureInPictureController.isPictureInPicturePossible) sourceView=\(Int(sourceView.bounds.width))x\(Int(sourceView.bounds.height))")
        startCustomControllerIfReady(pictureInPictureController)

        if customStartPending {
            let workItem = DispatchWorkItem { [weak self, weak pictureInPictureController] in
                guard let self, self.customStartPending, self.controller === pictureInPictureController else { return }
                self.customStartPending = false
                DiagnosticsLogger.shared.playback("PiP", "custom renderer start timeout possible=\(pictureInPictureController?.isPictureInPicturePossible ?? false); inline renderer preserved")
                self.resetCustomControllerAndRestore(reason: "start-timeout")
            }
            customStartTimeout = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
        }
    }

    private func startCustomControllerIfReady(_ pictureInPictureController: AVPictureInPictureController) {
        guard customStartPending, controller === pictureInPictureController, pictureInPictureController.isPictureInPicturePossible else { return }
        customStartPending = false
        customStartTimeout?.cancel()
        customStartTimeout = nil
        DiagnosticsLogger.shared.playback("PiP", "custom renderer source ready; starting system PiP with inline renderer still attached")
        pictureInPictureController.startPictureInPicture()
    }

    private func activateCustomRendererIfNeeded() {
        guard restoreCustomRenderer == nil, let activateCustomRenderer else { return }
        self.activateCustomRenderer = nil
        activateCustomRenderer()
    }

    private func activeKeyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first(where: { $0.activationState == .foregroundInactive })
        return scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first(where: { !$0.isHidden })
    }

    private func findVisibleSubview<T: UIView>(of type: T.Type, in root: UIView) -> T? {
        if let match = root as? T, match.window != nil, !match.isHidden, match.alpha > 0.01, match.bounds.width > 1, match.bounds.height > 1 { return match }
        for child in root.subviews {
            if let match: T = findVisibleSubview(of: type, in: child) { return match }
        }
        return nil
    }

    private func resetCustomControllerAndRestore(reason: String) {
        customStartTimeout?.cancel()
        customStartTimeout = nil
        customStartPending = false
        possibleObservation = nil
        controller?.delegate = nil
        controller = nil
        activateCustomRenderer = nil
        restoreCustomRendererIfNeeded(reason: reason)
        customContentController = nil
        isPossible = AVPictureInPictureController.isPictureInPictureSupported()
    }

    private func restoreCustomRendererIfNeeded(reason: String) {
        guard let restoreCustomRenderer else { return }
        self.restoreCustomRenderer = nil
        restoreCustomRenderer()
        DiagnosticsLogger.shared.playback("PiP", "custom renderer restored reason=\(reason)")
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        customStartTimeout?.cancel()
        customStartTimeout = nil
        customStartPending = false
        isActive = true
        activateCustomRendererIfNeeded()
        DiagnosticsLogger.shared.playback("PiP", "started customRenderer=\(customContentController != nil) rendererTransferred=\(restoreCustomRenderer != nil)")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isActive = false
        DiagnosticsLogger.shared.playback("PiP", "stopped customRenderer=\(customContentController != nil) rendererTransferred=\(restoreCustomRenderer != nil)")
        if customContentController != nil { resetCustomControllerAndRestore(reason: "stopped") }
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        isActive = false
        DiagnosticsLogger.shared.playback("PiP", "start failed error=\(error.localizedDescription) customRenderer=\(customContentController != nil) rendererTransferred=\(restoreCustomRenderer != nil)")
        if customContentController != nil { resetCustomControllerAndRestore(reason: "start-failed") }
    }
}

@available(iOS 15.0, *)
private final class PlayerCustomPiPContentViewController: AVPictureInPictureVideoCallViewController {
    var onContentVisible: (() -> Void)?
    var onContentHidden: (() -> Void)?
    private var hostedView: UIView?
    private var hostedLayer: CALayer?

    override func loadView() {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        view.clipsToBounds = true
        self.view = view
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        onContentVisible?()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        onContentHidden?()
    }

    func host(view hostedView: UIView) {
        loadViewIfNeeded()
        self.hostedLayer?.removeFromSuperlayer()
        self.hostedLayer = nil
        self.hostedView?.removeFromSuperview()
        self.hostedView = hostedView
        hostedView.removeFromSuperview()
        hostedView.frame = view.bounds
        hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hostedView)
    }

    func host(layer hostedLayer: CALayer) {
        loadViewIfNeeded()
        self.hostedView?.removeFromSuperview()
        self.hostedView = nil
        self.hostedLayer?.removeFromSuperlayer()
        self.hostedLayer = hostedLayer
        hostedLayer.removeFromSuperlayer()
        hostedLayer.frame = view.bounds
        hostedLayer.contentsScale = view.window?.screen.nativeScale ?? UIScreen.main.nativeScale
        view.layer.addSublayer(hostedLayer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        hostedView?.frame = view.bounds
        if let hostedLayer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            hostedLayer.frame = view.bounds
            hostedLayer.contentsScale = view.window?.screen.nativeScale ?? UIScreen.main.nativeScale
            CATransaction.commit()
        }
    }
}
