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
    private var customContentController: UIViewController?
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
        restoreCustomRendererIfNeeded(reason: "detach")
        isPossible = AVPictureInPictureController.isPictureInPictureSupported()
        isActive = false
    }

    private func observePossible(_ pictureInPictureController: AVPictureInPictureController) {
        possibleObservation = pictureInPictureController.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] controller, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isPossible = controller.isPictureInPicturePossible || (self.playerLayer == nil && AVPictureInPictureController.isPictureInPictureSupported())
                guard self.customStartPending, controller.isPictureInPicturePossible else { return }
                self.customStartPending = false
                self.customStartTimeout?.cancel()
                self.customStartTimeout = nil
                DiagnosticsLogger.shared.playback("PiP", "custom renderer source ready; starting")
                controller.startPictureInPicture()
            }
        }
    }

    private func startCustomRendererPictureInPicture() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            isPossible = false
            return
        }
        guard #available(iOS 15.0, *) else { return }
        guard controller == nil, restoreCustomRenderer == nil else { return }
        guard let window = activeKeyWindow() else {
            DiagnosticsLogger.shared.playback("PiP", "custom renderer start skipped reason=no-key-window")
            return
        }

        let contentController = PlayerCustomPiPContentViewController()
        let sourceView: UIView
        if let surface: MPVSurfaceUIView = findVisibleSubview(of: MPVSurfaceUIView.self, in: window), let layer = surface.takeDisplayLayerForPictureInPicture() {
            sourceView = surface
            contentController.host(layer: layer)
            restoreCustomRenderer = { [weak surface] in surface?.restoreDisplayLayerAfterPictureInPicture(layer) }
            DiagnosticsLogger.shared.playback("PiP", "custom renderer source=MPV")
        } else if let surface: KSAVIOSurfaceUIView = findVisibleSubview(of: KSAVIOSurfaceUIView.self, in: window), let playerView = surface.takePlayerViewForPictureInPicture() {
            sourceView = surface
            contentController.host(view: playerView)
            restoreCustomRenderer = { [weak surface] in surface?.restorePlayerViewAfterPictureInPicture(playerView) }
            DiagnosticsLogger.shared.playback("PiP", "custom renderer source=MDK")
        } else {
            DiagnosticsLogger.shared.playback("PiP", "custom renderer start skipped reason=no-supported-inline-surface")
            return
        }

        customContentController = contentController
        let contentSource = AVPictureInPictureController.ContentSource(activeVideoCallSourceView: sourceView, contentViewController: contentController)
        let pictureInPictureController = AVPictureInPictureController(contentSource: contentSource)
        pictureInPictureController.delegate = self
        pictureInPictureController.requiresLinearPlayback = false
        controller = pictureInPictureController
        customStartPending = true
        observePossible(pictureInPictureController)

        if pictureInPictureController.isPictureInPicturePossible {
            customStartPending = false
            pictureInPictureController.startPictureInPicture()
        } else {
            let workItem = DispatchWorkItem { [weak self, weak pictureInPictureController] in
                guard let self, self.customStartPending, self.controller === pictureInPictureController else { return }
                self.customStartPending = false
                DiagnosticsLogger.shared.playback("PiP", "custom renderer start timeout; restoring inline renderer")
                self.resetCustomControllerAndRestore(reason: "start-timeout")
            }
            customStartTimeout = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
        }
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
        restoreCustomRendererIfNeeded(reason: reason)
        isPossible = AVPictureInPictureController.isPictureInPictureSupported()
    }

    private func restoreCustomRendererIfNeeded(reason: String) {
        guard let restoreCustomRenderer else { return }
        self.restoreCustomRenderer = nil
        restoreCustomRenderer()
        customContentController = nil
        DiagnosticsLogger.shared.playback("PiP", "custom renderer restored reason=\(reason)")
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        customStartTimeout?.cancel()
        customStartTimeout = nil
        customStartPending = false
        isActive = true
        DiagnosticsLogger.shared.playback("PiP", "started customRenderer=\(restoreCustomRenderer != nil)")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isActive = false
        DiagnosticsLogger.shared.playback("PiP", "stopped customRenderer=\(restoreCustomRenderer != nil)")
        if restoreCustomRenderer != nil { resetCustomControllerAndRestore(reason: "stopped") }
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        isActive = false
        DiagnosticsLogger.shared.playback("PiP", "start failed error=\(error.localizedDescription) customRenderer=\(restoreCustomRenderer != nil)")
        if restoreCustomRenderer != nil { resetCustomControllerAndRestore(reason: "start-failed") }
    }
}

@available(iOS 15.0, *)
private final class PlayerCustomPiPContentViewController: AVPictureInPictureVideoCallViewController {
    private var hostedView: UIView?
    private var hostedLayer: CALayer?

    override func loadView() {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        view.clipsToBounds = true
        self.view = view
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
        hostedLayer.contentsScale = UIScreen.main.nativeScale
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
