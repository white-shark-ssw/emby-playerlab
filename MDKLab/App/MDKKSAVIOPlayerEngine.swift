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
        if size.width > 0, size.height > 0 { player.setVideoSurfaceSize(Int32(size.width), Int32(size.height), vid: self) }
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
    private struct PendingSeekResume {
        let id: Int
        let target: Double
        let requestedAt: TimeInterval
        var callbackAt: TimeInterval?
        var didLogBufferingSuppression = false
    }

    let kind: PlayerEngineKind = .ksAVIO
    var onSnapshot: ((PlayerSnapshot) -> Void)?
    var onSeekCompleted: ((SeekResult) -> Void)?

    private let source: ResolvedPlaybackSource
    private let sharedTransportSession: TransportDataSession?
    private let view = MDKRenderView()
    private var player: swift_mdk.Player?
    private var stateTimer: Timer?
    private var transportHTTPServer: TransportHTTPServer?
    private var transportPrepareTask: Task<Void, Never>?
    private var lastURL: URL?
    private var lastHeaders: [String: String] = [:]
    private var preferredForwardBuffer: Double = 90
    private var shouldPlay = false
    private var playbackRate: Double = 1
    private var rateGeneration = 0
    private var generation = 0
    private var firstRenderedGeneration = -1
    private var seekGeneration = 0
    private let seekBufferingUIGraceSeconds: TimeInterval = 0.5
    private let seekWatchdogSeconds: TimeInterval = 2.0
    private var pendingSeekResume: PendingSeekResume?
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

        guard let sharedTransportSession else {
            startMDKPlayer(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition, generation: currentGeneration, transportMode: "direct-http302")
            DiagnosticsLogger.shared.playback("MDKTransport", "mode=direct-http302 unifiedTransportAvailable=false nasMediaProxy=false")
            return
        }

        let server = TransportHTTPServer(session: sharedTransportSession, fileExtension: mediaFileExtension, stopSessionOnStop: false)
        transportHTTPServer = server
        DiagnosticsLogger.shared.playback("MDKTransport", "mode=unified-localhost starting=true host=127.0.0.1 unifiedTransportActive=true nasMediaProxy=false")
        transportPrepareTask = Task { @MainActor [weak self, weak server] in
            guard let self, let server else { return }
            do {
                let localURL = try await server.start()
                guard !Task.isCancelled, currentGeneration == self.generation, self.transportHTTPServer === server else { server.stop(); return }
                self.transportPrepareTask = nil
                DiagnosticsLogger.shared.playback("MDKTransport", "mode=unified-localhost ready=true host=127.0.0.1 port=\(localURL.port ?? 0) unifiedTransportActive=true nasMediaProxy=false")
                self.startMDKPlayer(url: localURL, headers: [:], preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition, generation: currentGeneration, transportMode: "unified-localhost")
            } catch {
                guard !Task.isCancelled, currentGeneration == self.generation else { return }
                self.transportPrepareTask = nil
                if self.transportHTTPServer === server { self.transportHTTPServer = nil }
                server.stop()
                let message = "MDK UnifiedTransport 本地桥启动失败：\(error.localizedDescription)"
                DiagnosticsLogger.shared.playback("MDKTransport", "mode=unified-localhost ready=false error=\(error.localizedDescription) directFallback=false nasMediaProxy=false")
                self.onSnapshot?(PlayerSnapshot(position: max(0, startPosition), duration: self.source.mediaSource.durationSeconds ?? 0, isPlaying: false, isBuffering: false, errorMessage: message))
            }
        }
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
        let duration = max(source.mediaSource.durationSeconds ?? 0, seconds(player.mediaInfo.duration))
        if let sharedTransportSession { Task { await sharedTransportSession.prioritizeSeek(position: target, duration: duration) } }
        let requestedAt = Date().timeIntervalSince1970
        seekGeneration &+= 1
        let seekID = seekGeneration
        pendingSeekResume = PendingSeekResume(id: seekID, target: target, requestedAt: requestedAt, callbackAt: nil)
        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(seekID) target=\(String(format: "%.3f", target)) phase=request unifiedTransport=\(sharedTransportSession != nil) direction=\(String(describing: direction))")
        let accepted = player.seek(milliseconds(target), flags: .Default) { [weak self, weak player] actualMs in
            guard let self else { return }
            let callbackAt = Date().timeIntervalSince1970
            let actual = actualMs >= 0 ? self.seconds(actualMs) : player.map { self.seconds($0.position) }
            let latency = (callbackAt - requestedAt) * 1_000
            if var pending = self.pendingSeekResume, pending.id == seekID { pending.callbackAt = callbackAt; self.pendingSeekResume = pending }
            self.onSeekCompleted?(SeekResult(requestedAt: requestedAt, target: target, actualPosition: actual, bufferHit: latency < 150, completionLatencyMs: latency, measurement: "MDK seek callback"))
            DiagnosticsLogger.shared.playback("MDKSeek", "id=\(seekID) target=\(String(format: "%.3f", target)) callbackMs=\(String(format: "%.1f", latency)) actual=\(actual.map { String(format: "%.3f", $0) } ?? "nil") accepted=true current=\(self.pendingSeekResume?.id == seekID) unifiedTransport=\(self.sharedTransportSession != nil) direction=\(String(describing: direction))")
            if self.shouldPlay, player?.state != .Playing { player?.state = .Playing }
        }
        if accepted { scheduleSeekWatchdog(player: player, seekID: seekID, target: target, requestedAt: requestedAt) }
        else {
            if pendingSeekResume?.id == seekID { pendingSeekResume = nil }
            onSeekCompleted?(SeekResult(requestedAt: requestedAt, target: target, actualPosition: self.seconds(player.position), bufferHit: false, completionLatencyMs: 0, measurement: "MDK seek rejected"))
            DiagnosticsLogger.shared.playback("MDKSeek", "id=\(seekID) target=\(String(format: "%.3f", target)) accepted=false unifiedTransport=\(sharedTransportSession != nil) direction=\(String(describing: direction))")
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
        if let sharedTransportSession { Task { await sharedTransportSession.recoverStall(position: position, duration: duration) } }
        DiagnosticsLogger.shared.playback("MDKRecovery", "position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) state=\(String(describing: player.state)) status=0x\(String(player.mediaStatus.rawValue, radix: 16)) unifiedTransport=\(sharedTransportSession != nil) action=prioritize-and-play")
        if shouldPlay { player.state = .Playing }
    }

    func transportMetrics() async -> TransportMetricsSnapshot? {
        guard let sharedTransportSession else { return nil }
        return await sharedTransportSession.metrics()
    }

    func stop() {
        shouldPlay = false
        generation &+= 1
        rateGeneration &+= 1
        stopPlayerOnly()
        onSnapshot = nil
        onSeekCompleted = nil
    }

    private func startMDKPlayer(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double, generation currentGeneration: Int, transportMode: String) {
        guard currentGeneration == generation else { return }
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
            DiagnosticsLogger.shared.playback("MDKPrepare", "preparedAtMs=\(preparedAtMs) requestedStart=\(String(format: "%.3f", startPosition)) sourceFPS=\(self.sourceFrameRateText) videoDecoders=VT,FFmpeg transport=\(transportMode)")
            return true
        })
        startStateTimer()
        DiagnosticsLogger.shared.playback("MDK", "prepare item=\(source.itemId) version=\(swift_mdk.version()) transport=\(transportMode) localHost=\(url.host == "127.0.0.1") sharedTransport=\(sharedTransportSession != nil ? "active" : "unavailable") headers=\(headers.keys.sorted().joined(separator: ",")) rate=\(String(format: "%.2f", playbackRate))")
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
        let rawBuffering = hasStatus(status, bit: 3) || hasStatus(status, bit: 4)
        let ended = hasStatus(status, bit: 6)
        let isPlaying = player.state == .Playing && !ended
        let now = Date().timeIntervalSince1970
        var suppressSeekBuffering = false
        if rawBuffering, var pending = pendingSeekResume, now - pending.requestedAt < seekBufferingUIGraceSeconds {
            suppressSeekBuffering = true
            if !pending.didLogBufferingSuppression {
                pending.didLogBufferingSuppression = true
                pendingSeekResume = pending
                DiagnosticsLogger.shared.playback("MDKBuffering", "id=\(pending.id) target=\(String(format: "%.3f", pending.target)) raw=true ui=false reason=seek-grace graceMs=\(Int(seekBufferingUIGraceSeconds * 1_000))")
            }
        }
        let buffering = rawBuffering && !suppressSeekBuffering
        let forwardBuffered = seconds(player.buffered())
        let bufferedEnd = duration > 0 ? min(duration, position + forwardBuffered) : position + forwardBuffered
        onSnapshot?(PlayerSnapshot(position: position, duration: duration, bufferedRanges: bufferedEnd > position ? [position...bufferedEnd] : [], isPlaying: isPlaying, isBuffering: buffering, waitingReason: buffering ? "MDK 等待媒体数据" : nil, errorMessage: hasStatus(status, bit: 31) ? "MDK media status invalid" : nil, didReachEnd: ended))

        if let pending = pendingSeekResume, position > pending.target + 0.08 {
            let resumeMs = (now - pending.requestedAt) * 1_000
            let afterCallbackMs = pending.callbackAt.map { (now - $0) * 1_000 }
            DiagnosticsLogger.shared.playback("MDKSeekHealth", "id=\(pending.id) target=\(String(format: "%.3f", pending.target)) firstAdvance=\(String(format: "%.3f", position)) resumeMs=\(String(format: "%.1f", resumeMs)) afterCallbackMs=\(afterCallbackMs.map { String(format: "%.1f", $0) } ?? "pending") playing=\(isPlaying) rawBuffering=\(rawBuffering) uiBuffering=\(buffering) bufferMs=\(player.buffered()) unifiedTransport=\(sharedTransportSession != nil)")
            pendingSeekResume = nil
        }
    }

    private func scheduleSeekWatchdog(player: swift_mdk.Player, seekID: Int, target: Double, requestedAt: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seekWatchdogSeconds) { [weak self, weak player] in
            guard let self, let player, self.player === player, let pending = self.pendingSeekResume, pending.id == seekID else { return }
            let now = Date().timeIntervalSince1970
            let callbackMs = pending.callbackAt.map { ($0 - requestedAt) * 1_000 }
            DiagnosticsLogger.shared.playback("MDKSeekWatchdog", "id=\(seekID) target=\(String(format: "%.3f", target)) elapsedMs=\(String(format: "%.1f", (now - requestedAt) * 1_000)) callbackMs=\(callbackMs.map { String(format: "%.1f", $0) } ?? "pending") position=\(String(format: "%.3f", self.seconds(player.position))) state=\(String(describing: player.state)) status=0x\(String(player.mediaStatus.rawValue, radix: 16)) bufferMs=\(player.buffered()) unifiedTransport=\(self.sharedTransportSession != nil)")
            if let session = self.sharedTransportSession {
                Task {
                    let metrics = await session.metrics()
                    DiagnosticsLogger.shared.playback("MDKSeekWatchdog", "id=\(seekID) transport anchor=\(metrics.schedulerAnchorByte) frontier=\(metrics.schedulerFrontierByte) cacheBytes=\(metrics.cacheBytes) active=\(metrics.activeRequestCount) networkBps=\(Int(metrics.currentDownloadBytesPerSecond))")
                }
            }
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

    private var mediaFileExtension: String {
        let container = source.mediaSource.normalizedContainer
        return container.isEmpty ? "mkv" : container
    }

    private func hasStatus(_ raw: Int32, bit: Int32) -> Bool { UInt32(bitPattern: raw) & (UInt32(1) << UInt32(bit)) != 0 }
    private func isPrepared(_ raw: Int32) -> Bool { hasStatus(raw, bit: 2) || hasStatus(raw, bit: 8) }
    private func seconds(_ milliseconds: Int64) -> Double { max(0, Double(milliseconds) / 1_000) }
    private func milliseconds(_ seconds: Double) -> Int64 { Int64((max(0, seconds) * 1_000).rounded()) }

    private func stopPlayerOnly() {
        stateTimer?.invalidate()
        stateTimer = nil
        transportPrepareTask?.cancel()
        transportPrepareTask = nil
        transportHTTPServer?.stop()
        transportHTTPServer = nil
        seekGeneration &+= 1
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