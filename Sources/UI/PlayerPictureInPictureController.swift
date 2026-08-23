import AVFoundation
import AVKit
import Combine
import CoreMedia
import UIKit

@MainActor
final class PlayerPictureInPictureController: NSObject, ObservableObject, @preconcurrency AVPictureInPictureControllerDelegate, @preconcurrency AVPictureInPictureSampleBufferPlaybackDelegate {
    @Published private(set) var isPossible = AVPictureInPictureController.isPictureInPictureSupported()
    @Published private(set) var isActive = false

    private weak var playbackController: PlayerController?
    private var activeSession: UnifiedMediaTransportSession?
    private var controller: AVPictureInPictureController?
    private var possibleObservation: NSKeyValueObservation?
    private var displayLayer: AVSampleBufferDisplayLayer?
    private var sourceHostView: PlayerSampleBufferPiPSourceHostView?
    private var bridge: PlayerSampleBufferPiPBridge?
    private var controlTimebase: CMTimebase?
    private var startPending = false
    private var startTimeout: DispatchWorkItem?
    private var startPoll: DispatchWorkItem?
    private var firstSampleEnqueued = false

    func attach(playerLayer: AVPlayerLayer) {
        _ = playerLayer
        DiagnosticsLogger.shared.playback("PiP", "AVPlayerLayer attach ignored policy=samplebuffer-only")
    }

    func toggle(using playbackController: PlayerController) {
        if controller?.isPictureInPictureActive == true {
            controller?.stopPictureInPicture()
            return
        }
        if startPending {
            DiagnosticsLogger.shared.playback("PiP", "samplebuffer start cancelled by second tap")
            reset(reason: "user-cancelled")
            return
        }
        startSampleBufferPictureInPicture(using: playbackController)
    }

    func stopAndDetach() {
        if controller?.isPictureInPictureActive == true { controller?.stopPictureInPicture() }
        reset(reason: "detach")
    }

    private func startSampleBufferPictureInPicture(using playbackController: PlayerController) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { isPossible = false; return }
        guard let session = PlaybackTransportSessionRegistry.shared.session(itemId: playbackController.source.itemId) else {
            DiagnosticsLogger.shared.playback("PiP", "samplebuffer start skipped reason=no-active-unified-session item=\(playbackController.source.itemId)")
            return
        }
        guard let sourceView = visiblePlaybackSurface() else {
            DiagnosticsLogger.shared.playback("PiP", "samplebuffer start skipped reason=no-visible-playback-surface")
            return
        }

        reset(reason: "prepare-new")
        self.playbackController = playbackController
        activeSession = session

        let host = PlayerSampleBufferPiPSourceHostView(frame: sourceView.frame)
        host.autoresizingMask = sourceView.autoresizingMask
        if let parent = sourceView.superview { parent.insertSubview(host, belowSubview: sourceView) }
        else { sourceView.addSubview(host) }
        sourceHostView = host

        let layer = host.displayLayer
        layer.videoGravity = .resizeAspect
        var timebase: CMTimebase?
        let timebaseStatus = CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        guard timebaseStatus == noErr, let timebase else {
            DiagnosticsLogger.shared.playback("PiP", "samplebuffer start failed reason=timebase status=\(timebaseStatus)")
            reset(reason: "timebase-failed")
            return
        }
        let position = max(0, playbackController.snapshot.position)
        CMTimebaseSetTime(timebase, time: CMTime(seconds: position, preferredTimescale: 60000))
        CMTimebaseSetRate(timebase, rate: playbackController.playbackControlIsPlaying ? 1 : 0)
        layer.controlTimebase = timebase
        controlTimebase = timebase
        displayLayer = layer

        let contentSource = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: layer, playbackDelegate: self)
        let pictureInPictureController = AVPictureInPictureController(contentSource: contentSource)
        pictureInPictureController.delegate = self
        pictureInPictureController.requiresLinearPlayback = false
        controller = pictureInPictureController
        observePossible(pictureInPictureController)

        startPending = true
        firstSampleEnqueued = false
        startBridge(session: session, at: position)
        scheduleStartTimeout()
        DiagnosticsLogger.shared.playback("PiP", "samplebuffer prepared engine=\(playbackController.engineKind.title) position=\(String(format: "%.3f", position)) possible=\(pictureInPictureController.isPictureInPicturePossible) source=\(Int(sourceView.bounds.width))x\(Int(sourceView.bounds.height)) avplayer=false")
    }

    private func startBridge(session: UnifiedMediaTransportSession, at position: Double) {
        bridge?.stop()
        let bridge = PlayerSampleBufferPiPBridge(session: session, startPosition: position)
        self.bridge = bridge
        bridge.onReady = { info in DispatchQueue.main.async { DiagnosticsLogger.shared.playback("PiP", "samplebuffer demux ready \(info)") } }
        bridge.onFailure = { [weak self] reason in
            DispatchQueue.main.async {
                guard let self else { return }
                DiagnosticsLogger.shared.playback("PiP", "samplebuffer demux failed reason=\(reason)")
                if !self.isActive { self.reset(reason: "demux-failed") }
            }
        }
        bridge.onSample = { [weak self] envelope in DispatchQueue.main.async { self?.enqueue(envelope) } }
        bridge.setPaused(!(playbackController?.playbackControlIsPlaying ?? true))
        bridge.start()
    }

    private func enqueue(_ envelope: PlayerSampleBufferPiPBridge.SampleEnvelope) {
        guard let displayLayer, displayLayer.status != .failed else {
            if let error = displayLayer?.error { DiagnosticsLogger.shared.playback("PiP", "samplebuffer layer failed error=\(error.localizedDescription)") }
            if !isActive { reset(reason: "display-layer-failed") }
            return
        }
        displayLayer.enqueue(envelope.buffer)
        if !firstSampleEnqueued {
            firstSampleEnqueued = true
            DiagnosticsLogger.shared.playback("PiP", "samplebuffer first sample enqueued pts=\(String(format: "%.3f", envelope.pts)) key=\(envelope.keyframe)")
            pollStart(attempt: 0)
        }
    }

    private func observePossible(_ pictureInPictureController: AVPictureInPictureController) {
        possibleObservation = pictureInPictureController.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] controller, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isPossible = controller.isPictureInPicturePossible || AVPictureInPictureController.isPictureInPictureSupported()
                DiagnosticsLogger.shared.playback("PiP", "samplebuffer possible=\(controller.isPictureInPicturePossible) ready=\(self.displayLayer?.isReadyForDisplay ?? false) first=\(self.firstSampleEnqueued)")
                self.startIfReady()
            }
        }
    }

    private func pollStart(attempt: Int) {
        startPoll?.cancel()
        guard startPending else { return }
        startIfReady()
        guard startPending, attempt < 80 else { return }
        let work = DispatchWorkItem { [weak self] in self?.pollStart(attempt: attempt + 1) }
        startPoll = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    private func startIfReady() {
        guard startPending, firstSampleEnqueued, let controller, let displayLayer else { return }
        guard controller.isPictureInPicturePossible, displayLayer.isReadyForDisplay else { return }
        startPending = false
        startTimeout?.cancel(); startTimeout = nil
        startPoll?.cancel(); startPoll = nil
        DiagnosticsLogger.shared.playback("PiP", "samplebuffer source ready; startPictureInPicture possible=true layerReady=true avplayer=false")
        controller.startPictureInPicture()
    }

    private func scheduleStartTimeout() {
        startTimeout?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.startPending else { return }
            DiagnosticsLogger.shared.playback("PiP", "samplebuffer start timeout possible=\(self.controller?.isPictureInPicturePossible ?? false) layerReady=\(self.displayLayer?.isReadyForDisplay ?? false) first=\(self.firstSampleEnqueued) status=\(self.displayLayer?.status.rawValue ?? -1)")
            self.reset(reason: "start-timeout")
        }
        startTimeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: work)
    }

    private func visiblePlaybackSurface() -> UIView? {
        guard let window = activeKeyWindow() else { return nil }
        if let surface: MPVSurfaceUIView = findVisibleSubview(of: MPVSurfaceUIView.self, in: window) { return surface }
        if let surface: KSAVIOSurfaceUIView = findVisibleSubview(of: KSAVIOSurfaceUIView.self, in: window) { return surface }
        if let surface: PlayerSurfaceUIView = findVisibleSubview(of: PlayerSurfaceUIView.self, in: window) { return surface }
        return nil
    }

    private func activeKeyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first(where: { $0.activationState == .foregroundInactive })
        return scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first(where: { !$0.isHidden })
    }

    private func findVisibleSubview<T: UIView>(of type: T.Type, in root: UIView) -> T? {
        if let match = root as? T, match.window != nil, !match.isHidden, match.alpha > 0.01, match.bounds.width > 1, match.bounds.height > 1 { return match }
        for child in root.subviews { if let match: T = findVisibleSubview(of: type, in: child) { return match } }
        return nil
    }

    private func restartBridge(at position: Double) {
        guard let session = activeSession, let displayLayer, let timebase = controlTimebase else { return }
        displayLayer.flushAndRemoveImage()
        CMTimebaseSetTime(timebase, time: CMTime(seconds: max(0, position), preferredTimescale: 60000))
        CMTimebaseSetRate(timebase, rate: playbackController?.playbackControlIsPlaying == true ? 1 : 0)
        firstSampleEnqueued = false
        startBridge(session: session, at: position)
        DiagnosticsLogger.shared.playback("PiP", "samplebuffer bridge restart position=\(String(format: "%.3f", position))")
    }

    private func reset(reason: String) {
        startTimeout?.cancel(); startTimeout = nil
        startPoll?.cancel(); startPoll = nil
        startPending = false
        possibleObservation = nil
        bridge?.stop(); bridge = nil
        displayLayer?.flushAndRemoveImage()
        displayLayer?.controlTimebase = nil
        displayLayer = nil
        controlTimebase = nil
        sourceHostView?.removeFromSuperview(); sourceHostView = nil
        controller?.delegate = nil
        controller = nil
        activeSession = nil
        playbackController = nil
        firstSampleEnqueued = false
        isActive = false
        isPossible = AVPictureInPictureController.isPictureInPictureSupported()
        DiagnosticsLogger.shared.playback("PiP", "samplebuffer reset reason=\(reason)")
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isActive = true
        DiagnosticsLogger.shared.playback("PiP", "started samplebuffer=true avplayer=false engine=\(playbackController?.engineKind.title ?? "unknown")")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DiagnosticsLogger.shared.playback("PiP", "stopped samplebuffer=true position=\(String(format: "%.3f", playbackController?.snapshot.position ?? 0))")
        reset(reason: "stopped")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        DiagnosticsLogger.shared.playback("PiP", "start failed samplebuffer=true error=\(error.localizedDescription)")
        reset(reason: "start-failed")
    }

    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        guard let playbackController else { return .invalid }
        return CMTimeRange(start: .zero, duration: CMTime(seconds: max(0.001, playbackController.effectiveDuration), preferredTimescale: 60000))
    }

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool { !(playbackController?.playbackControlIsPlaying ?? false) }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        guard let playbackController else { return }
        if playbackController.playbackControlIsPlaying != playing { playbackController.togglePlayPause() }
        bridge?.setPaused(!playing)
        if let timebase = controlTimebase { CMTimebaseSetTime(timebase, time: CMTime(seconds: playbackController.snapshot.position, preferredTimescale: 60000)); CMTimebaseSetRate(timebase, rate: playing ? 1 : 0) }
        pictureInPictureController.invalidatePlaybackState()
        DiagnosticsLogger.shared.playback("PiP", "samplebuffer setPlaying=\(playing) engine=\(playbackController.engineKind.title)")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        DiagnosticsLogger.shared.playback("PiP", "samplebuffer renderSize=\(newRenderSize.width)x\(newRenderSize.height)")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping @Sendable () -> Void) {
        guard let playbackController else { completionHandler(); return }
        let delta = CMTimeGetSeconds(skipInterval)
        guard delta.isFinite else { completionHandler(); return }
        let target = min(max(0, playbackController.snapshot.position + delta), max(playbackController.effectiveDuration, 0))
        playbackController.seek(by: delta)
        restartBridge(at: target)
        pictureInPictureController.invalidatePlaybackState()
        DiagnosticsLogger.shared.playback("PiP", "samplebuffer skip delta=\(String(format: "%.3f", delta)) target=\(String(format: "%.3f", target))")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: completionHandler)
    }

    func pictureInPictureControllerShouldProhibitBackgroundAudioPlayback(_ pictureInPictureController: AVPictureInPictureController) -> Bool { false }
}

private final class PlayerSampleBufferPiPSourceHostView: UIView {
    let displayLayer = AVSampleBufferDisplayLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isUserInteractionEnabled = false
        clipsToBounds = true
        layer.addSublayer(displayLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin(); CATransaction.setDisableActions(true); displayLayer.frame = bounds; displayLayer.contentsScale = window?.screen.nativeScale ?? UIScreen.main.nativeScale; CATransaction.commit()
    }
}
