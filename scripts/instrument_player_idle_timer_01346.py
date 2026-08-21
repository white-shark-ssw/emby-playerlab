from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"missing patch anchor in {path}: {old[:260]!r}")
    p.write_text(text.replace(old, new, 1))


player_path = "Sources/UI/PlayerScreen.swift"
identity_path = "Sources/Core/AppIdentity.swift"

# Build113 identity. Build112 materialization runs before this script.
replace_once(identity_path, 'sourceVersion = "0.13.45"', 'sourceVersion = "0.13.46"')

# Keep the display awake for the full lifetime of the visible player screen.
replace_once(
    player_path,
    '''        .onAppear {\n            originalScreenBrightness = UIScreen.main.brightness\n''',
    '''        .onAppear {\n            setPlaybackIdleTimerDisabled(true, reason: "player-appear")\n            originalScreenBrightness = UIScreen.main.brightness\n''',
)
replace_once(
    player_path,
    '''        .onDisappear {\n            controlsHideWorkItem?.cancel()\n''',
    '''        .onDisappear {\n            setPlaybackIdleTimerDisabled(false, reason: "player-disappear")\n            controlsHideWorkItem?.cancel()\n''',
)

# Background restores normal system idle behavior. Returning to an active player
# explicitly re-arms the idle timer guard in case iOS reset application state.
replace_once(
    player_path,
    '''        case .background:\n            resetTransientInteractions(reason: "background")\n''',
    '''        case .background:\n            setPlaybackIdleTimerDisabled(false, reason: "scene-background")\n            resetTransientInteractions(reason: "background")\n''',
)
replace_once(
    player_path,
    '''        case .active:\n            updateIndependentBrightnessForPlaybackContext()\n''',
    '''        case .active:\n            setPlaybackIdleTimerDisabled(true, reason: "scene-active")\n            updateIndependentBrightnessForPlaybackContext()\n''',
)

replace_once(
    player_path,
    '''    private func activeWindowScene() -> UIWindowScene? {\n''',
    '''    private func setPlaybackIdleTimerDisabled(_ disabled: Bool, reason: String) {\n        if UIApplication.shared.isIdleTimerDisabled != disabled { UIApplication.shared.isIdleTimerDisabled = disabled }\n        DiagnosticsLogger.shared.playback("PlayerIdleTimer", "disabled=\\(disabled) reason=\\(reason)")\n    }\n\n    private func activeWindowScene() -> UIWindowScene? {\n''',
)

player = Path(player_path).read_text()
identity = Path(identity_path).read_text()
assert 'setPlaybackIdleTimerDisabled(true, reason: "player-appear")' in player
assert 'setPlaybackIdleTimerDisabled(false, reason: "player-disappear")' in player
assert 'setPlaybackIdleTimerDisabled(false, reason: "scene-background")' in player
assert 'setPlaybackIdleTimerDisabled(true, reason: "scene-active")' in player
assert 'UIApplication.shared.isIdleTimerDisabled = disabled' in player
assert 'PlayerIdleTimer' in player
assert 'sourceVersion = "0.13.46"' in identity
assert 'iOS: "15.0"' in Path("project.mdklab.yml").read_text()
print("Build113 player idle timer guard materialized")
