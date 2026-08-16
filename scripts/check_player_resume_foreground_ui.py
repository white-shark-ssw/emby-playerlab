from pathlib import Path

root = Path(__file__).resolve().parents[1]
player = (root / "Sources/Player/PlayerController.swift").read_text()
transport = (root / "Sources/Transport/UnifiedMediaTransportSession.swift").read_text()
orientation = (root / "Sources/App/AppOrientationCoordinator.swift").read_text()
screen = (root / "Sources/UI/PlayerScreen.swift").read_text()
panels = (root / "Sources/UI/PlayerFloatingPanelViews.swift").read_text()
controls = (root / "Sources/UI/PlayerControlPanelViews.swift").read_text()
rate = (root / "Sources/Player/PlaybackRateBridge.swift").read_text()
mpv = (root / "Sources/Player/MPVPlayerEngine.swift").read_text()

checks = {
    "resume playback advancement confirms transport head": "confirmInitialResumePlayback" in player and "confirmInitialResumePlayback" in transport,
    "resume confirmation does not use time to byte math": "byteGuess=disabled" in transport,
    "foreground restores previous player orientation": "foreground-restore" in orientation and "backgroundPlayerOrientation" in orientation,
    "floating panels use frosted material": "UIVisualEffectView" in panels and "UIBlurEffect" in panels,
    "speed panel exposes 8x and 0.15x": "8.0" in panels and "0.15" in panels,
    "playback rate bridge accepts 8x and 0.15x": "min(8" in rate and "max(0.15" in rate,
    "mpv accepts 8x and 0.15x": "min(8" in mpv and "max(0.15" in mpv,
    "player base-rate path accepts 8x and 0.15x": "min(8" in screen and "max(0.15" in screen,
    "bottom controls are icon only": "Text(title)" not in controls.split("struct PlayerBottomFunctionBar", 1)[1].split("struct PlayerControlPanelSheet", 1)[0],
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit("player resume/foreground/ui regression: " + "; ".join(failed))
print("player resume/foreground/ui regression: OK")
