from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTROLLER = ROOT / "Sources/Player/PlayerController.swift"
SCREEN = ROOT / "Sources/UI/PlayerScreen.swift"
PROJECT = ROOT / "project.mdklab.yml"
IDENTITY = ROOT / "Sources/Core/AppIdentity.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, got {count}")
    return text.replace(old, new, 1)

project = PROJECT.read_text()
if 'MARKETING_VERSION: "0.13.22"' in project and 'CURRENT_PROJECT_VERSION: "89"' in project:
    print("Build89 already materialized")
    raise SystemExit(0)
if project.count('MARKETING_VERSION: "0.13.21"') != 2 or project.count('CURRENT_PROJECT_VERSION: "88"') != 2:
    raise SystemExit("Build89 requires validated Build88 baseline")

controller = CONTROLLER.read_text()
controller = replace_once(
    controller,
    '''    var mpvDisplayLayer: CAMetalLayer? {\n        if let engine = engine as? MPVPlayerEngine { return engine.displayLayer }\n        if let engine = engine as? KTVMPVPlayerEngine { return engine.displayLayer }\n        return nil\n    }\n\n''',
    '''    var mpvDisplayLayer: CAMetalLayer? {\n        if let engine = engine as? MPVPlayerEngine { return engine.displayLayer }\n        if let engine = engine as? KTVMPVPlayerEngine { return engine.displayLayer }\n        return nil\n    }\n\n    private var mdkDirectHTTPABActive: Bool {\n        #if MDK_LAB\n        return engineKind == .ksAVIO\n        #else\n        return false\n        #endif\n    }\n\n''',
    "direct MDK A/B state")
controller = replace_once(
    controller,
    '''        if startupTransportPrewarmTask == nil, let session = transportContext?.session {\n''',
    '''        if !mdkDirectHTTPABActive, startupTransportPrewarmTask == nil, let session = transportContext?.session {\n''',
    "skip UnifiedTransport startup prewarm during direct MDK")
controller = replace_once(
    controller,
    '''            if let session = self.transportContext?.session {\n                await session.releaseStartupPrewarm(initialPosition: startPosition, duration: duration)\n                guard !Task.isCancelled, self.started else { return }\n            }\n''',
    '''            if !self.mdkDirectHTTPABActive, let session = self.transportContext?.session {\n                await session.releaseStartupPrewarm(initialPosition: startPosition, duration: duration)\n                guard !Task.isCancelled, self.started else { return }\n            }\n''',
    "skip UnifiedTransport release during direct MDK")
controller = replace_once(
    controller,
    '''        if let session = transportContext?.session { Task { await session.setPlaybackAdvancing(true) } }\n''',
    '''        if !mdkDirectHTTPABActive, let session = transportContext?.session { Task { await session.setPlaybackAdvancing(true) } }\n''',
    "skip UnifiedTransport playback advance during direct MDK startup")
controller = replace_once(
    controller,
    '''            if let session = transportContext?.session { Task { await session.setPlaybackAdvancing(false) } }\n            Task { await client.reportProgress(source: source, position: snapshot.position, paused: true, eventName: "Pause") }\n''',
    '''            if !mdkDirectHTTPABActive, let session = transportContext?.session { Task { await session.setPlaybackAdvancing(false) } }\n            Task { await client.reportProgress(source: source, position: snapshot.position, paused: true, eventName: "Pause") }\n''',
    "skip UnifiedTransport pause during direct MDK")
controller = replace_once(
    controller,
    '''            if let session = transportContext?.session { Task { await session.setPlaybackAdvancing(true) } }\n            Task { await client.reportProgress(source: source, position: snapshot.position, paused: false, eventName: "Unpause") }\n''',
    '''            if !mdkDirectHTTPABActive, let session = transportContext?.session { Task { await session.setPlaybackAdvancing(true) } }\n            Task { await client.reportProgress(source: source, position: snapshot.position, paused: false, eventName: "Unpause") }\n''',
    "skip UnifiedTransport resume during direct MDK")
controller = replace_once(
    controller,
    '''            if let transportContext = self.transportContext { await transportContext.quiesceConsumers() }\n            guard !Task.isCancelled, self.started, self.engineSwitchSerial == serial else { return }\n            EngineTransitionBreadcrumb.record(stage: "transport-quiesced", from: previousKind, to: kind, position: resumePosition, reason: reason)\n            try? await Task.sleep(nanoseconds: 250_000_000)\n''',
    '''            if let transportContext = self.transportContext { await transportContext.quiesceConsumers() }\n            guard !Task.isCancelled, self.started, self.engineSwitchSerial == serial else { return }\n            EngineTransitionBreadcrumb.record(stage: "transport-quiesced", from: previousKind, to: kind, position: resumePosition, reason: reason)\n            #if MDK_LAB\n            if previousKind == .ksAVIO, kind == .mpv, let session = self.transportContext?.session {\n                let ready = await session.prewarmStartupResolve()\n                guard !Task.isCancelled, self.started, self.engineSwitchSerial == serial else { return }\n                await session.releaseStartupPrewarm(initialPosition: resumePosition, duration: self.effectiveDuration)\n                await session.setPlaybackAdvancing(shouldPlay)\n                DiagnosticsLogger.shared.playback("MDKDirectAB", "fallbackTransportWarm ready=\\(ready) resume=\\(String(format: \"%.3f\", resumePosition)) action=handoff-to-unified-mpv")\n            }\n            #endif\n            try? await Task.sleep(nanoseconds: 250_000_000)\n''',
    "warm UnifiedTransport only at MDK to MPV handoff")
controller = replace_once(
    controller,
    '''        case .ksAVIO:\n            #if canImport(KSPlayer)\n            return KSAVIOPlayerEngine(source: source, client: client, configuration: configuration, sharedTransportSession: transportContext?.session, ktvCacheSession: nil)\n            #else\n''',
    '''        case .ksAVIO:\n            #if canImport(KSPlayer)\n            DiagnosticsLogger.shared.playback("MDKDirectAB", "mode=direct-http302 sharedTransportPassed=false unifiedTransportReservedForFallback=true nasMediaProxy=false")\n            return KSAVIOPlayerEngine(source: source, client: client, configuration: configuration, sharedTransportSession: nil, ktvCacheSession: nil)\n            #else\n''',
    "MDK direct HTTP engine construction")
controller = replace_once(
    controller,
    '''    private func reportPlaybackClockToTransportIfNeeded(_ value: PlayerSnapshot) {\n        guard let session = transportContext?.session, value.position.isFinite else { return }\n''',
    '''    private func reportPlaybackClockToTransportIfNeeded(_ value: PlayerSnapshot) {\n        guard !mdkDirectHTTPABActive, let session = transportContext?.session, value.position.isFinite else { return }\n''',
    "skip UnifiedTransport playback clock during direct MDK")
controller = replace_once(
    controller,
    '''        if let session = transportContext?.session { Task { await session.confirmInitialResumePlayback() } }\n''',
    '''        if !mdkDirectHTTPABActive, let session = transportContext?.session { Task { await session.confirmInitialResumePlayback() } }\n''',
    "skip UnifiedTransport resume confirmation during direct MDK")
CONTROLLER.write_text(controller)

screen = SCREEN.read_text()
screen = replace_once(
    screen,
    '''            if let message = controller.prematureEOFMessage { statusBanner(title: "疑似提前结束", message: message, color: .red) }\n''',
    '''            // Premature EOF stays diagnostic-only while automatic fallback is enabled.\n''',
    "hide premature EOF red banner")
SCREEN.write_text(screen)

project = project.replace('MARKETING_VERSION: "0.13.21"', 'MARKETING_VERSION: "0.13.22"').replace('CURRENT_PROJECT_VERSION: "88"', 'CURRENT_PROJECT_VERSION: "89"')
PROJECT.write_text(project)

identity = IDENTITY.read_text()
identity = replace_once(identity, 'static let sourceVersion = "0.13.21"', 'static let sourceVersion = "0.13.22"', "source version")
identity = replace_once(identity, 'as? String ?? "0.13.21"', 'as? String ?? "0.13.22"', "bundle version fallback")
IDENTITY.write_text(identity)

print("Build89 materialized: hide premature EOF UI + MDK direct Emby/302 HTTP A/B; UnifiedTransport reserved for MPV fallback")
