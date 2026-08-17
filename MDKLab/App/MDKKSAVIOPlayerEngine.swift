#if MDK_LAB && canImport(swift_mdk)
import Foundation
import MetalKit
import QuartzCore
import UIKit
import swift_mdk

private final class MDKRenderView: MTKView, MTKViewDelegate {
    weak var player: swift_mdk.Player?
    var onSurfaceChanged: ((CGSize) -> Void)?
    var onFrameSubmitted: ((Double) -> Void)?
    private let commandQueue: MTLCommandQueue

    init() {
        guard let device = MTLCreateSystemDefaultDevice(), let commandQueue = device.makeCommandQueue() else { fatalError("Metal is unavailable") }
        self.commandQueue = commandQueue
        super.init(frame: .zero, device: device)
        delegate = self
        autoResizeDrawable = true
        enableSetNeedsDisplay = true
        isPaused = true
        preferredFramesPerSecond = UIScreen.main.maximumFramesPerSecond
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(_ player: swift_mdk.Player) {
        self.player = player
        player.addRenderTarget(self, commandQueue: commandQueue)
        let size = drawableSize
        player.setRenderCallback { [weak self, weak player] in
            DispatchQueue.main.async { [weak self, weak player] in
                guard let self, let player, self.player === player else { return }
                self.setNeedsDisplay()
            }
        }
        onSurfaceChanged?(size)
    }

    func unbind(_ player: swift_mdk.Player) {
        guard self.player === player else { return }
        player.setRenderCallback(nil)
        player.setVideoSurfaceSize(Int32(-1), Int32(-1), vid: self)
        self.player = nil
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        player?.setVideoSurfaceSize(Int32(size.width), Int32(size.height), vid: self)
        onSurfaceChanged?(size)
    }

    func draw(in view: MTKView) {
        guard let player else { return }
        let renderResult = player.renderVideo(vid: self)
        guard let drawable = currentDrawable, let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        commandBuffer.present(drawable)
        commandBuffer.commit()
        onFrameSubmitted?(renderResult)
    }
}

final class KSAVIOPlayerEngine: PlayerEngine {
    let kind: PlayerEngineKind = .ksAVIO
    var onSnapshot: ((PlayerSnapshot) -> Void)?
    var onSeekCompleted: ((SeekResult) -> Void)?

    private let source: ResolvedPlaybackSource
    private let sharedTransportSession: TransportDataSession?
    private let view = MDKRenderView()
    private var player: swift_mdk.Player?
    private var stateTimer: Timer?
    private var transportStopTask: Task<Void, Never>?
    private var lastURL: URL?
    private var lastHeaders: [String: String] = [:]
    private var preferredForwardBuffer: Double = 90
    private var shouldPlay = false
    private var playbackRate: Double = 1
    private var rateGeneration = 0
    private var generation = 0
    private var firstRenderedGeneration = -1
    private var pendingSeekResume: (target: Double, requestedAt: TimeInterval, callbackAt: TimeInterval?)?
    private var didInstallLogHandler = false

    var playerView: UIView? { view }

    init(source: ResolvedPlaybackSource, client: EmbyAPIClient, configuration: MediaTransportConfiguration, sharedTransportSession: TransportDataSession? = nil, ktvCacheSession: KTVCachePlaybackSession? = nil) {
        self.source = source
        self.sharedTransportSession = sharedTransportSession
        view.backgroundColor = .black
        view.isOpaque = true
        view.isUserInteractionEnabled = false
        view.onSurfaceChanged = { size in
            DiagnosticsLogger.shared.playback("MDKSurface", "size=\(Int(size.width))x\(Int(size.height)) backend=MTKView")
        }
        view.onFrameSubmitted = { [weak self] renderResult in self?.recordFirstRenderedFrame(renderResult) }
        _ = client
        _ = configuration
        _ = ktvCacheSession
    }

    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double) {
        stopPlayerOnly()
        generation &+= 1
        let currentGeneration = generation
        self.preferredForwardBuffer = preferredForwardBuffer
        lastURL = url
        lastHeaders = headers
        pendingSeekResume = nil
        installMDKLoggingIfNeeded()

        let player = swift_mdk.Player()
        self.player = player
        player.videoDecoders = ["VT", "FFmpeg"]
        player.playbackRate = Float(playbackRate)
        player.setBufferRange(msMin: 1_000, msMax: Int64(max(3_000, min(30_000, preferredForwardBuffer * 1_000))), drop: false)
        applyHTTPHeaders(headers, to: player)
        attachCallbacks(to: player, generation: currentGeneration)
        view.bind(player)
        player.media = url.absoluteString
        player.prepare(from: milliseconds(startPosition), complete: { [weak self, weak player] preparedAtMs, boost in
            guard let self, let player, currentGeneration == self.generation, self.player === player else { return false }
            boost = true
            DispatchQueue.main.async { [weak self, weak player] in
                guard let self, let player, currentGeneration == self.generation, self.player === player else { return }
                if self.shouldPlay { player.state = .Playing }
            }
            DiagnosticsLogger.shared.playback("MDKPrepare", "preparedAtMs=\(preparedAtMs) requestedStart=\(String(format: "%.3f", startPosition)) sourceFPS=\(self.sourceFrameRateText) videoDecoders=VT,FFmpeg directHTTP302=true")
            return true
        })
        startStateTimer()
        stopUnusedUnifiedTransportAfterDirectStart()
        DiagnosticsLogger.shared.playback("MDK", "prepare item=\(source.itemId) version=\(swift_mdk.version()) directHTTP302=true sharedTransport=disabled-after-start headers=\(headers.keys.sorted().joined(separator: ",")) rate=\(String(format: "%.2f", playbackRate))")
    }

    func play() {
        shouldPlay = true
        player?.state = .Playing
    }

    func pause() {
        shouldPlay = false
        player?.state = .Paused
    }

    func setPlaybackRate(_ rate: Double) {
        let clamped = min(8, max(0.15, rate))
        playbackRate = clamped
        rateGeneration &+= 1
        let currentRateGeneration = rateGeneration
        guard let player else {
            DiagnosticsLogger.shared.playback("MDKRate", "requested=\(String(format: "%.2f", clamped)) state=pending-player")
            return
        }
        let startPosition = seconds(player.position)
        let startedAt = CACurrentMediaTime()
        player.playbackRate = Float(clamped)
        DiagnosticsLogger.shared.playback("MDKRate", "requested=\(String(format: "%.2f", clamped)) applied=\(String(format: "%.2f", Double(player.playbackRate))) sourceFPS=\(sourceFrameRateText) decoder=VT")
        guard player.state == .Playing else { return }
        scheduleRateHealth(player: player, generation: currentRateGeneration, requested: clamped, startedAt: startedAt, startPosition: startPosition, delay: 1.5)
        scheduleRateHealth(player: player, generation: currentRateGeneration, requested: clamped, startedAt: startedAt, startPosition: startPosition, delay: 4.0)
    }

    func seek(to targetSeconds: Double, direction: SeekDirection) {
        guard let player else { return }
        let target = max(0, targetSeconds)
        let requestedAt = Date().timeIntervalSince1970
        pendingSeekResume = (target, requestedAt, nil)
        let accepted = player.seek(milliseconds(target), flags: .Default) { [weak self, weak player] actualMs in
            guard let self else { return }
            let callbackAt = Date().timeIntervalSince1970
            let actual = actualMs >= 0 ? self.seconds(actualMs) : player.map { self.seconds($0.position) }
            let latency = (callbackAt - requestedAt) * 1_000
            if var pending = self.pendingSeekResume, abs(pending.target - target) < 0.001 { pending.callbackAt = callbackAt; self.pendingSeekResume = pending }
            self.onSeekCompleted?(SeekResult(requestedAt: requestedAt, target: target, actualPosition: actual, bufferHit: latency < 150, completionLatencyMs: latency, measurement: "MDK seek callback"))
            DiagnosticsLogger.shared.playback("MDKSeek", "target=\(String(format: "%.3f", target)) callbackMs=\(String(format: "%.1f", latency)) actual=\(actual.map { String(format: "%.3f", $0) } ?? "nil") accepted=true direction=\(String(describing: direction))")
            if self.shouldPlay, player?.state != .Playing { player?.state = .Playing }
        }
        if !accepted {
            pendingSeekResume = nil
            onSeekCompleted?(SeekResult(requestedAt: requestedAt, target: target, actualPosition: self.seconds(player.position), bufferHit: false, completionLatencyMs: 0, measurement: "MDK seek rejected"))
            DiagnosticsLogger.shared.playback("MDKSeek", "target=\(String(format: "%.3f", target)) accepted=false direction=\(String(describing: direction))")
        }
    }

    func reload(at seconds: Double) {
        guard let url = lastURL else { return }
        let resume = shouldPlay
        prepare(url: url, headers: lastHeaders, preferredForwardBuffer: preferredForwardBuffer, startPosition: seconds)
        if resume { play() }
    }

    func recoverStall(position: Double, duration: Double) {
        guard let player else { return }
        DiagnosticsLogger.shared.playback("MDKRecovery", "position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) state=\(String(describing: player.state)) status=0x\(String(player.mediaStatus.rawValue, radix: 16)) action=play")
        if shouldPlay { player.state = .Playing }
    }

    func stop() {
        shouldPlay = false
        generation &+= 1
        rateGeneration &+= 1
        stopPlayerOnly()
        onSnapshot = nil
        onSeekCompleted = nil
    }

    private func attachCallbacks(to player: swift_mdk.Player, generation: Int) {
        player.onStateChanged { [weak self, weak player] state in
            DispatchQueue.main.async { [weak self, weak player] in
                guard let self, let player, generation == self.generation, self.player === player else { return }
                DiagnosticsLogger.shared.playback("MDKState", "state=\(String(describing: state)) position=\(String(format: "%.3f", self.seconds(player.position)))")
            }
        }
        player.onMediaStatusChanged { [weak self, weak player] status in
            DispatchQueue.main.async { [weak self, weak player] in
                guard let self, let player, generation == self.generation, self.player === player else { return }
                DiagnosticsLogger.shared.playback("MDKStatus", "raw=0x\(String(status.rawValue, radix: 16)) position=\(String(format: "%.3f", self.seconds(player.position)))")
                if self.shouldPlay, self.isPrepared(status.rawValue), player.state != .Playing { player.state = .Playing }
            }
            return true
        }
    }

    private func startStateTimer() {
        stateTimer?.invalidate()
        stateTimer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { [weak self] _ in self?.pollState() }
        if let stateTimer { RunLoop.main.add(stateTimer, forMode: .common) }
    }

    private func pollState() {
        guard let player else { return }
        let position = seconds(player.position)
        let info = player.mediaInfo
        let duration = max(seconds(info.duration), source.mediaSource.durationSeconds ?? 0)
        let status = player.mediaStatus.rawValue
        let buffering = hasStatus(status, bit: 3) || hasStatus(status, bit: 4)
        let ended = hasStatus(status, bit: 6)
        let isPlaying = player.state == .Playing && !ended
        let forwardBuffered = seconds(player.buffered())
        let bufferedEnd = duration > 0 ? min(duration, position + forwardBuffered) : position + forwardBuffered
        onSnapshot?(PlayerSnapshot(position: position, duration: duration, bufferedRanges: bufferedEnd > position ? [position...bufferedEnd] : [], isPlaying: isPlaying, isBuffering: buffering, waitingReason: buffering ? "MDK 等待媒体数据" : nil, errorMessage: hasStatus(status, bit: 31) ? "MDK media status invalid" : nil, didReachEnd: ended))

        if let pending = pendingSeekResume, position > pending.target + 0.08 {
            let now = Date().timeIntervalSince1970
            let resumeMs = (now - pending.requestedAt) * 1_000
            let afterCallbackMs = pending.callbackAt.map { (now - $0) * 1_000 }
            DiagnosticsLogger.shared.playback("MDKSeekHealth", "target=\(String(format: "%.3f", pending.target)) firstAdvance=\(String(format: "%.3f", position)) resumeMs=\(String(format: "%.1f", resumeMs)) afterCallbackMs=\(afterCallbackMs.map { String(format: "%.1f", $0) } ?? "pending") playing=\(isPlaying) buffering=\(buffering) bufferMs=\(player.buffered())")
            pendingSeekResume = nil
        }
    }

    private func scheduleRateHealth(player: swift_mdk.Player, generation: Int, requested: Double, startedAt: TimeInterval, startPosition: Double, delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak player] in
            guard let self, let player, self.rateGeneration == generation, self.player === player else { return }
            let elapsed = max(0.001, CACurrentMediaTime() - startedAt)
            let currentPosition = self.seconds(player.position)
            let actualRate = max(0, (currentPosition - startPosition) / elapsed)
            DiagnosticsLogger.shared.playback("MDKRateHealth", "requested=\(String(format: "%.2f", requested)) actual=\(String(format: "%.2f", actualRate)) sample=\(String(format: "%.1f", elapsed))s position=\(String(format: "%.3f", currentPosition)) status=0x\(String(player.mediaStatus.rawValue, radix: 16)) state=\(String(describing: player.state)) sourceFPS=\(self.sourceFrameRateText) decoder=VT")
        }
    }

    private func recordFirstRenderedFrame(_ renderResult: Double) {
        guard firstRenderedGeneration != generation else { return }
        firstRenderedGeneration = generation
        DiagnosticsLogger.shared.playback("MDKFrame", "firstFrameSubmitted generation=\(generation) renderResult=\(renderResult) drawable=\(Int(view.drawableSize.width))x\(Int(view.drawableSize.height))")
    }

    private func applyHTTPHeaders(_ headers: [String: String], to player: swift_mdk.Player) {
        guard !headers.isEmpty else { return }
        let value = headers.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }.map { "\($0.key): \($0.value)" }.joined(separator: "\r\n") + "\r\n"
        player.setProperty(name: "avio.headers", value: value)
        player.setProperty(name: "avformat.headers", value: value)
    }

    private func stopUnusedUnifiedTransportAfterDirectStart() {
        transportStopTask?.cancel()
        guard let sharedTransportSession else { return }
        transportStopTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await sharedTransportSession.stop()
            DiagnosticsLogger.shared.playback("MDKTransport", "mode=directHTTP302 unifiedTransportStopped=true nasMediaProxy=false")
        }
    }

    private func installMDKLoggingIfNeeded() {
        guard !didInstallLogHandler else { return }
        didInstallLogHandler = true
        swift_mdk.logLevel = .Info
        swift_mdk.setLogHandler { level, message in
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            DiagnosticsLogger.shared.playback("MDKNative", "level=\(String(describing: level)) \(trimmed)")
        }
    }

    private var sourceFrameRateText: String {
        let video = source.mediaSource.mediaStreams?.first(where: { $0.type?.caseInsensitiveCompare("Video") == .orderedSame })
        let fps = video?.averageFrameRate ?? video?.realFrameRate
        return fps.map { String(format: "%.3f", $0) } ?? "unknown"
    }

    private func hasStatus(_ raw: Int32, bit: Int32) -> Bool { UInt32(bitPattern: raw) & (UInt32(1) << UInt32(bit)) != 0 }
    private func isPrepared(_ raw: Int32) -> Bool { hasStatus(raw, bit: 2) || hasStatus(raw, bit: 8) }
    private func seconds(_ milliseconds: Int64) -> Double { max(0, Double(milliseconds) / 1_000) }
    private func milliseconds(_ seconds: Double) -> Int64 { Int64((max(0, seconds) * 1_000).rounded()) }

    private func stopPlayerOnly() {
        stateTimer?.invalidate()
        stateTimer = nil
        transportStopTask?.cancel()
        transportStopTask = nil
        pendingSeekResume = nil
        if let player {
            player.onStateChanged(callback: nil)
            player.onMediaStatusChanged(callback: nil)
            player.state = .Stopped
            view.unbind(player)
        }
        player = nil
    }
}
#endif