from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"missing anchor in {path}: {old[:220]!r}")
    p.write_text(text.replace(old, new, 1))


renderer_path = Path("MDKLab/SwiftMDKOnePlayer/Sources/swift-mdk/MetalLayerRenderer.swift")
renderer_path.write_text(r'''import Foundation
import Metal
import QuartzCore
#if canImport(mdk)
import mdk
#endif

public final class PlayerMetalLayerRenderer: @unchecked Sendable {
    private final class RenderContext: @unchecked Sendable {
        let layer: CAMetalLayer
        let device: MTLDevice
        private let lock = NSLock()
        private var texture: MTLTexture?
        private var enabled = true

        init(layer: CAMetalLayer, device: MTLDevice) {
            self.layer = layer
            self.device = device
            resize(CGSize(width: 1, height: 1))
        }

        func setEnabled(_ value: Bool) {
            lock.lock()
            enabled = value
            lock.unlock()
        }

        func resize(_ size: CGSize) {
            let width = max(1, Int(size.width.rounded()))
            let height = max(1, Int(size.height.rounded()))
            lock.lock()
            if let texture, texture.width == width, texture.height == height { lock.unlock(); return }
            lock.unlock()
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            descriptor.usage = [.renderTarget, .shaderRead]
            descriptor.storageMode = .private
            guard let newTexture = device.makeTexture(descriptor: descriptor) else { return }
            lock.lock()
            texture = newTexture
            lock.unlock()
        }

        func acquireRenderTexture() -> MTLTexture? {
            lock.lock()
            defer { lock.unlock() }
            guard enabled else { return nil }
            return texture
        }

        func presentationResources() -> (MTLTexture, CAMetalDrawable)? {
            lock.lock()
            guard enabled, let texture else { lock.unlock(); return nil }
            lock.unlock()
            guard let drawable = layer.nextDrawable() else { return nil }
            lock.lock()
            let stillEnabled = enabled
            lock.unlock()
            guard stillEnabled else { return nil }
            return (texture, drawable)
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
        self.context = RenderContext(layer: layer, device: device)
        self.renderQueue = DispatchQueue(label: "OnePlayer.MDK.Render.\(UUID().uuidString)", qos: .userInteractive)
        layer.device = device
        layer.pixelFormat = .bgra8Unorm
        layer.framebufferOnly = false
        layer.presentsWithTransaction = false
        if #available(iOS 11.0, macOS 10.13, tvOS 11.0, *) { layer.allowsNextDrawableTimeout = true }
    }

    public func prepareSurfaceSize(_ size: CGSize) { context.resize(size) }

    public func bind(_ player: Player) {
        func currentRenderTarget(_ opaque: UnsafeRawPointer?) -> UnsafeRawPointer? {
            guard let opaque else { return nil }
            let context: RenderContext = bridge(ptr: opaque)
            guard let texture = context.acquireRenderTexture() else { return nil }
            return bridge(obj: texture)
        }

        context.setEnabled(true)
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
        api.layer = nil
        player.setRenderAPI(&api, vid: self)
        player.setRenderCallback { [weak self] in self?.requestRender() }
    }

    public func setSurfaceSize(_ size: CGSize, player: Player) {
        context.resize(size)
        player.setVideoSurfaceSize(Int32(size.width.rounded()), Int32(size.height.rounded()), vid: self)
    }

    public func detach() {
        lock.lock()
        active = false
        player = nil
        renderPending = false
        lock.unlock()
        context.setEnabled(false)
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
        lock.lock()
        let shouldSubmit = active && self.player === player
        lock.unlock()

        if shouldSubmit {
            if let (source, drawable) = context.presentationResources(), let buffer = commandQueue.makeCommandBuffer(), let blit = buffer.makeBlitCommandEncoder() {
                let width = min(source.width, drawable.texture.width)
                let height = min(source.height, drawable.texture.height)
                if width > 0, height > 0 {
                    blit.copy(from: source, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: width, height: height, depth: 1), to: drawable.texture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
                }
                blit.endEncoding()
                buffer.present(drawable)
                buffer.commit()
            }
            onFrameSubmitted?(result)
            onRenderCompleted?((CACurrentMediaTime() - startedAt) * 1_000)
        }

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

engine_path = "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
replace_once(engine_path, "    private var renderWatchdogTimer: Timer?\n", "    private var renderWatchdogTimer: DispatchSourceTimer?\n    private let watchdogQueue = DispatchQueue(label: \"OnePlayer.MDK.Watchdog\", qos: .userInitiated)\n    private let renderHealthLock = NSLock()\n    private var nativeRenderedFrameSerial: UInt64 = 0\n    private var nativeLastRenderedFrameAt = CACurrentMediaTime()\n    private var nativeRenderedGeneration = -1\n")
replace_once(engine_path, "    private let firstFrameWatchdogSeconds: TimeInterval = 4.0\n", "    private let firstFrameWatchdogSeconds: TimeInterval = 2.0\n")

replace_once(
    engine_path,
    '''        renderer.onFrameSubmitted = { [weak self, weak renderer] result in\n            guard let self else { return }\n            self.renderDispatchLock.lock()\n''',
    '''        renderer.onFrameSubmitted = { [weak self, weak renderer] result in\n            guard let self else { return }\n            self.renderHealthLock.lock()\n            if rendererGeneration == self.generation {\n                self.nativeRenderedFrameSerial &+= 1\n                self.nativeLastRenderedFrameAt = CACurrentMediaTime()\n                self.nativeRenderedGeneration = rendererGeneration\n            }\n            self.renderHealthLock.unlock()\n            self.renderDispatchLock.lock()\n''',
)

replace_once(
    engine_path,
    '''    private func startRenderWatchdog() {\n        renderWatchdogTimer?.invalidate()\n        let timer = Timer.scheduledTimer(withTimeInterval: renderWatchdogPollSeconds, repeats: true) { [weak self] _ in self?.evaluateRenderLiveness() }\n        renderWatchdogTimer = timer\n        RunLoop.main.add(timer, forMode: .common)\n    }\n\n    private func evaluateRenderLiveness() {\n        guard shouldPlay, hasRenderedValidFrame, !lastNativeBuffering else { return }\n        let age = CACurrentMediaTime() - lastRenderedFrameAt\n        guard age >= renderWatchdogTimeoutSeconds else { return }\n        hasRenderedValidFrame = false\n        nativeQuarantineActive = true\n        let message = "MDK native isolation render timeout"\n        DiagnosticsLogger.shared.playback("MDKNativeIsolation", "operation=render timeoutMs=\\(Int(age * 1_000)) generation=\\(generation) mainResponsive=true action=quarantine-engine-switch-mpv")\n        onSnapshot?(PlayerSnapshot(position: lastNativePosition, duration: lastNativeDuration, isPlaying: false, isBuffering: false, waitingReason: "MDK 渲染线程未响应", errorMessage: message))\n    }\n''',
    '''    private func startRenderWatchdog() {\n        renderWatchdogTimer?.cancel()\n        let timer = DispatchSource.makeTimerSource(queue: watchdogQueue)\n        timer.schedule(deadline: .now() + renderWatchdogPollSeconds, repeating: renderWatchdogPollSeconds, leeway: .milliseconds(50))\n        timer.setEventHandler { [weak self] in self?.evaluateRenderLiveness() }\n        renderWatchdogTimer = timer\n        timer.resume()\n    }\n\n    private func nativeRenderHealth() -> (serial: UInt64, lastAt: TimeInterval, generation: Int) {\n        renderHealthLock.lock()\n        let value = (nativeRenderedFrameSerial, nativeLastRenderedFrameAt, nativeRenderedGeneration)\n        renderHealthLock.unlock()\n        return value\n    }\n\n    private func evaluateRenderLiveness() {\n        let currentGeneration = generation\n        guard shouldPlay, preparedGeneration == currentGeneration, !lastNativeBuffering else { return }\n        let health = nativeRenderHealth()\n        guard health.generation == currentGeneration, health.serial > 0 else { return }\n        let age = CACurrentMediaTime() - health.lastAt\n        guard age >= renderWatchdogTimeoutSeconds else { return }\n        nativeQuarantineActive = true\n        let message = "MDK native isolation render timeout"\n        DiagnosticsLogger.shared.playback("MDKNativeIsolation", "operation=render timeoutMs=\\(Int(age * 1_000)) generation=\\(currentGeneration) watchdogQueue=independent renderBridge=offscreen-texture action=quarantine-engine-switch-mpv")\n        quarantineCurrentGeneration(reason: "render-timeout", position: lastNativePosition, failedGeneration: currentGeneration, message: message)\n    }\n''',
)

replace_once(
    engine_path,
    '''        hasRenderedValidFrame = false\n        lastRenderedFrameAt = CACurrentMediaTime()\n        lastNativeBuffering = false\n''',
    '''        hasRenderedValidFrame = false\n        lastRenderedFrameAt = CACurrentMediaTime()\n        renderHealthLock.lock()\n        nativeRenderedFrameSerial = 0\n        nativeLastRenderedFrameAt = CACurrentMediaTime()\n        nativeRenderedGeneration = currentGeneration\n        renderHealthLock.unlock()\n        lastNativeBuffering = false\n''',
)

replace_once(engine_path, "        renderWatchdogTimer?.invalidate()\n", "        renderWatchdogTimer?.cancel()\n")

replace_once(
    engine_path,
    '''            self.attachCallbacks(to: player, generation: currentGeneration)\n            renderer.bind(player)\n            renderer.setSurfaceSize(surfaceSize, player: player)\n            player.playbackRate = Float(self.playbackRate)\n            if self.shouldPlay { player.state = .Playing }\n            DispatchQueue.main.async { [weak self, weak player, weak renderer] in\n                guard let self, let player, let renderer, self.renderer === renderer, self.preparedGeneration == currentGeneration, self.isCurrentPlayer(player, generation: currentGeneration) else { return }\n                self.startStateTimer(player: player, generation: currentGeneration, queue: self.nativeControlQueue)\n                self.startRenderWatchdog()\n                self.scheduleFirstFrameWatchdog(player: player, generation: currentGeneration, startPosition: requestedStart)\n                DiagnosticsLogger.shared.playback("MDKPrepare", "preparedAtMs=\\(preparedAtMs) requestedStart=\\(String(format: \"%.3f\", requestedStart)) sourceFPS=\\(self.sourceFrameRateText) compatLevel=\\(compatLevel) videoDecoders=\\(decoderList.joined(separator: \",\")) transport=\\(transportMode) probation=passed rendererBound=true statePoll=true")\n            }\n''',
    '''            self.attachCallbacks(to: player, generation: currentGeneration)\n            renderer.prepareSurfaceSize(surfaceSize)\n            renderer.bind(player)\n            renderer.setSurfaceSize(surfaceSize, player: player)\n            player.playbackRate = Float(self.playbackRate)\n            if self.shouldPlay { player.state = .Playing }\n            self.startStateTimer(player: player, generation: currentGeneration, queue: self.nativeControlQueue)\n            self.startRenderWatchdog()\n            self.scheduleFirstFrameWatchdog(player: player, generation: currentGeneration, startPosition: requestedStart)\n            DiagnosticsLogger.shared.playback("MDKPrepare", "preparedAtMs=\\(preparedAtMs) requestedStart=\\(String(format: \"%.3f\", requestedStart)) sourceFPS=\\(self.sourceFrameRateText) compatLevel=\\(compatLevel) videoDecoders=\\(decoderList.joined(separator: \",\")) transport=\\(transportMode) probation=passed rendererBound=true statePoll=true renderBridge=offscreen-texture watchdogQueue=independent")\n''',
)

replace_once(
    engine_path,
    '''    private func schedulePrepareWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double, startedAt: TimeInterval) {\n        DispatchQueue.main.asyncAfter(deadline: .now() + prepareWatchdogSeconds) { [weak self, weak player] in\n            guard let self, let player, self.preparingGeneration == currentGeneration, self.isCurrentPlayer(player, generation: currentGeneration) else { return }\n            let elapsedMs = (CACurrentMediaTime() - startedAt) * 1_000\n            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\\(currentGeneration) phase=prepare-timeout elapsedMs=\\(String(format: \"%.1f\", elapsedMs)) start=\\(String(format: \"%.3f\", startPosition)) mainResponsive=true")\n            self.quarantineCurrentGeneration(reason: "prepare-timeout", position: startPosition, failedGeneration: currentGeneration, message: "MDK native prepare timeout")\n        }\n    }\n\n    private func scheduleFirstFrameWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double) {\n        let startSerial = renderedFrameSerial\n        DispatchQueue.main.asyncAfter(deadline: .now() + firstFrameWatchdogSeconds) { [weak self, weak player] in\n            guard let self, let player, self.preparedGeneration == currentGeneration, self.isCurrentPlayer(player, generation: currentGeneration), self.shouldPlay else { return }\n            guard !self.hasRenderedValidFrame, self.renderedFrameSerial <= startSerial else { return }\n            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\\(currentGeneration) phase=first-frame-timeout elapsedMs=\\(Int(self.firstFrameWatchdogSeconds * 1_000)) position=\\(String(format: \"%.3f\", self.lastNativePosition)) mainResponsive=true")\n            self.quarantineCurrentGeneration(reason: "first-frame-timeout", position: max(startPosition, self.lastNativePosition), failedGeneration: currentGeneration, message: "MDK native first frame timeout")\n        }\n    }\n''',
    '''    private func schedulePrepareWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double, startedAt: TimeInterval) {\n        watchdogQueue.asyncAfter(deadline: .now() + prepareWatchdogSeconds) { [weak self, weak player] in\n            guard let self, let player, self.preparingGeneration == currentGeneration, self.isCurrentPlayer(player, generation: currentGeneration) else { return }\n            let elapsedMs = (CACurrentMediaTime() - startedAt) * 1_000\n            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\\(currentGeneration) phase=prepare-timeout elapsedMs=\\(String(format: \"%.1f\", elapsedMs)) start=\\(String(format: \"%.3f\", startPosition)) watchdogQueue=independent")\n            self.quarantineCurrentGeneration(reason: "prepare-timeout", position: startPosition, failedGeneration: currentGeneration, message: "MDK native prepare timeout")\n        }\n    }\n\n    private func scheduleFirstFrameWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double) {\n        let startSerial = nativeRenderHealth().serial\n        watchdogQueue.asyncAfter(deadline: .now() + firstFrameWatchdogSeconds) { [weak self, weak player] in\n            guard let self, let player, self.preparedGeneration == currentGeneration, self.isCurrentPlayer(player, generation: currentGeneration), self.shouldPlay else { return }\n            let health = self.nativeRenderHealth()\n            guard health.generation == currentGeneration, health.serial <= startSerial else { return }\n            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\\(currentGeneration) phase=first-frame-timeout elapsedMs=\\(Int(self.firstFrameWatchdogSeconds * 1_000)) position=\\(String(format: \"%.3f\", self.lastNativePosition)) watchdogQueue=independent renderBridge=offscreen-texture")\n            self.quarantineCurrentGeneration(reason: "first-frame-timeout", position: max(startPosition, self.lastNativePosition), failedGeneration: currentGeneration, message: "MDK native first frame timeout")\n        }\n    }\n''',
)

replace_once(
    engine_path,
    '''                DispatchQueue.main.async { [weak self, weak player, weak renderer] in\n                    guard let self, let player, let renderer else { return }\n                    self.activatePreparedPlayer(player, renderer: renderer, surfaceSize: surfaceSize, generation: currentGeneration, preparedAtMs: preparedAtMs, requestedStart: startPosition, compatLevel: compatLevel, decoderList: decoderList, transportMode: transportMode, prepareStartedAt: prepareStartedAt)\n                }\n                return true\n''',
    '''                self.activatePreparedPlayer(player, renderer: renderer, surfaceSize: surfaceSize, generation: currentGeneration, preparedAtMs: preparedAtMs, requestedStart: startPosition, compatLevel: compatLevel, decoderList: decoderList, transportMode: transportMode, prepareStartedAt: prepareStartedAt)\n                return true\n''',
)

orchestrator_path = "Sources/Player/PlaybackOrchestrator.swift"
replace_once(
    orchestrator_path,
    '''        if preference.isAutomatic {\n            let storedCompatibility = MediaCompatibilityStore.requiresCompatibilityEngine(itemId: source.itemId)\n            if storedCompatibility {\n                let compatibilityKind = PlayerEnginePreference.automaticCompatibilityKind\n                self.currentKind = compatibilityKind\n                DiagnosticsLogger.shared.log("Compatibility", "item=\\(source.itemId) automaticProfile=\\(compatibilityKind.title)+UnifiedTransportV3 reason=stored-media-compatibility")\n            } else {\n                self.currentKind = preference.resolved(for: source.mediaSource)\n                DiagnosticsLogger.shared.log("Compatibility", "item=\\(source.itemId) automaticProfile=\\(currentKind.title)+UnifiedTransportV3 reason=high-performance-priority")\n            }\n        } else {\n''',
    '''        if preference.isAutomatic {\n            let preferredKind = preference.resolved(for: source.mediaSource)\n            if preferredKind == .ksAVIO {\n                self.currentKind = preferredKind\n                DiagnosticsLogger.shared.log("Compatibility", "item=\\(source.itemId) automaticProfile=\\(currentKind.title)+UnifiedTransportV3 reason=per-session-mdk-probe storedCompatibilityIgnored=true")\n            } else if MediaCompatibilityStore.requiresCompatibilityEngine(itemId: source.itemId) {\n                let compatibilityKind = PlayerEnginePreference.automaticCompatibilityKind\n                self.currentKind = compatibilityKind\n                DiagnosticsLogger.shared.log("Compatibility", "item=\\(source.itemId) automaticProfile=\\(compatibilityKind.title)+UnifiedTransportV3 reason=stored-non-mdk-compatibility")\n            } else {\n                self.currentKind = preferredKind\n                DiagnosticsLogger.shared.log("Compatibility", "item=\\(source.itemId) automaticProfile=\\(currentKind.title)+UnifiedTransportV3 reason=high-performance-priority")\n            }\n        } else {\n''',
)

controller_path = "Sources/Player/PlayerController.swift"
replace_once(
    controller_path,
    '''            if engineKind == .ksAVIO, next == .mpv, message.lowercased().contains("mdk native isolation") { MediaCompatibilityStore.markCompatibilityEngineRequired(itemId: source.itemId, reason: "mdk-native-isolation") }\n            stallMessage = "\\(engineKind.title) 发生错误，正在自动切换到 \\(next.title)。"\n''',
    '''            if engineKind == .ksAVIO, next == .mpv { DiagnosticsLogger.shared.playback("Compatibility", "item=\\(source.itemId) mdkFailureHistory=diagnostic-only persistentEngineRouting=false error=\\(message)") }\n            stallMessage = "\\(engineKind.title) 发生错误，正在自动切换到 \\(next.title)。"\n''',
)

view_path = "Sources/UI/EmbyMediaDetailView.swift"
replace_once(
    view_path,
    '''            } else if let index = episodes.firstIndex(where: { $0.id == itemID }) {\n                episodes[index] = refreshed\n            }\n            DiagnosticsLogger.shared.log("EmbyDetail", "playback userdata refreshed item=\\(itemID) positionTicks=\\(refreshed.userData?.playbackPositionTicks ?? 0)")\n''',
    '''            } else if let index = episodes.firstIndex(where: { $0.id == itemID }) {\n                episodes[index] = refreshed\n                selectedEpisodeID = itemID\n                if let season = seasonNumber(for: refreshed) {\n                    selectedSeason = season\n                    if let offset = selectedSeasonEpisodes.firstIndex(where: { $0.id == itemID }) { selectedEpisodeRangeOffset = (offset / 10) * 10 }\n                }\n                hasPlaybackPositionOverride = false\n                playbackPositionOverrideTicks = nil\n            }\n            DiagnosticsLogger.shared.log("EmbyDetail", "playback userdata refreshed item=\\(itemID) positionTicks=\\(refreshed.userData?.playbackPositionTicks ?? 0) selectedResumeTarget=\\(selectedEpisodeID ?? item.id) override=\\(hasPlaybackPositionOverride)")\n''',
)

identity_path = "Sources/Core/AppIdentity.swift"
replace_once(identity_path, 'static let sourceVersion = "0.13.29"', 'static let sourceVersion = "0.13.30"')
replace_once(identity_path, '?? "0.13.29"', '?? "0.13.30"')

project_path = Path("project.mdklab.yml")
text = project_path.read_text()
if 'MARKETING_VERSION: "0.13.30"' not in text:
    if text.count('MARKETING_VERSION: "0.13.29"') != 2:
        raise SystemExit('unexpected MARKETING_VERSION anchor count')
    text = text.replace('MARKETING_VERSION: "0.13.29"', 'MARKETING_VERSION: "0.13.30"')
if 'CURRENT_PROJECT_VERSION: "97"' not in text:
    if text.count('CURRENT_PROJECT_VERSION: "96"') != 2:
        raise SystemExit('unexpected CURRENT_PROJECT_VERSION anchor count')
    text = text.replace('CURRENT_PROJECT_VERSION: "96"', 'CURRENT_PROJECT_VERSION: "97"')
project_path.write_text(text)

print('Build97 MDK offscreen render isolation + per-session fallback + detail resume refresh materialized')
