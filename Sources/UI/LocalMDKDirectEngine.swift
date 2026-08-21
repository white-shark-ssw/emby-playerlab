import Foundation
import MetalKit
import UIKit

#if MDK_LAB && canImport(swift_mdk)
import swift_mdk

final class LocalMDKDirectEngine: NSObject, PlayerEngine, MTKViewDelegate, @unchecked Sendable {
    let kind: PlayerEngineKind = .ksAVIO
    var onSnapshot: ((PlayerSnapshot) -> Void)?
    var onSeekCompleted: ((SeekResult) -> Void)?

    let playerView: MTKView

    private let commandQueue: MTLCommandQueue
    private var player: swift_mdk.Player?
    private var stateTimer: Timer?
    private var lastURL: URL?
    private var shouldPlay = false
    private var firstFrameLogged = false
    private var inputTraceSession = "unassigned"
    private var inputTraceLastSecond = -1
    private var inputTraceRenderCalls: UInt64 = 0
    private var inputTraceLastRenderResult: Double?
    private var inputTraceLastPosition: Double = 0
    private var inputTraceLastStatus: Int32 = 0

    override init() {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { fatalError("Metal is unavailable") }
        commandQueue = queue
        playerView = MTKView(frame: .zero, device: device)
        super.init()
        playerView.backgroundColor = .black
        playerView.clearColor = MTLClearColorMake(0, 0, 0, 1)
        playerView.colorPixelFormat = .bgra8Unorm
        playerView.framebufferOnly = false
        playerView.isPaused = true
        playerView.enableSetNeedsDisplay = true
        playerView.preferredFramesPerSecond = 60
        playerView.delegate = self
    }

    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double) {
        stopPlayerOnly()
        lastURL = url
        firstFrameLogged = false
        inputTraceSession = String(UUID().uuidString.prefix(8)).lowercased()
        inputTraceLastSecond = -1
        inputTraceRenderCalls = 0
        inputTraceLastRenderResult = nil
        inputTraceLastPosition = max(0, startPosition)
        inputTraceLastStatus = 0
        DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\(inputTraceSession) source=file event=open start=\(String(format: "%.3f", startPosition)) scheme=\(url.scheme ?? "nil") name=\(url.lastPathComponent)")
        let player = swift_mdk.Player()
        self.player = player
        player.videoDecoders = ["VT", "FFmpeg"]
        player.setBufferRange(msMin: 1_000, msMax: Int64(max(3_000, min(30_000, preferredForwardBuffer * 1_000))), drop: false)
        player.setProperty(name: "keep_open", value: "1")
        player.setRenderTarget(playerView, commandQueue: commandQueue, vid: playerView)
        let size = playerView.drawableSize
        player.setVideoSurfaceSize(Int32(max(1, size.width)), Int32(max(1, size.height)), vid: playerView)
        player.setRenderCallback { [weak self] in
            DispatchQueue.main.async { [weak self] in self?.playerView.setNeedsDisplay() }
        }
        player.onMediaStatusChanged { [weak self, weak player] status in
            DispatchQueue.main.async { [weak self, weak player] in
                guard let self, let player, self.player === player else { return }
                self.inputTraceLastStatus = status.rawValue
                DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\(self.inputTraceSession) source=file event=status position=\(String(format: "%.3f", self.inputTraceLastPosition)) raw=0x\(String(status.rawValue, radix: 16)) renderCalls=\(self.inputTraceRenderCalls) renderValue=\(self.inputTraceLastRenderResult.map { String(format: "%.6f", $0) } ?? "nil")")
            }
            return true
        }
        player.media = url.absoluteString
        DiagnosticsLogger.shared.playback("LocalMDKDirect", "event=prepare path=file renderer=MTKView-direct mdkVersion=\(swift_mdk.version()) start=\(String(format: "%.3f", startPosition)) drawable=\(Int(size.width))x\(Int(size.height))")
        player.prepare(from: Int64(max(0, startPosition) * 1_000), complete: { [weak self, weak player] preparedAtMs, boost in
            boost = true
            guard let self, let player, self.player === player else { return false }
            DiagnosticsLogger.shared.playback("LocalMDKDirect", "event=prepared actualMs=\(preparedAtMs) renderer=MTKView-direct")
            DispatchQueue.main.async { [weak self, weak player] in
                guard let self, let player, self.player === player else { return }
                self.startStateTimer()
                if self.shouldPlay { player.state = .Playing }
                self.playerView.setNeedsDisplay()
            }
            return true
        })
    }

    func play() {
        shouldPlay = true
        player?.state = .Playing
    }

    func pause() {
        shouldPlay = false
        player?.state = .Paused
    }

    func setPlaybackRate(_ rate: Double) { player?.playbackRate = Float(min(8, max(0.15, rate))) }

    func seek(to seconds: Double, direction: SeekDirection) {
        guard let player else { return }
        let target = max(0, seconds)
        let requestedAt = Date().timeIntervalSince1970
        let immediate = player.seek(Int64(target * 1_000), flags: .Default) { [weak self, weak player] actualMs in
            guard let self, let player, self.player === player else { return }
            let completedAt = Date().timeIntervalSince1970
            let actual = actualMs >= 0 ? Double(actualMs) / 1_000 : nil
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onSeekCompleted?(SeekResult(requestedAt: requestedAt, target: target, actualPosition: actual, bufferHit: false, completionLatencyMs: (completedAt - requestedAt) * 1_000, measurement: "mdk-mtkview-direct"))
                self.playerView.setNeedsDisplay()
            }
        }
        DiagnosticsLogger.shared.playback("LocalMDKDirect", "event=seek target=\(String(format: "%.3f", target)) immediate=\(immediate) direction=\(String(describing: direction))")
    }

    func reload(at seconds: Double) {
        guard let lastURL else { return }
        let resume = shouldPlay
        prepare(url: lastURL, headers: [:], preferredForwardBuffer: 0, startPosition: seconds)
        if resume { play() }
    }

    func stop() {
        shouldPlay = false
        stopPlayerOnly()
        onSnapshot = nil
        onSeekCompleted = nil
    }

    private func stopPlayerOnly() {
        if inputTraceSession != "unassigned" { DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\(inputTraceSession) source=file event=stop position=\(String(format: "%.3f", inputTraceLastPosition)) raw=0x\(String(inputTraceLastStatus, radix: 16)) renderCalls=\(inputTraceRenderCalls) renderValue=\(inputTraceLastRenderResult.map { String(format: "%.6f", $0) } ?? "nil")") }
        stateTimer?.invalidate()
        stateTimer = nil
        if let player {
            player.setRenderCallback(nil)
            player.state = .Stopped
        }
        player = nil
    }

    private func startStateTimer() {
        stateTimer?.invalidate()
        stateTimer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { [weak self] _ in self?.pollState() }
        if let stateTimer { RunLoop.main.add(stateTimer, forMode: .common) }
    }

    private func pollState() {
        guard let player else { return }
        let position = Double(player.position) / 1_000
        let duration = Double(player.mediaInfo.duration) / 1_000
        let isPlaying = player.state == .Playing
        let status = player.mediaStatus.rawValue
        inputTraceLastPosition = position
        inputTraceLastStatus = status
        let traceSecond = Int(max(0, position).rounded(.down))
        if traceSecond != inputTraceLastSecond {
            inputTraceLastSecond = traceSecond
            DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\(inputTraceSession) source=file event=progress position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) raw=0x\(String(status, radix: 16)) playing=\(isPlaying) bufferMs=\(player.buffered()) renderCalls=\(inputTraceRenderCalls) renderValue=\(inputTraceLastRenderResult.map { String(format: "%.6f", $0) } ?? "nil")")
        }
        let buffered = Double(max(0, player.buffered())) / 1_000
        let bufferedEnd = duration > 0 ? min(duration, position + buffered) : position + buffered
        onSnapshot?(PlayerSnapshot(position: position, duration: duration, bufferedRanges: bufferedEnd > position ? [position...bufferedEnd] : [], isPlaying: isPlaying, isBuffering: false, errorMessage: nil, didReachEnd: false))
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        guard let player else { return }
        player.setVideoSurfaceSize(Int32(max(1, size.width)), Int32(max(1, size.height)), vid: view)
        DiagnosticsLogger.shared.playback("LocalMDKDirect", "event=surface-size renderer=MTKView-direct drawable=\(Int(size.width))x\(Int(size.height))")
    }

    func draw(in view: MTKView) {
        guard let player else { return }
        let result = player.renderVideo(vid: view)
        inputTraceRenderCalls &+= 1
        inputTraceLastRenderResult = result
        if inputTraceRenderCalls == 1 || inputTraceRenderCalls % 30 == 0 { DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\(inputTraceSession) source=file event=render renderCalls=\(inputTraceRenderCalls) position=\(String(format: "%.3f", inputTraceLastPosition)) renderValue=\(String(format: "%.6f", result))") }
        if !firstFrameLogged {
            firstFrameLogged = true
            let size = view.drawableSize
            DiagnosticsLogger.shared.playback("LocalMDKDirect", "event=first-render renderer=MTKView-direct result=\(String(format: "%.3f", result)) drawable=\(Int(size.width))x\(Int(size.height)) hasDrawable=\(view.currentDrawable != nil)")
        }
    }
}
#endif
