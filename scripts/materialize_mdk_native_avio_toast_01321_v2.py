from pathlib import Path

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


project = PROJECT.read_text()
if 'MARKETING_VERSION: "0.13.21"' in project and 'CURRENT_PROJECT_VERSION: "88"' in project:
    print("Build88 already materialized")
    raise SystemExit(0)
if project.count('MARKETING_VERSION: "0.13.20"') != 2 or project.count('CURRENT_PROJECT_VERSION: "87"') != 2:
    raise SystemExit("Build88 requires validated Build87 baseline")

engine = ENGINE.read_text()
engine = replace_once(engine, '''    private var didInstallLogHandler = false\n    private var prematureEOFRecoveryActive = false\n''', '''    private var didInstallLogHandler = false\n    private var didConfigureGlobalIO = false\n    private var prematureEOFRecoveryActive = false\n''', "MDK IO configuration state")
engine = replace_once(engine, '''        lastNativeEnded = false\n        installMDKLoggingIfNeeded()\n\n        guard let sharedTransportSession else {\n''', '''        lastNativeEnded = false\n        installMDKLoggingIfNeeded()\n        configureMDKIOIfNeeded()\n\n        guard let sharedTransportSession else {\n''', "MDK IO configure before player creation")
engine = replace_once(engine, '''    private func installMDKLoggingIfNeeded() {\n''', '''    private func configureMDKIOIfNeeded() {\n        guard !didConfigureGlobalIO else { return }\n        didConfigureGlobalIO = true\n        swift_mdk.setGlobalOption(name: "io.avio", value: 1)\n        DiagnosticsLogger.shared.playback("MDKIO", "mode=ffmpeg-native-avio option=io.avio value=1 customAVIO=false transport=unified-localhost-ab")\n    }\n\n    private func installMDKLoggingIfNeeded() {\n''', "MDK native AVIO helper")
ENGINE.write_text(engine)

controller = CONTROLLER.read_text()
controller = replace_once(controller, '''    @Published private(set) var prematureEOFMessage: String?\n    @Published private(set) var stallMessage: String?\n    @Published private(set) var engineKind: PlayerEngineKind\n''', '''    @Published private(set) var prematureEOFMessage: String?\n    @Published private(set) var stallMessage: String?\n    @Published private(set) var engineSwitchNotice: String?\n    @Published private(set) var engineKind: PlayerEngineKind\n''', "engine switch notice published state")
controller = replace_once(controller, '''    private var transportMetricsTask: Task<Void, Never>?\n    private var engineSwitchTask: Task<Void, Never>?\n    private var startupFallbackTask: Task<Void, Never>?\n''', '''    private var transportMetricsTask: Task<Void, Never>?\n    private var engineSwitchTask: Task<Void, Never>?\n    private var engineSwitchNoticeTask: Task<Void, Never>?\n    private var startupFallbackTask: Task<Void, Never>?\n''', "engine switch notice task")
controller = replace_once(controller, '''        engineSwitchTask?.cancel()\n        engineSwitchTask = nil\n        startupFallbackTask?.cancel()\n''', '''        engineSwitchTask?.cancel()\n        engineSwitchTask = nil\n        engineSwitchNoticeTask?.cancel()\n        engineSwitchNoticeTask = nil\n        engineSwitchNotice = nil\n        startupFallbackTask?.cancel()\n''', "engine switch notice stop cleanup")
controller = replace_once(controller, '''        stallMessage = "正在自动切换到 \\(kind.title)：\\(reason)"\n''', '''        if kind == .mpv, reason != "用户切换" {\n            stallMessage = nil\n            showAutomaticMPVSwitchNotice()\n        } else {\n            stallMessage = reason == "用户切换" ? nil : "正在自动切换到 \\(kind.title)：\\(reason)"\n        }\n''', "automatic MPV switch compact notice")
controller = replace_once(controller, '''    private func handleEngineError(_ message: String) {\n''', '''    private func showAutomaticMPVSwitchNotice() {\n        engineSwitchNoticeTask?.cancel()\n        engineSwitchNotice = "自动切换为 MPV 高兼容引擎"\n        engineSwitchNoticeTask = Task { [weak self] in\n            try? await Task.sleep(nanoseconds: 2_000_000_000)\n            guard !Task.isCancelled else { return }\n            self?.engineSwitchNotice = nil\n        }\n    }\n\n    private func handleEngineError(_ message: String) {\n''', "automatic MPV switch 2s helper")
CONTROLLER.write_text(controller)

screen = SCREEN.read_text()
screen = replace_once(screen, '''                if controller.snapshot.isBuffering { bufferingIndicator }\n                statusMessages\n\n                if playbackSettingsPresented {\n''', '''                if controller.snapshot.isBuffering { bufferingIndicator }\n                statusMessages\n                if let message = controller.engineSwitchNotice { automaticEngineSwitchToast(message) }\n\n                if playbackSettingsPresented {\n''', "automatic switch toast overlay")
screen = replace_once(screen, '''    private func adjustmentHUDView(_ state: AdjustmentHUDState) -> some View { PlayerAdjustmentRulerHUD(adjustment: state.adjustment, value: state.value) }\n''', '''    private func automaticEngineSwitchToast(_ message: String) -> some View {\n        VStack {\n            Text(message)\n                .font(.system(size: 14, weight: .semibold))\n                .foregroundColor(.white)\n                .lineLimit(1)\n                .fixedSize(horizontal: true, vertical: false)\n                .padding(.horizontal, 16)\n                .padding(.vertical, 10)\n                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial))\n                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 0.5))\n            Spacer()\n        }\n        .padding(.top, 64)\n        .allowsHitTesting(false)\n        .zIndex(30)\n    }\n\n    private func adjustmentHUDView(_ state: AdjustmentHUDState) -> some View { PlayerAdjustmentRulerHUD(adjustment: state.adjustment, value: state.value) }\n''', "automatic switch glass toast")
SCREEN.write_text(screen)

project = project.replace('MARKETING_VERSION: "0.13.20"', 'MARKETING_VERSION: "0.13.21"').replace('CURRENT_PROJECT_VERSION: "87"', 'CURRENT_PROJECT_VERSION: "88"')
PROJECT.write_text(project)

identity = IDENTITY.read_text()
identity = replace_once(identity, 'static let sourceVersion = "0.13.20"', 'static let sourceVersion = "0.13.21"', "source version")
identity = replace_once(identity, 'as? String ?? "0.13.20"', 'as? String ?? "0.13.21"', "bundle version fallback")
IDENTITY.write_text(identity)

print("Build88 materialized: MDK io.avio=1 A/B + compact 2-second MPV fallback toast")
