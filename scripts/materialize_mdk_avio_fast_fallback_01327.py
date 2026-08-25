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
    '''    private let prepareWatchdogSeconds: TimeInterval = 3.0\n    private let firstFrameWatchdogSeconds: TimeInterval = 4.0\n    private let endConfirmationSeconds: TimeInterval = 1.0\n''',
    '''    private let prepareWatchdogSeconds: TimeInterval = 3.0\n    private let firstFrameWatchdogSeconds: TimeInterval = 4.0\n    private let endConfirmationSeconds: TimeInterval = 1.0\n    private let renderWatchdogPollSeconds: TimeInterval = 0.25\n    private let renderWatchdogTimeoutSeconds: TimeInterval = 2.5\n    private let avioShortSeekSizeBytes = 2 * 1_048_576\n''',
)

replace_once(
    engine_path,
    '''    private func startRenderWatchdog() {\n        renderWatchdogTimer?.invalidate()\n        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.evaluateRenderLiveness() }\n        renderWatchdogTimer = timer\n        RunLoop.main.add(timer, forMode: .common)\n    }\n''',
    '''    private func startRenderWatchdog() {\n        renderWatchdogTimer?.invalidate()\n        let timer = Timer.scheduledTimer(withTimeInterval: renderWatchdogPollSeconds, repeats: true) { [weak self] _ in self?.evaluateRenderLiveness() }\n        renderWatchdogTimer = timer\n        RunLoop.main.add(timer, forMode: .common)\n    }\n''',
)

replace_once(
    engine_path,
    '''        let age = CACurrentMediaTime() - lastRenderedFrameAt\n        guard age >= 4 else { return }\n''',
    '''        let age = CACurrentMediaTime() - lastRenderedFrameAt\n        guard age >= renderWatchdogTimeoutSeconds else { return }\n''',
)

replace_once(
    engine_path,
    '''            guard abnormalMediaRecoveryLevel < 2 else {\n                DiagnosticsLogger.shared.playback("MDKCompat", "position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) status=0x\\(String(status, radix: 16)) level=\\(abnormalMediaRecoveryLevel) action=exhausted-mdk-generations")\n                onSnapshot?(PlayerSnapshot(position: position, duration: duration, isPlaying: false, isBuffering: false, waitingReason: "MDK 异常媒体恢复已用尽", errorMessage: "MDK abnormal media recovery exhausted"))\n                return\n            }\n''',
    '''            guard abnormalMediaRecoveryLevel < 2 else {\n                let message = "MDK abnormal media recovery exhausted"\n                DiagnosticsLogger.shared.playback("MDKCompat", "position=\\(String(format: \"%.3f\", position)) duration=\\(String(format: \"%.3f\", duration)) status=0x\\(String(status, radix: 16)) level=\\(abnormalMediaRecoveryLevel) action=exhausted-switch-mpv-immediate")\n                onSnapshot?(PlayerSnapshot(position: position, duration: duration, isPlaying: false, isBuffering: false, waitingReason: "MDK 异常媒体恢复已用尽", errorMessage: message))\n                return\n            }\n''',
)

replace_once(
    engine_path,
    '''            if compatLevel >= 2 {\n                player.setProperty(name: "avformat.err_detect", value: "ignore_err")\n                player.setProperty(name: "avformat.fflags", value: "+discardcorrupt")\n            }\n            let compatProfile = compatLevel == 0 ? "normal" : (compatLevel == 1 ? "fresh-player" : "software-tolerant")\n''',
    '''            player.setProperty(name: "avio.multiple_requests", value: "1")\n            player.setProperty(name: "avio.short_seek_size", value: String(avioShortSeekSizeBytes))\n            player.setProperty(name: "avio.reconnect", value: "1")\n            DiagnosticsLogger.shared.playback("MDKAVIO", "generation=\\(currentGeneration) multipleRequests=1 shortSeekSize=\\(avioShortSeekSizeBytes) reconnect=1 requestSize=unbounded transport=\\(transportMode)")\n            if compatLevel >= 2 {\n                player.setProperty(name: "avformat.err_detect", value: "ignore_err")\n                player.setProperty(name: "avformat.fflags", value: "+discardcorrupt")\n            }\n            let compatProfile = compatLevel == 0 ? "normal" : (compatLevel == 1 ? "fresh-player" : "software-tolerant")\n''',
)

orchestrator_path = "Sources/Player/PlaybackOrchestrator.swift"
replace_once(
    orchestrator_path,
    '''    func actionForEngineError(kind: PlayerEngineKind, message: String) -> PlaybackRecoveryAction? {\n        let normalized = message.lowercased()\n        if kind == .ksAVIO, normalized.contains("mdk native isolation"), automaticMode {\n            DiagnosticsLogger.shared.playback("Orchestrator", "engine error engine=\\(kind.title) failureIsolation=triggered action=switch-mpv error=\\(message)")\n            return .switchEngine(.mpv, reason: "MDK native worker 超时；主线程仍响应，受控切换到 MPV 高兼容引擎")\n        }\n        DiagnosticsLogger.shared.log("Orchestrator", "engine error engine=\\(kind.title) runtimeSwitch=disabled error=\\(message)")\n        return nil\n    }\n''',
    '''    func actionForEngineError(kind: PlayerEngineKind, message: String) -> PlaybackRecoveryAction? {\n        let normalized = message.lowercased()\n        if kind == .ksAVIO, automaticMode, normalized.contains("mdk native isolation") {\n            DiagnosticsLogger.shared.playback("Orchestrator", "engine error engine=\\(kind.title) failureIsolation=triggered action=switch-mpv error=\\(message)")\n            return .switchEngine(.mpv, reason: "MDK native worker 超时；主线程仍响应，受控切换到 MPV 高兼容引擎")\n        }\n        if kind == .ksAVIO, automaticMode, normalized.contains("mdk abnormal media recovery exhausted") {\n            DiagnosticsLogger.shared.playback("Orchestrator", "engine error engine=\\(kind.title) recoveryExhausted=true action=switch-mpv-immediate error=\\(message)")\n            return .switchEngine(.mpv, reason: "MDK 异常媒体恢复已用尽；立即切换到 MPV 高兼容引擎")\n        }\n        DiagnosticsLogger.shared.log("Orchestrator", "engine error engine=\\(kind.title) runtimeSwitch=disabled error=\\(message)")\n        return nil\n    }\n''',
)

controller_path = "Sources/Player/PlayerController.swift"
replace_once(
    controller_path,
    '''            try? await Task.sleep(nanoseconds: 250_000_000)\n            guard !Task.isCancelled, self.started, self.engineSwitchSerial == serial else { return }\n''',
    '''            let settleNanoseconds: UInt64 = previousKind == .ksAVIO && kind == .mpv ? 50_000_000 : 250_000_000\n            DiagnosticsLogger.shared.playback("EngineTransition", "from=\\(previousKind.title) to=\\(kind.title) settleMs=\\(settleNanoseconds / 1_000_000) fastFallback=\\(previousKind == .ksAVIO && kind == .mpv)")\n            try? await Task.sleep(nanoseconds: settleNanoseconds)\n            guard !Task.isCancelled, self.started, self.engineSwitchSerial == serial else { return }\n''',
)

identity_path = "Sources/Core/AppIdentity.swift"
replace_once(identity_path, 'static let sourceVersion = "0.13.26"', 'static let sourceVersion = "0.13.27"')
replace_once(identity_path, '?? "0.13.26"', '?? "0.13.27"')

project_path = "project.mdklab.yml"
p = Path(project_path)
text = p.read_text()
if 'MARKETING_VERSION: "0.13.27"' not in text:
    if text.count('MARKETING_VERSION: "0.13.26"') != 2:
        raise SystemExit('unexpected MARKETING_VERSION anchor count')
    text = text.replace('MARKETING_VERSION: "0.13.26"', 'MARKETING_VERSION: "0.13.27"')
if 'CURRENT_PROJECT_VERSION: "94"' not in text:
    if text.count('CURRENT_PROJECT_VERSION: "93"') != 2:
        raise SystemExit('unexpected CURRENT_PROJECT_VERSION anchor count')
    text = text.replace('CURRENT_PROJECT_VERSION: "93"', 'CURRENT_PROJECT_VERSION: "94"')
p.write_text(text)

print('Build94 MDK AVIO + fast fallback materialized')
