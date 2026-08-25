from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"missing anchor in {path}: {old[:180]!r}")
    p.write_text(text.replace(old, new, 1))


def replace_all_exact(path: str, old: str, new: str, expected: int) -> None:
    p = Path(path)
    text = p.read_text()
    old_count = text.count(old)
    new_count = text.count(new)
    if old_count == 0:
        if new_count == expected:
            return
        raise SystemExit(f"unexpected materialized count in {path}: {new!r} count={new_count} expected={expected}")
    if old_count != expected:
        raise SystemExit(f"unexpected anchor count in {path}: {old!r} count={old_count} expected={expected}")
    p.write_text(text.replace(old, new))


engine_path = Path("MDKLab/App/MDKKSAVIOPlayerEngine.swift")
engine = engine_path.read_text()

old_store_anchor = '''}\n\nfinal class KSAVIOPlayerEngine: PlayerEngine {'''
new_store_anchor = '''}\n\nprivate final class MDKNativeQuarantineStore {\n    static let shared = MDKNativeQuarantineStore()\n    private let lock = NSLock()\n    private var retainedObjects: [AnyObject] = []\n\n    func retain(_ objects: AnyObject...) {\n        lock.lock()\n        retainedObjects.append(contentsOf: objects)\n        let count = retainedObjects.count\n        lock.unlock()\n        DiagnosticsLogger.shared.playback("MDKNativeIsolation", "operation=quarantine-retain objects=\\(count) action=skip-native-destroy")\n    }\n}\n\nfinal class KSAVIOPlayerEngine: PlayerEngine {'''
if new_store_anchor not in engine:
    if old_store_anchor not in engine:
        raise SystemExit("missing MDK quarantine store anchor")
    engine = engine.replace(old_store_anchor, new_store_anchor, 1)

old_property = '''    private var prematureEOFRecoveryActive = false\n    private var abnormalMediaRecoveryLevel = 0\n'''
new_property = '''    private var prematureEOFRecoveryActive = false\n    private var abnormalMediaRecoveryLevel = 0\n    private var nativeQuarantineActive = false\n'''
if new_property not in engine:
    if old_property not in engine:
        raise SystemExit("missing native quarantine property anchor")
    engine = engine.replace(old_property, new_property, 1)

engine = engine.replace('''        configureRenderer(renderer)''', '''        configureRenderer(renderer, generation: 0)''', 1)

old_configure = '''    private func configureRenderer(_ renderer: PlayerMetalLayerRenderer) {\n        renderer.onFrameSubmitted = { [weak self] result in\n            DispatchQueue.main.async { [weak self] in self?.recordRenderedFrame(result) }\n        }\n        renderer.onRenderCompleted = { elapsedMs in\n            guard elapsedMs >= 250 else { return }\n            DiagnosticsLogger.shared.playback("MDKNativeIsolation", "operation=render completedMs=\\(String(format: \"%.1f\", elapsedMs)) mainThread=false")\n        }\n    }\n'''
new_configure = '''    private func configureRenderer(_ renderer: PlayerMetalLayerRenderer, generation rendererGeneration: Int) {\n        renderer.onFrameSubmitted = { [weak self, weak renderer] result in\n            DispatchQueue.main.async { [weak self, weak renderer] in\n                guard let self, let renderer, rendererGeneration == self.generation, self.renderer === renderer else {\n                    DiagnosticsLogger.shared.playback("MDKNativeIsolation", "operation=discard-stale-render-callback callbackGeneration=\\(rendererGeneration) action=no-state-mutation")\n                    return\n                }\n                self.recordRenderedFrame(result)\n            }\n        }\n        renderer.onRenderCompleted = { [weak self, weak renderer] elapsedMs in\n            guard let self, let renderer, rendererGeneration == self.generation, self.renderer === renderer, elapsedMs >= 250 else { return }\n            DiagnosticsLogger.shared.playback("MDKNativeIsolation", "operation=render completedMs=\\(String(format: \"%.1f\", elapsedMs)) generation=\\(rendererGeneration) mainThread=false")\n        }\n    }\n'''
if new_configure not in engine:
    if old_configure not in engine:
        raise SystemExit("missing renderer generation anchor")
    engine = engine.replace(old_configure, new_configure, 1)

engine = engine.replace('''        configureRenderer(newRenderer)''', '''        configureRenderer(newRenderer, generation: currentGeneration)''', 1)

old_render_timeout = '''        hasRenderedValidFrame = false\n        let message = "MDK native isolation render timeout"\n        DiagnosticsLogger.shared.playback("MDKNativeIsolation", "operation=render timeoutMs=\\(Int(age * 1_000)) mainResponsive=true action=quarantine-engine")\n        onSnapshot?(PlayerSnapshot(position: lastNativePosition, duration: lastNativeDuration, isPlaying: false, isBuffering: false, waitingReason: "MDK 渲染线程未响应", errorMessage: message))\n'''
new_render_timeout = '''        hasRenderedValidFrame = false\n        nativeQuarantineActive = true\n        let message = "MDK native isolation render timeout"\n        DiagnosticsLogger.shared.playback("MDKNativeIsolation", "operation=render timeoutMs=\\(Int(age * 1_000)) generation=\\(generation) mainResponsive=true action=quarantine-engine-switch-mpv")\n        onSnapshot?(PlayerSnapshot(position: lastNativePosition, duration: lastNativeDuration, isPlaying: false, isBuffering: false, waitingReason: "MDK 渲染线程未响应", errorMessage: message))\n'''
if new_render_timeout not in engine:
    if old_render_timeout not in engine:
        raise SystemExit("missing render timeout quarantine anchor")
    engine = engine.replace(old_render_timeout, new_render_timeout, 1)

old_wedge = '''    private func recoverWedgedSeek(reason: String, fallbackTarget: Double, playerGeneration: Int) {\n        guard playerGeneration == generation, player != nil else { return }\n        let recoveryTarget = latestDesiredTarget(fallback: fallbackTarget)\n        DiagnosticsLogger.shared.playback("MDKSeekWedge", "reason=\\(reason) active=\\(activeNativeSeek?.id ?? -1) queued=\\(queuedLatestSeek?.id ?? -1) latestTarget=\\(String(format: \"%.3f\", recoveryTarget)) action=rebuild-player-at-latest-target")\n        transportHTTPServer?.resetClientStreams(reason: "mdk-seek-wedge-\\(reason)")\n        activeNativeSeek = nil\n        queuedLatestSeek = nil\n        reload(at: recoveryTarget)\n    }\n'''
new_wedge = '''    private func recoverWedgedSeek(reason: String, fallbackTarget: Double, playerGeneration: Int) {\n        guard playerGeneration == generation, player != nil else { return }\n        let recoveryTarget = latestDesiredTarget(fallback: fallbackTarget)\n        let nativeUnresponsive = reason.contains("timeout") || reason.contains("callback-without-new-frame")\n        if nativeUnresponsive {\n            nativeQuarantineActive = true\n            activeNativeSeek = nil\n            queuedLatestSeek = nil\n            pendingSeekResume = nil\n            seekBufferingGraceStartedAt = nil\n            seekBufferingGraceID = nil\n            seekBufferingGraceTarget = nil\n            hasRenderedValidFrame = false\n            let message = "MDK native isolation seek wedge"\n            DiagnosticsLogger.shared.playback("MDKSeekWedge", "reason=\\(reason) generation=\\(playerGeneration) latestTarget=\\(String(format: \"%.3f\", recoveryTarget)) action=quarantine-engine-switch-mpv sameProcessMDKRebuild=false")\n            onSnapshot?(PlayerSnapshot(position: recoveryTarget, duration: max(lastNativeDuration, source.mediaSource.durationSeconds ?? 0), isPlaying: false, isBuffering: false, errorMessage: message))\n            return\n        }\n        DiagnosticsLogger.shared.playback("MDKSeekWedge", "reason=\\(reason) active=\\(activeNativeSeek?.id ?? -1) queued=\\(queuedLatestSeek?.id ?? -1) latestTarget=\\(String(format: \"%.3f\", recoveryTarget)) action=rebuild-responsive-mdk-generation")\n        transportHTTPServer?.resetClientStreams(reason: "mdk-seek-recovery-\\(reason)")\n        activeNativeSeek = nil\n        queuedLatestSeek = nil\n        reload(at: recoveryTarget)\n    }\n'''
if new_wedge not in engine:
    if old_wedge not in engine:
        raise SystemExit("missing seek wedge recovery anchor")
    engine = engine.replace(old_wedge, new_wedge, 1)

old_teardown = '''        let oldRenderer = renderer\n        oldRenderer.detach()\n        guard let oldPlayer = takePlayer() else { return }\n        let teardownStartedAt = CACurrentMediaTime()\n        DiagnosticsLogger.shared.playback("MDKTeardown", "phase=ui-detached generation=\\(generation) activeSeek=\\(activeSeekID ?? -1) action=isolated-native-stop mainResponsive=true")\n        DispatchQueue.global(qos: .utility).async {\n            oldRenderer.invalidateNative(oldPlayer)\n            oldPlayer.state = .Stopped\n            let elapsed = (CACurrentMediaTime() - teardownStartedAt) * 1_000\n            DiagnosticsLogger.shared.playback("MDKTeardown", "phase=native-stop-finished ms=\\(String(format: \"%.1f\", elapsed)) activeSeek=\\(activeSeekID ?? -1) mainThread=false")\n        }\n'''
new_teardown = '''        let oldRenderer = renderer\n        oldRenderer.detach()\n        guard let oldPlayer = takePlayer() else { nativeQuarantineActive = false; return }\n        if nativeQuarantineActive {\n            nativeQuarantineActive = false\n            MDKNativeQuarantineStore.shared.retain(oldPlayer, oldRenderer)\n            DiagnosticsLogger.shared.playback("MDKTeardown", "phase=ui-detached generation=\\(generation) activeSeek=\\(activeSeekID ?? -1) action=quarantine-retain-skip-native-stop mainResponsive=true")\n            return\n        }\n        let teardownStartedAt = CACurrentMediaTime()\n        DiagnosticsLogger.shared.playback("MDKTeardown", "phase=ui-detached generation=\\(generation) activeSeek=\\(activeSeekID ?? -1) action=isolated-native-stop mainResponsive=true")\n        DispatchQueue.global(qos: .utility).async {\n            oldRenderer.invalidateNative(oldPlayer)\n            oldPlayer.state = .Stopped\n            let elapsed = (CACurrentMediaTime() - teardownStartedAt) * 1_000\n            DiagnosticsLogger.shared.playback("MDKTeardown", "phase=native-stop-finished ms=\\(String(format: \"%.1f\", elapsed)) activeSeek=\\(activeSeekID ?? -1) mainThread=false")\n        }\n'''
if new_teardown not in engine:
    if old_teardown not in engine:
        raise SystemExit("missing teardown quarantine anchor")
    engine = engine.replace(old_teardown, new_teardown, 1)

engine_path.write_text(engine)

renderer_path = Path("MDKLab/SwiftMDKOnePlayer/Sources/swift-mdk/MetalLayerRenderer.swift")
renderer = renderer_path.read_text()

old_context = '''        private let lock = NSLock()\n        private var drawable: CAMetalDrawable?\n\n        init(layer: CAMetalLayer) { self.layer = layer }\n\n        func acquireTexture() -> MTLTexture? {\n            guard let next = layer.nextDrawable() else { return nil }\n            lock.lock()\n            drawable = next\n            lock.unlock()\n            return next.texture\n        }\n'''
new_context = '''        private let lock = NSLock()\n        private var drawable: CAMetalDrawable?\n        private var enabled = true\n\n        init(layer: CAMetalLayer) { self.layer = layer }\n\n        func setEnabled(_ value: Bool) {\n            lock.lock()\n            enabled = value\n            if !value { drawable = nil }\n            lock.unlock()\n        }\n\n        func acquireTexture() -> MTLTexture? {\n            lock.lock()\n            let allowed = enabled\n            lock.unlock()\n            guard allowed, let next = layer.nextDrawable() else { return nil }\n            lock.lock()\n            guard enabled else { lock.unlock(); return nil }\n            drawable = next\n            lock.unlock()\n            return next.texture\n        }\n'''
if new_context not in renderer:
    if old_context not in renderer:
        raise SystemExit("missing Metal render context anchor")
    renderer = renderer.replace(old_context, new_context, 1)

old_bind = '''        lock.lock()\n        self.player = player\n        active = true\n        renderScheduled = false\n        renderPending = false\n        lock.unlock()\n'''
new_bind = '''        context.setEnabled(true)\n        lock.lock()\n        self.player = player\n        active = true\n        renderScheduled = false\n        renderPending = false\n        lock.unlock()\n'''
if new_bind not in renderer:
    if old_bind not in renderer:
        raise SystemExit("missing renderer bind anchor")
    renderer = renderer.replace(old_bind, new_bind, 1)

old_detach = '''    public func detach() {\n        lock.lock()\n        active = false\n        player = nil\n        renderPending = false\n        lock.unlock()\n        context.clearDrawable()\n    }\n'''
new_detach = '''    public func detach() {\n        lock.lock()\n        active = false\n        player = nil\n        renderPending = false\n        lock.unlock()\n        context.setEnabled(false)\n        context.clearDrawable()\n    }\n'''
if new_detach not in renderer:
    if old_detach not in renderer:
        raise SystemExit("missing renderer detach anchor")
    renderer = renderer.replace(old_detach, new_detach, 1)

old_render = '''    private func render(_ player: Player) {\n        let startedAt = CACurrentMediaTime()\n        let result = player.renderVideo(vid: self)\n        if let drawable = context.takeDrawable(), let buffer = commandQueue.makeCommandBuffer() {\n            buffer.present(drawable)\n            buffer.commit()\n        }\n        onFrameSubmitted?(result)\n        onRenderCompleted?((CACurrentMediaTime() - startedAt) * 1_000)\n\n        var scheduleAgain = false\n        lock.lock()\n        if active, self.player === player, renderPending {\n            renderPending = false\n            scheduleAgain = true\n        } else {\n            renderScheduled = false\n            renderPending = false\n        }\n        lock.unlock()\n        if scheduleAgain { renderQueue.async { [weak self, player] in self?.render(player) } }\n    }\n'''
new_render = '''    private func render(_ player: Player) {\n        let startedAt = CACurrentMediaTime()\n        let result = player.renderVideo(vid: self)\n        lock.lock()\n        let shouldSubmit = active && self.player === player\n        lock.unlock()\n        if shouldSubmit {\n            if let drawable = context.takeDrawable(), let buffer = commandQueue.makeCommandBuffer() {\n                buffer.present(drawable)\n                buffer.commit()\n            }\n            onFrameSubmitted?(result)\n            onRenderCompleted?((CACurrentMediaTime() - startedAt) * 1_000)\n        } else {\n            context.clearDrawable()\n        }\n\n        var scheduleAgain = false\n        lock.lock()\n        if active, self.player === player, renderPending {\n            renderPending = false\n            scheduleAgain = true\n        } else {\n            renderScheduled = false\n            renderPending = false\n        }\n        lock.unlock()\n        if scheduleAgain { renderQueue.async { [weak self, player] in self?.render(player) } }\n    }\n'''
if new_render not in renderer:
    if old_render not in renderer:
        raise SystemExit("missing renderer stale submit anchor")
    renderer = renderer.replace(old_render, new_render, 1)

renderer_path.write_text(renderer)

replace_all_exact("project.mdklab.yml", 'MARKETING_VERSION: "0.13.24"', 'MARKETING_VERSION: "0.13.25"', expected=2)
replace_all_exact("project.mdklab.yml", 'CURRENT_PROJECT_VERSION: "91"', 'CURRENT_PROJECT_VERSION: "92"', expected=2)
replace_once("Sources/Core/AppIdentity.swift", 'sourceVersion = "0.13.24"', 'sourceVersion = "0.13.25"')
replace_once("Sources/Core/AppIdentity.swift", '?? "0.13.24"', '?? "0.13.25"')

print("Build92 materialized: native wedge quarantine + generation-safe renderer callbacks")
