from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
CONTROLLER = ROOT / "Sources/Player/PlayerController.swift"
SCREEN = ROOT / "Sources/UI/PlayerScreen.swift"
PROJECT = ROOT / "project.mdklab.yml"
IDENTITY = ROOT / "Sources/Core/AppIdentity.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, got {count}")
    return text.replace(old, new, 1)


def regex_once(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"{label}: expected one regex match, got {count}")
    return updated


project = PROJECT.read_text()
if 'MARKETING_VERSION: "0.13.22"' in project and 'CURRENT_PROJECT_VERSION: "89"' in project:
    print("Build89 already materialized")
    raise SystemExit(0)
if project.count('MARKETING_VERSION: "0.13.21"') != 2 or project.count('CURRENT_PROJECT_VERSION: "88"') != 2:
    raise SystemExit("Build89 requires validated Build88 baseline")

engine = ENGINE.read_text()
engine = regex_once(
    engine,
    r'''        guard let sharedTransportSession else \{.*?\n    \}\n\n    func play''',
    r'''        let sharedTransportAvailable = sharedTransportSession != nil
        startMDKPlayer(url: url, headers: [:], preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition, generation: currentGeneration, transportMode: "direct-http302-native-avio")
        DiagnosticsLogger.shared.playback("MDKTransport", "mode=direct-http302-native-avio localhostBypassed=true sharedTransportAvailable=\(sharedTransportAvailable) requestHeaders=none nativeAVIO=true nasMediaProxy=false")
    }

    func play''',
    "MDK direct HTTP diagnostic transport")
ENGINE.write_text(engine)

controller = CONTROLLER.read_text()
controller = replace_once(
    controller,
    '''            if let session = self.transportContext?.session {\n                await session.releaseStartupPrewarm(initialPosition: startPosition, duration: duration)\n                guard !Task.isCancelled, self.started else { return }\n            }\n''',
    '''            if let session = self.transportContext?.session {\n                #if MDK_LAB\n                if self.engineKind == .ksAVIO {\n                    DiagnosticsLogger.shared.playback("MDKDirectHTTP", "phase=startup transportPrewarm=resolved-only action=hold-resolve-only-for-mdk-direct")\n                } else {\n                    await session.releaseStartupPrewarm(initialPosition: startPosition, duration: duration)\n                }\n                #else\n                await session.releaseStartupPrewarm(initialPosition: startPosition, duration: duration)\n                #endif\n                guard !Task.isCancelled, self.started else { return }\n            }\n''',
    "hold UnifiedTransport while MDK direct diagnostic runs")
controller = replace_once(
    controller,
    '''            if let transportContext = self.transportContext { await transportContext.quiesceConsumers() }\n            guard !Task.isCancelled, self.started, self.engineSwitchSerial == serial else { return }\n            EngineTransitionBreadcrumb.record(stage: "transport-quiesced", from: previousKind, to: kind, position: resumePosition, reason: reason)\n            try? await Task.sleep(nanoseconds: 250_000_000)\n''',
    r'''            if let transportContext = self.transportContext { await transportContext.quiesceConsumers() }
            guard !Task.isCancelled, self.started, self.engineSwitchSerial == serial else { return }
            EngineTransitionBreadcrumb.record(stage: "transport-quiesced", from: previousKind, to: kind, position: resumePosition, reason: reason)
            #if MDK_LAB
            if previousKind == .ksAVIO, kind == .mpv, let session = self.transportContext?.session {
                await session.releaseStartupPrewarm(initialPosition: resumePosition, duration: self.effectiveDuration)
                DiagnosticsLogger.shared.playback("MDKDirectHTTP", "phase=fallback position=\(String(format: "%.3f", resumePosition)) action=release-for-mpv-fallback")
            }
            #endif
            try? await Task.sleep(nanoseconds: 250_000_000)
''',
    "release UnifiedTransport for MPV fallback")
CONTROLLER.write_text(controller)

screen = SCREEN.read_text()
screen = replace_once(
    screen,
    '''            if let message = controller.prematureEOFMessage { statusBanner(title: "疑似提前结束", message: message, color: .red) }\n            if let message = controller.stallMessage { statusBanner(title: "播放停滞恢复", message: message, color: .orange) }\n''',
    '''            if let message = controller.stallMessage { statusBanner(title: "播放停滞恢复", message: message, color: .orange) }\n''',
    "hide premature EOF red banner from users")
SCREEN.write_text(screen)

project = project.replace('MARKETING_VERSION: "0.13.21"', 'MARKETING_VERSION: "0.13.22"').replace('CURRENT_PROJECT_VERSION: "88"', 'CURRENT_PROJECT_VERSION: "89"')
PROJECT.write_text(project)

identity = IDENTITY.read_text()
identity = replace_once(identity, 'static let sourceVersion = "0.13.21"', 'static let sourceVersion = "0.13.22"', "source version")
identity = replace_once(identity, 'as? String ?? "0.13.21"', 'as? String ?? "0.13.22"', "bundle version fallback")
IDENTITY.write_text(identity)

print("Build89 materialized: MDK native AVIO direct HTTP302 diagnostic + silent premature EOF UI")
