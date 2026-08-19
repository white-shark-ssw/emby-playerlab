from pathlib import Path
import re
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
UPSTREAM = "https://raw.githubusercontent.com/wang-bin/swift-mdk/f112a85f2f51c5352439465204c1ae0fa51a9f18/"


def replace_once(path: str, old: str, new: str) -> None:
    p = ROOT / path
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one match, got {count}")
    p.write_text(text.replace(old, new, 1))


def regex_once(path: str, pattern: str, replacement: str) -> None:
    p = ROOT / path
    text = p.read_text()
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"{path}: regex expected exactly one match, got {count}: {pattern[:80]}")
    p.write_text(updated)


def download_text(relative: str) -> str:
    with urllib.request.urlopen(UPSTREAM + relative, timeout=60) as response:
        return response.read().decode("utf-8")


project = (ROOT / "project.mdklab.yml").read_text()
if 'MARKETING_VERSION: "0.13.19"' in project and 'CURRENT_PROJECT_VERSION: "86"' in project:
    print("Build86 source already materialized")
    raise SystemExit(0)
if 'MARKETING_VERSION: "0.13.18"' not in project or 'CURRENT_PROJECT_VERSION: "85"' not in project:
    raise SystemExit("Expected Build85 source baseline before materializing Build86")

# Pin the exact already-tested swift-mdk revision locally so we can add a Metal layer renderer
# inside the swift_mdk module without importing the transitive mdk C module from the app target.
local_pkg = ROOT / "MDKLab/SwiftMDKOnePlayer"
source_dir = local_pkg / "Sources/swift-mdk"
source_dir.mkdir(parents=True, exist_ok=True)
for relative in ["Package.swift", "LICENSE", "Sources/swift-mdk/MediaInfo.swift", "Sources/swift-mdk/Player.swift", "Sources/swift-mdk/VideoFrame.swift", "Sources/swift-mdk/global.swift", "Sources/swift-mdk/swift_mdk.swift"]:
    destination = local_pkg / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(download_text(relative))

(source_dir / "MetalLayerRenderer.swift").write_text(r'''import Foundation
import Metal
import QuartzCore
#if canImport(mdk)
import mdk
#endif

public final class PlayerMetalLayerRenderer: @unchecked Sendable {
    private final class RenderContext: @unchecked Sendable {
        let layer: CAMetalLayer
        private let lock = NSLock()
        private var drawable: CAMetalDrawable?

        init(layer: CAMetalLayer) { self.layer = layer }

        func acquireTexture() -> MTLTexture? {
            guard let next = layer.nextDrawable() else { return nil }
            lock.lock()
            drawable = next
            lock.unlock()
            return next.texture
        }

        func takeDrawable() -> CAMetalDrawable? {
            lock.lock()
            let value = drawable
            drawable = nil
            lock.unlock()
            return value
        }

        func clearDrawable() {
            lock.lock()
            drawable = nil
            lock.unlock()
        }
    }

    public var onFrameSubmitted: (@Sendable (Double) -> Void)?
    public var onRenderCompleted: (@Sendable (Double) -> Void)?

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let context: RenderContext
    private let renderQueue: DispatchQueue
    private let lock = NSLock()
    private weak var player: Player?
    private var active = false
    private var renderScheduled = false
    private var renderPending = false

    public init?(layer: CAMetalLayer) {
        guard let device = MTLCreateSystemDefaultDevice(), let commandQueue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.commandQueue = commandQueue
        self.context = RenderContext(layer: layer)
        self.renderQueue = DispatchQueue(label: "OnePlayer.MDK.Render.\(UUID().uuidString)", qos: .userInteractive)
        layer.device = device
        layer.pixelFormat = .bgra8Unorm
        layer.framebufferOnly = true
        layer.presentsWithTransaction = false
        if #available(iOS 11.0, macOS 10.13, tvOS 11.0, *) { layer.allowsNextDrawableTimeout = true }
    }

    public func bind(_ player: Player) {
        func currentRenderTarget(_ opaque: UnsafeRawPointer?) -> UnsafeRawPointer? {
            guard let opaque else { return nil }
            let context: RenderContext = bridge(ptr: opaque)
            guard let texture = context.acquireTexture() else { return nil }
            return bridge(obj: texture)
        }

        lock.lock()
        self.player = player
        active = true
        renderScheduled = false
        renderPending = false
        lock.unlock()

        var api = mdkMetalRenderAPI()
        api.type = MDK_RenderAPI_Metal
        api.device = bridge(obj: device)
        api.cmdQueue = bridge(obj: commandQueue)
        api.opaque = bridge(obj: context)
        api.currentRenderTarget = currentRenderTarget
        api.layer = bridge(obj: context.layer)
        player.setRenderAPI(&api, vid: self)
        player.setRenderCallback { [weak self] in self?.requestRender() }
    }

    public func setSurfaceSize(_ size: CGSize, player: Player) {
        player.setVideoSurfaceSize(Int32(size.width.rounded()), Int32(size.height.rounded()), vid: self)
    }

    public func detach() {
        lock.lock()
        active = false
        player = nil
        renderPending = false
        lock.unlock()
        context.clearDrawable()
    }

    public func invalidateNative(_ player: Player) {
        player.setRenderCallback(nil)
        player.setVideoSurfaceSize(Int32(-1), Int32(-1), vid: self)
    }

    private func requestRender() {
        let player: Player
        lock.lock()
        guard active, let current = self.player else { lock.unlock(); return }
        if renderScheduled {
            renderPending = true
            lock.unlock()
            return
        }
        renderScheduled = true
        player = current
        lock.unlock()
        renderQueue.async { [weak self, player] in self?.render(player) }
    }

    private func render(_ player: Player) {
        let startedAt = CACurrentMediaTime()
        let result = player.renderVideo(vid: self)
        if let drawable = context.takeDrawable(), let buffer = commandQueue.makeCommandBuffer() {
            buffer.present(drawable)
            buffer.commit()
        }
        onFrameSubmitted?(result)
        onRenderCompleted?((CACurrentMediaTime() - startedAt) * 1_000)

        var scheduleAgain = false
        lock.lock()
        if active, self.player === player, renderPending {
            renderPending = false
            scheduleAgain = true
        } else {
            renderScheduled = false
            renderPending = false
        }
        lock.unlock()
        if scheduleAgain { renderQueue.async { [weak self, player] in self?.render(player) } }
    }
}
''')

replace_once(
    "project.mdklab.yml",
    '''  SwiftMDK:\n    url: https://github.com/wang-bin/swift-mdk.git\n    revision: f112a85f2f51c5352439465204c1ae0fa51a9f18\n''',
    '''  SwiftMDK:\n    path: MDKLab/SwiftMDKOnePlayer\n''')

engine_path = "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
replace_once(engine_path, "import MetalKit\n", "")

regex_once(
    engine_path,
    r'''private final class MDKRenderView: MTKView, MTKViewDelegate \{.*?\n\}\n\nfinal class KSAVIOPlayerEngine''',
    r'''private final class MDKRenderView: UIView {
    var onSurfaceChanged: ((CGSize) -> Void)?

    override class var layerClass: AnyClass { CAMetalLayer.self }
    var metalLayer: CAMetalLayer { layer as! CAMetalLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isOpaque = true
        isUserInteractionEnabled = false
        metalLayer.contentsScale = UIScreen.main.scale
    }

    convenience init() { self.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = window?.screen.scale ?? UIScreen.main.scale
        let size = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
        guard metalLayer.drawableSize != size else { return }
        metalLayer.drawableSize = size
        onSurfaceChanged?(size)
    }

    var currentPixelSize: CGSize {
        let size = metalLayer.drawableSize
        if size.width > 0, size.height > 0 { return size }
        let scale = window?.screen.scale ?? UIScreen.main.scale
        return CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
    }
}

final class KSAVIOPlayerEngine''')

replace_once(
    engine_path,
    '''    private let source: ResolvedPlaybackSource\n    private let sharedTransportSession: TransportDataSession?\n    private let view = MDKRenderView()\n    private let nativeControlQueue = DispatchQueue(label: "OnePlayer.MDK.NativeControl", qos: .userInitiated)\n    private var player: swift_mdk.Player?\n    private var stateTimer: Timer?\n''',
    '''    private let source: ResolvedPlaybackSource\n    private let sharedTransportSession: TransportDataSession?\n    private let view: MDKRenderView\n    private var renderer: PlayerMetalLayerRenderer\n    private var nativeControlQueue = DispatchQueue(label: "OnePlayer.MDK.NativeControl.0", qos: .userInitiated)\n    private let playerLock = NSLock()\n    private var player: swift_mdk.Player?\n    private var stateTimer: DispatchSourceTimer?\n    private var renderWatchdogTimer: Timer?\n    private var hasRenderedValidFrame = false\n    private var lastRenderedFrameAt = CACurrentMediaTime()\n    private var lastNativeBuffering = false\n    private var lastNativePosition: Double = 0\n    private var lastNativeDuration: Double = 0\n''')

regex_once(
    engine_path,
    r'''    init\(source: ResolvedPlaybackSource, client: EmbyAPIClient, configuration: MediaTransportConfiguration, sharedTransportSession: TransportDataSession\? = nil, ktvCacheSession: KTVCachePlaybackSession\? = nil\) \{.*?\n    \}\n\n    func prepare''',
    r'''    init(source: ResolvedPlaybackSource, client: EmbyAPIClient, configuration: MediaTransportConfiguration, sharedTransportSession: TransportDataSession? = nil, ktvCacheSession: KTVCachePlaybackSession? = nil) {
        self.source = source
        self.sharedTransportSession = sharedTransportSession
        let renderView = MDKRenderView()
        guard let renderer = PlayerMetalLayerRenderer(layer: renderView.metalLayer) else { fatalError("Metal is unavailable") }
        self.view = renderView
        self.renderer = renderer
        configureRenderer(renderer)
        renderView.onSurfaceChanged = { [weak self] size in self?.surfaceDidChange(size) }
        _ = client
        _ = configuration
        _ = ktvCacheSession
    }

    private func configureRenderer(_ renderer: PlayerMetalLayerRenderer) {
        renderer.onFrameSubmitted = { [weak self] result in
            DispatchQueue.main.async { [weak self] in self?.recordRenderedFrame(result) }
        }
        renderer.onRenderCompleted = { elapsedMs in
            guard elapsedMs >= 250 else { return }
            DiagnosticsLogger.shared.playback("MDKNativeIsolation", "operation=render completedMs=\(String(format: "%.1f", elapsedMs)) mainThread=false")
        }
    }

    private func currentPlayerReference() -> swift_mdk.Player? {
        playerLock.lock()
        let value = player
        playerLock.unlock()
        return value
    }

    private func installPlayer(_ value: swift_mdk.Player?) {
        playerLock.lock()
        player = value
        playerLock.unlock()
    }

    private func takePlayer() -> swift_mdk.Player? {
        playerLock.lock()
        let value = player
        player = nil
        playerLock.unlock()
        return value
    }

    private func isCurrentPlayer(_ candidate: swift_mdk.Player, generation expectedGeneration: Int) -> Bool {
        playerLock.lock()
        let matches = generation == expectedGeneration && player === candidate
        playerLock.unlock()
        return matches
    }

    private func surfaceDidChange(_ size: CGSize) {
        DiagnosticsLogger.shared.playback("MDKSurface", "size=\(Int(size.width))x\(Int(size.height)) backend=CAMetalLayer mainNativeCall=false")
        guard let player = currentPlayerReference() else { return }
        let currentGeneration = generation
        let renderer = self.renderer
        let queue = nativeControlQueue
        queue.async { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: currentGeneration) else { return }
            renderer.setSurfaceSize(size, player: player)
        }
    }

    private func requestPlayerState(playing: Bool, expectedPlayer: swift_mdk.Player? = nil, generation expectedGeneration: Int? = nil) {
        guard let player = expectedPlayer ?? currentPlayerReference() else { return }
        let currentGeneration = expectedGeneration ?? generation
        let queue = nativeControlQueue
        queue.async { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: currentGeneration) else { return }
            player.state = playing ? .Playing : .Paused
        }
    }

    private func startRenderWatchdog() {
        renderWatchdogTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.evaluateRenderLiveness() }
        renderWatchdogTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func evaluateRenderLiveness() {
        guard shouldPlay, hasRenderedValidFrame, !lastNativeBuffering else { return }
        let age = CACurrentMediaTime() - lastRenderedFrameAt
        guard age >= 4 else { return }
        hasRenderedValidFrame = false
        let message = "MDK native isolation render timeout"
        DiagnosticsLogger.shared.playback("MDKNativeIsolation", "operation=render timeoutMs=\(Int(age * 1_000)) mainResponsive=true action=quarantine-engine")
        onSnapshot?(PlayerSnapshot(position: lastNativePosition, duration: lastNativeDuration, isPlaying: false, isBuffering: false, waitingReason: "MDK 渲染线程未响应", errorMessage: message))
    }

    func prepare''')

replace_once(
    engine_path,
    '''        stopPlayerOnly()\n        generation &+= 1\n        let currentGeneration = generation\n''',
    '''        stopPlayerOnly()\n        generation &+= 1\n        let currentGeneration = generation\n        nativeControlQueue = DispatchQueue(label: "OnePlayer.MDK.NativeControl.\(currentGeneration)", qos: .userInitiated)\n        guard let newRenderer = PlayerMetalLayerRenderer(layer: view.metalLayer) else { return }\n        renderer = newRenderer\n        configureRenderer(newRenderer)\n        startRenderWatchdog()\n''')

replace_once(
    engine_path,
    '''        prematureEOFRecoveryActive = false\n        installMDKLoggingIfNeeded()\n''',
    '''        prematureEOFRecoveryActive = false\n        hasRenderedValidFrame = false\n        lastRenderedFrameAt = CACurrentMediaTime()\n        lastNativeBuffering = false\n        lastNativePosition = max(0, startPosition)\n        lastNativeDuration = source.mediaSource.durationSeconds ?? 0\n        installMDKLoggingIfNeeded()\n''')

replace_once(
    engine_path,
    '''    func play() {\n        shouldPlay = true\n        player?.state = .Playing\n    }\n\n    func pause() {\n        shouldPlay = false\n        guard let player else { return }\n        let playerGeneration = generation\n        DiagnosticsLogger.shared.playback("MDKLifecycle", "phase=pause-request generation=\(playerGeneration) nativeOutstanding=\(nativeSeekOutstandingCount) action=async-native-state")\n        nativeControlQueue.async { [weak self, weak player] in\n            guard let self, let player, playerGeneration == self.generation, self.player === player else { return }\n            player.state = .Paused\n        }\n    }\n''',
    '''    func play() {\n        shouldPlay = true\n        requestPlayerState(playing: true)\n    }\n\n    func pause() {\n        shouldPlay = false\n        DiagnosticsLogger.shared.playback("MDKLifecycle", "phase=pause-request generation=\(generation) nativeOutstanding=\(nativeSeekOutstandingCount) action=isolated-native-state")\n        requestPlayerState(playing: false)\n    }\n''')

regex_once(
    engine_path,
    r'''    private func startMDKPlayer\(url: URL, headers: \[String: String\], preferredForwardBuffer: Double, startPosition: Double, generation currentGeneration: Int, transportMode: String\) \{.*?\n    \}\n\n    private func attachCallbacks''',
    r'''    private func startMDKPlayer(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double, generation currentGeneration: Int, transportMode: String) {
        guard currentGeneration == generation else { return }
        let player = swift_mdk.Player()
        installPlayer(player)
        let renderer = self.renderer
        let queue = nativeControlQueue
        let surfaceSize = view.currentPixelSize
        startStateTimer(player: player, generation: currentGeneration, queue: queue)
        queue.async { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: currentGeneration) else { return }
            player.videoDecoders = ["VT", "FFmpeg"]
            player.playbackRate = Float(self.playbackRate)
            player.setBufferRange(msMin: 1_000, msMax: Int64(max(3_000, min(30_000, preferredForwardBuffer * 1_000))), drop: false)
            self.applyHTTPHeaders(headers, to: player)
            self.attachCallbacks(to: player, generation: currentGeneration)
            renderer.bind(player)
            renderer.setSurfaceSize(surfaceSize, player: player)
            player.setProperty(name: "keep_open", value: "1")
            player.media = url.absoluteString
            player.prepare(from: self.milliseconds(startPosition), complete: { [weak self, weak player] preparedAtMs, boost in
                guard let self, let player, self.isCurrentPlayer(player, generation: currentGeneration) else { return false }
                boost = true
                if self.shouldPlay { self.requestPlayerState(playing: true, expectedPlayer: player, generation: currentGeneration) }
                DiagnosticsLogger.shared.playback("MDKPrepare", "preparedAtMs=\(preparedAtMs) requestedStart=\(String(format: "%.3f", startPosition)) sourceFPS=\(self.sourceFrameRateText) videoDecoders=VT,FFmpeg transport=\(transportMode) mainNativeCall=false")
                return true
            })
            DiagnosticsLogger.shared.playback("MDK", "prepare item=\(self.source.itemId) version=\(swift_mdk.version()) transport=\(transportMode) localHost=\(url.host == "127.0.0.1") sharedTransport=\(self.sharedTransportSession != nil ? "active" : "unavailable") headers=\(headers.keys.sorted().joined(separator: ",")) rate=\(String(format: "%.2f", self.playbackRate)) nativeQueue=isolated")
        }
    }

    private func attachCallbacks''')

regex_once(
    engine_path,
    r'''    private func attachCallbacks\(to player: swift_mdk.Player, generation: Int\) \{.*?\n    \}\n\n    private func startStateTimer\(\) \{.*?\n    \}\n\n    private func pollState\(\) \{.*?\n    \}\n\n    private func scheduleActiveNativeSeekFastWatchdog''',
    r'''    private func attachCallbacks(to player: swift_mdk.Player, generation: Int) {
        player.onStateChanged { [weak self, weak player] state in
            DispatchQueue.main.async { [weak self, weak player] in
                guard let self, let player, self.isCurrentPlayer(player, generation: generation) else { return }
                DiagnosticsLogger.shared.playback("MDKState", "state=\(String(describing: state)) position=\(String(format: "%.3f", self.lastNativePosition)) nativeCallbackMainRead=false")
            }
        }
        player.onMediaStatusChanged { [weak self, weak player] status in
            DispatchQueue.main.async { [weak self, weak player] in
                guard let self, let player, self.isCurrentPlayer(player, generation: generation) else { return }
                DiagnosticsLogger.shared.playback("MDKStatus", "raw=0x\(String(status.rawValue, radix: 16)) position=\(String(format: "%.3f", self.lastNativePosition)) nativeCallbackMainRead=false")
                if self.shouldPlay, self.isPrepared(status.rawValue) { self.requestPlayerState(playing: true, expectedPlayer: player, generation: generation) }
            }
            return true
        }
    }

    private func startStateTimer(player: swift_mdk.Player, generation: Int, queue: DispatchQueue) {
        stateTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.10, repeating: 0.10, leeway: .milliseconds(20))
        timer.setEventHandler { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: generation) else { return }
            self.pollState(player: player, generation: generation)
        }
        stateTimer = timer
        timer.resume()
    }

    private func pollState(player: swift_mdk.Player, generation: Int) {
        guard isCurrentPlayer(player, generation: generation) else { return }
        let position = seconds(player.position)
        let info = player.mediaInfo
        let duration = max(seconds(info.duration), source.mediaSource.durationSeconds ?? 0)
        let status = player.mediaStatus.rawValue
        let rawBuffering = hasStatus(status, bit: 3) || hasStatus(status, bit: 4)
        let ended = hasStatus(status, bit: 6)
        let isPlaying = player.state == .Playing && !ended
        let bufferMs = player.buffered()
        DispatchQueue.main.async { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: generation) else { return }
            self.consumeStateSample(position: position, duration: duration, status: status, rawBuffering: rawBuffering, ended: ended, isPlaying: isPlaying, bufferMs: bufferMs)
        }
    }

    private func consumeStateSample(position: Double, duration: Double, status: Int32, rawBuffering: Bool, ended: Bool, isPlaying: Bool, bufferMs: Int64) {
        let now = Date().timeIntervalSince1970
        lastNativePosition = position
        lastNativeDuration = duration
        lastNativeBuffering = rawBuffering

        if ended, duration > 0, position + max(3, duration * 0.005) < duration, activeNativeSeek != nil || queuedLatestSeek != nil || pendingSeekResume != nil {
            let recoveryTarget = latestDesiredTarget(fallback: position)
            activeNativeSeek = nil
            queuedLatestSeek = nil
            pendingSeekResume = nil
            DiagnosticsLogger.shared.playback("MDKSeekWedge", "reason=premature-eof-during-seek position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) latestTarget=\(String(format: "%.3f", recoveryTarget)) action=in-place-reprepare-no-rebuild")
            recoverStall(position: recoveryTarget, duration: duration)
            return
        }

        var suppressSeekBuffering = false
        if rawBuffering, let graceStartedAt = seekBufferingGraceStartedAt, now - graceStartedAt < seekBufferingUIGraceSeconds {
            suppressSeekBuffering = true
            if didLogSeekBufferingGraceID != seekBufferingGraceID {
                didLogSeekBufferingGraceID = seekBufferingGraceID
                DiagnosticsLogger.shared.playback("MDKBuffering", "id=\(seekBufferingGraceID ?? -1) target=\(String(format: "%.3f", seekBufferingGraceTarget ?? position)) raw=true ui=false reason=active-native-seek-grace graceMs=\(Int(seekBufferingUIGraceSeconds * 1_000))")
            }
        }
        let buffering = rawBuffering && !suppressSeekBuffering
        let forwardBuffered = seconds(bufferMs)
        let bufferedEnd = duration > 0 ? min(duration, position + forwardBuffered) : position + forwardBuffered
        onSnapshot?(PlayerSnapshot(position: position, duration: duration, bufferedRanges: bufferedEnd > position ? [position...bufferedEnd] : [], isPlaying: isPlaying, isBuffering: buffering, waitingReason: buffering ? "MDK 等待媒体数据" : nil, errorMessage: hasStatus(status, bit: 31) ? "MDK media status invalid" : nil, didReachEnd: ended))

        if var pending = pendingSeekResume, !pending.didLogClockAdvance, let callbackPosition = pending.callbackPosition, abs(position - callbackPosition) > 0.08 {
            let resumeMs = (now - pending.requestedAt) * 1_000
            let afterCallbackMs = pending.callbackAt.map { (now - $0) * 1_000 }
            pending.didLogClockAdvance = true
            pendingSeekResume = pending
            DiagnosticsLogger.shared.playback("MDKSeekHealth", "id=\(pending.id) target=\(String(format: "%.3f", pending.target)) callbackPosition=\(String(format: "%.3f", callbackPosition)) firstClockAdvance=\(String(format: "%.3f", position)) resumeMs=\(String(format: "%.1f", resumeMs)) afterCallbackMs=\(afterCallbackMs.map { String(format: "%.1f", $0) } ?? "pending") playing=\(isPlaying) rawBuffering=\(rawBuffering) uiBuffering=\(buffering) bufferMs=\(bufferMs) nativeOutstanding=\(nativeSeekOutstandingCount) awaitingRenderedFrame=true unifiedTransport=\(sharedTransportSession != nil)")
        }
    }

    private func scheduleActiveNativeSeekFastWatchdog''')

replace_once(
    engine_path,
    '''        if prematureEOFRecoveryActive, renderResult.isFinite, renderResult >= 0 {\n''',
    '''        if renderResult.isFinite, renderResult >= 0 {\n            hasRenderedValidFrame = true\n            lastRenderedFrameAt = CACurrentMediaTime()\n        }\n        if prematureEOFRecoveryActive, renderResult.isFinite, renderResult >= 0 {\n''')

regex_once(
    engine_path,
    r'''    private func stopPlayerOnly\(\) \{.*?\n    \}\n\}\n#endif''',
    r'''    private func stopPlayerOnly() {
        stateTimer?.cancel()
        stateTimer = nil
        renderWatchdogTimer?.invalidate()
        renderWatchdogTimer = nil
        transportPrepareTask?.cancel()
        transportPrepareTask = nil
        let server = transportHTTPServer
        transportHTTPServer = nil
        server?.stop()
        seekGeneration &+= 1
        let activeSeekID = activeNativeSeek?.id
        pendingSeekResume = nil
        activeNativeSeek = nil
        queuedLatestSeek = nil
        seekBufferingGraceStartedAt = nil
        seekBufferingGraceID = nil
        seekBufferingGraceTarget = nil
        didLogSeekBufferingGraceID = nil
        let oldRenderer = renderer
        oldRenderer.detach()
        guard let oldPlayer = takePlayer() else { return }
        let teardownStartedAt = CACurrentMediaTime()
        DiagnosticsLogger.shared.playback("MDKTeardown", "phase=ui-detached generation=\(generation) activeSeek=\(activeSeekID ?? -1) action=isolated-native-stop mainResponsive=true")
        DispatchQueue.global(qos: .utility).async {
            oldRenderer.invalidateNative(oldPlayer)
            oldPlayer.state = .Stopped
            let elapsed = (CACurrentMediaTime() - teardownStartedAt) * 1_000
            DiagnosticsLogger.shared.playback("MDKTeardown", "phase=native-stop-finished ms=\(String(format: "%.1f", elapsed)) activeSeek=\(activeSeekID ?? -1) mainThread=false")
        }
    }
}
#endif''')

replace_once(
    "Sources/Player/PlaybackOrchestrator.swift",
    '''    func actionForEngineError(kind: PlayerEngineKind, message: String) -> PlaybackRecoveryAction? {\n        DiagnosticsLogger.shared.log("Orchestrator", "engine error engine=\\(kind.title) runtimeSwitch=disabled error=\\(message)")\n        return nil\n    }\n'''.replace('\\\\', '\\'),
    '''    func actionForEngineError(kind: PlayerEngineKind, message: String) -> PlaybackRecoveryAction? {\n        let normalized = message.lowercased()\n        if kind == .ksAVIO, normalized.contains("mdk native isolation"), automaticMode {\n            DiagnosticsLogger.shared.playback("Orchestrator", "engine error engine=\\(kind.title) failureIsolation=triggered action=switch-mpv error=\\(message)")\n            return .switchEngine(.mpv, reason: "MDK native worker 超时；主线程仍响应，受控切换到 MPV 高兼容引擎")\n        }\n        DiagnosticsLogger.shared.log("Orchestrator", "engine error engine=\\(kind.title) runtimeSwitch=disabled error=\\(message)")\n        return nil\n    }\n'''.replace('\\\\', '\\'))

replace_once(
    "Sources/UI/PlayerScreen.swift",
    '''    private func closePlayer() {\n        guard !isClosing else { return }\n        isClosing = true\n''',
    '''    private func closePlayer() {\n        guard !isClosing else { return }\n        DiagnosticsLogger.shared.app("PlayerLifecycle", "close tap received before engine stop engine=\\(controller.engineKind.title)")\n        isClosing = true\n'''.replace('\\\\', '\\'))

replace_once("Sources/Core/AppIdentity.swift", 'static let sourceVersion = "0.13.8"', 'static let sourceVersion = "0.13.19"')
replace_once("Sources/Core/AppIdentity.swift", '?? "0.13.8"', '?? "0.13.19"')

project_path = ROOT / "project.mdklab.yml"
project = project_path.read_text().replace('MARKETING_VERSION: "0.13.18"', 'MARKETING_VERSION: "0.13.19"').replace('CURRENT_PROJECT_VERSION: "85"', 'CURRENT_PROJECT_VERSION: "86"')
project_path.write_text(project)

print("Build86 MDK native isolation source materialized")
