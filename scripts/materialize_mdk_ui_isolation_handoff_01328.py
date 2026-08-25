from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"missing anchor in {path}: {old[:180]!r}")
    p.write_text(text.replace(old, new, 1))

engine_path = "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
replace_once(
    engine_path,
    '''    private var renderWatchdogTimer: Timer?\n    private var hasRenderedValidFrame = false\n''',
    '''    private var renderWatchdogTimer: Timer?\n    private let renderDispatchLock = NSLock()\n    private var renderDispatchPending = false\n    private var latestRenderResult: Double?\n    private let renderStateDispatchInterval: TimeInterval = 1.0 / 30.0\n    private var hasRenderedValidFrame = false\n''',
)

replace_once(
    engine_path,
    '''    private func configureRenderer(_ renderer: PlayerMetalLayerRenderer, generation rendererGeneration: Int) {\n        renderer.onFrameSubmitted = { [weak self, weak renderer] result in\n            DispatchQueue.main.async { [weak self, weak renderer] in\n                guard let self, let renderer, rendererGeneration == self.generation, self.renderer === renderer else {\n                    DiagnosticsLogger.shared.playback("MDKNativeIsolation", "operation=discard-stale-render-callback callbackGeneration=\\(rendererGeneration) action=no-state-mutation")\n                    return\n                }\n                self.recordRenderedFrame(result)\n            }\n        }\n''',
    '''    private func configureRenderer(_ renderer: PlayerMetalLayerRenderer, generation rendererGeneration: Int) {\n        renderer.onFrameSubmitted = { [weak self, weak renderer] result in\n            guard let self else { return }\n            self.renderDispatchLock.lock()\n            self.latestRenderResult = result\n            if self.renderDispatchPending { self.renderDispatchLock.unlock(); return }\n            self.renderDispatchPending = true\n            self.renderDispatchLock.unlock()\n            DispatchQueue.main.asyncAfter(deadline: .now() + self.renderStateDispatchInterval) { [weak self, weak renderer] in\n                guard let self else { return }\n                self.renderDispatchLock.lock()\n                let latest = self.latestRenderResult ?? result\n                self.latestRenderResult = nil\n                self.renderDispatchPending = false\n                self.renderDispatchLock.unlock()\n                guard let renderer, rendererGeneration == self.generation, self.renderer === renderer else {\n                    DiagnosticsLogger.shared.playback("MDKNativeIsolation", "operation=discard-stale-render-callback callbackGeneration=\\(rendererGeneration) action=no-state-mutation")\n                    return\n                }\n                self.recordRenderedFrame(latest)\n            }\n        }\n''',
)

replace_once(
    engine_path,
    '''            player.setProperty(name: "avio.multiple_requests", value: "1")\n            player.setProperty(name: "avio.short_seek_size", value: String(avioShortSeekSizeBytes))\n            player.setProperty(name: "avio.reconnect", value: "1")\n            DiagnosticsLogger.shared.playback("MDKAVIO", "generation=\\(currentGeneration) multipleRequests=1 shortSeekSize=\\(avioShortSeekSizeBytes) reconnect=1 requestSize=unbounded transport=\\(transportMode)")\n''',
    '''            player.setProperty(name: "avio.multiple_requests", value: "1")\n            player.setProperty(name: "avio.short_seek_size", value: String(avioShortSeekSizeBytes))\n            DiagnosticsLogger.shared.playback("MDKAVIO", "generation=\\(currentGeneration) multipleRequests=1 shortSeekSize=\\(avioShortSeekSizeBytes) reconnect=off-localhost requestSize=unbounded transport=\\(transportMode)")\n''',
)

replace_once(
    engine_path,
    '''        renderWatchdogTimer?.invalidate()\n        renderWatchdogTimer = nil\n        transportPrepareTask?.cancel()\n''',
    '''        renderWatchdogTimer?.invalidate()\n        renderWatchdogTimer = nil\n        renderDispatchLock.lock()\n        renderDispatchPending = false\n        latestRenderResult = nil\n        renderDispatchLock.unlock()\n        transportPrepareTask?.cancel()\n''',
)

controller_path = "Sources/Player/PlayerController.swift"
replace_once(
    controller_path,
    '''        let previousKind = engineKind\n        let previousEngine = engine\n        engineSwitchInProgress = true\n''',
    '''        let previousKind = engineKind\n        let previousEngine = engine\n        let fastMDKFallback = previousKind == .ksAVIO && kind == .mpv && reason != "用户切换"\n        engineSwitchInProgress = true\n''',
)

replace_once(
    controller_path,
    '''        engineSwitchTask?.cancel()\n        engineSwitchTask = Task { [weak self] in\n            guard let self else { return }\n            if let transportContext = self.transportContext { await transportContext.quiesceConsumers() }\n            guard !Task.isCancelled, self.started, self.engineSwitchSerial == serial else { return }\n            EngineTransitionBreadcrumb.record(stage: "transport-quiesced", from: previousKind, to: kind, position: resumePosition, reason: reason)\n            #if MDK_LAB\n            if previousKind == .ksAVIO, kind == .mpv, let session = self.transportContext?.session {\n                let ready = await session.prewarmStartupResolve()\n                guard !Task.isCancelled, self.started, self.engineSwitchSerial == serial else { return }\n                await session.releaseStartupPrewarm(initialPosition: resumePosition, duration: self.effectiveDuration)\n                await session.setPlaybackAdvancing(shouldPlay)\n                DiagnosticsLogger.shared.playback("MDKDirectAB", "fallbackTransportWarm ready=\\(ready) resume=\\(String(format: \"%.3f\", resumePosition)) action=handoff-to-unified-mpv")\n            }\n            #endif\n            let settleNanoseconds: UInt64 = previousKind == .ksAVIO && kind == .mpv ? 50_000_000 : 250_000_000\n            DiagnosticsLogger.shared.playback("EngineTransition", "from=\\(previousKind.title) to=\\(kind.title) settleMs=\\(settleNanoseconds / 1_000_000) fastFallback=\\(previousKind == .ksAVIO && kind == .mpv)")\n            try? await Task.sleep(nanoseconds: settleNanoseconds)\n            guard !Task.isCancelled, self.started, self.engineSwitchSerial == serial else { return }\n''',
    '''        engineSwitchTask?.cancel()\n        engineSwitchTask = Task { [weak self] in\n            guard let self else { return }\n            if fastMDKFallback {\n                EngineTransitionBreadcrumb.record(stage: "transport-preserved", from: previousKind, to: kind, position: resumePosition, reason: reason)\n                DiagnosticsLogger.shared.playback("EngineTransition", "from=\\(previousKind.title) to=\\(kind.title) transport=preserve-live-unified settleMs=0 fastFallback=true")\n            } else {\n                if let transportContext = self.transportContext { await transportContext.quiesceConsumers() }\n                guard !Task.isCancelled, self.started, self.engineSwitchSerial == serial else { return }\n                EngineTransitionBreadcrumb.record(stage: "transport-quiesced", from: previousKind, to: kind, position: resumePosition, reason: reason)\n                try? await Task.sleep(nanoseconds: 250_000_000)\n            }\n            guard !Task.isCancelled, self.started, self.engineSwitchSerial == serial else { return }\n''',
)

replace_once(
    controller_path,
    '''    private func handleEngineError(_ message: String) {\n        guard !engineSwitchInProgress, !engineTransitionAwaitingFirstSnapshot else { return }\n        if scheduleStartupCompatibilityFallbackIfNeeded(message: message) { return }\n        guard let action = orchestrator.actionForEngineError(kind: engineKind, message: message) else { return }\n        if case .switchEngine(let next, let reason) = action { stallMessage = "\\(engineKind.title) 发生错误，正在自动切换到 \\(next.title)。"; switchEngine(to: next, reason: reason) }\n    }\n''',
    '''    private func handleEngineError(_ message: String) {\n        guard !engineSwitchInProgress, !engineTransitionAwaitingFirstSnapshot else { return }\n        if scheduleStartupCompatibilityFallbackIfNeeded(message: message) { return }\n        guard let action = orchestrator.actionForEngineError(kind: engineKind, message: message) else { return }\n        if case .switchEngine(let next, let reason) = action {\n            if engineKind == .ksAVIO, next == .mpv, message.lowercased().contains("mdk native isolation") { MediaCompatibilityStore.markCompatibilityEngineRequired(itemId: source.itemId, reason: "mdk-native-isolation") }\n            stallMessage = "\\(engineKind.title) 发生错误，正在自动切换到 \\(next.title)。"\n            switchEngine(to: next, reason: reason)\n        }\n    }\n''',
)

identity_path = "Sources/Core/AppIdentity.swift"
replace_once(identity_path, 'static let sourceVersion = "0.13.27"', 'static let sourceVersion = "0.13.28"')
replace_once(identity_path, '?? "0.13.27"', '?? "0.13.28"')

project_path = "project.mdklab.yml"
p = Path(project_path)
text = p.read_text()
if 'MARKETING_VERSION: "0.13.28"' not in text:
    if text.count('MARKETING_VERSION: "0.13.27"') != 2: raise SystemExit('unexpected MARKETING_VERSION count')
    text = text.replace('MARKETING_VERSION: "0.13.27"', 'MARKETING_VERSION: "0.13.28"')
if 'CURRENT_PROJECT_VERSION: "95"' not in text:
    if text.count('CURRENT_PROJECT_VERSION: "94"') != 2: raise SystemExit('unexpected CURRENT_PROJECT_VERSION count')
    text = text.replace('CURRENT_PROJECT_VERSION: "94"', 'CURRENT_PROJECT_VERSION: "95"')
p.write_text(text)

print('Build95 MDK UI isolation + live transport handoff materialized')
