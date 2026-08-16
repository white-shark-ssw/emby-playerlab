from pathlib import Path

root = Path(__file__).resolve().parents[1]
player = (root / "Sources/Player/PlayerController.swift").read_text()
transport = (root / "Sources/Transport/UnifiedMediaTransportSession.swift").read_text()
transport_protocol = (root / "Sources/Transport/TransportDataSession.swift").read_text()
resume_authority = (root / "Sources/Transport/UnifiedResumeAuthority.swift").read_text()
orientation = (root / "Sources/App/AppOrientationCoordinator.swift").read_text()
presentation_gate = (root / "Sources/Player/PlayerSurfacePresentationGate.swift").read_text()
renderer = (root / "Sources/Player/RendererLayoutCoordinator.swift").read_text()
mpv_surface = (root / "Sources/UI/MPVPlayerSurface.swift").read_text()
mpv_stream = (root / "Sources/Player/MPVUnifiedStreamBridge.swift").read_text()
screen = (root / "Sources/UI/PlayerScreen.swift").read_text()
panels = (root / "Sources/UI/PlayerFloatingPanelViews.swift").read_text()
controls = (root / "Sources/UI/PlayerControlPanelViews.swift").read_text()
rate = (root / "Sources/Player/PlaybackRateBridge.swift").read_text()
mpv = (root / "Sources/Player/MPVPlayerEngine.swift").read_text()

checks = {
    "resume playback advancement confirms transport head": "confirmInitialResumePlayback" in player and "confirmInitialResumePlayback" in transport,
    "resume authority accepts exact consumed bytes": "confirmConcretePlaybackByte" in transport_protocol and "exact-byte authority confirmed" in resume_authority,
    "mpv resume authority requires sustained concrete reads": "sustained playback-byte authority" in mpv_stream and "authorityMinimumReads = 3" in mpv_stream and "authorityMinimumSpanBytes" in mpv_stream,
    "resume confirmation does not use time to byte math": "byteGuess=disabled" in transport and "byteGuess=disabled" in resume_authority,
    "foreground restores previous player orientation before active presentation": "foreground-prepare" in orientation and "foreground-active" in orientation and "backgroundPlayerOrientation" in orientation,
    "foreground locks orientation while presentation is held": "lockedMask" in orientation and "PlayerSurfacePresentationGate.shared.hold" in orientation,
    "foreground release requires renderer acknowledgement": "requiresRendererAcknowledgement" in presentation_gate and "isHolding && foregroundReleaseArmed" in presentation_gate,
    "renderer snapshot derives target backing from plan and scale": "plan.surfaceFrame.width * scale" in renderer and "plan.surfaceFrame.height * scale" in renderer,
    "renderer snapshot identity excludes observed backing": "struct SnapshotKey" in renderer and "observedBackingWidth" not in renderer and "observedBackingHeight" not in renderer,
    "mpv surface reports mismatched geometry to coordinator": "if geometry != lastReportedGeometry" in mpv_surface and "onGeometrySettled?(geometry)" in mpv_surface,
    "mpv foreground release replays unchanged geometry": "foreground presentation replay" in mpv_surface and "lastReportedGeometry = nil" in mpv_surface and "gate.requiresRendererAcknowledgement" in mpv_surface,
    "mpv presentation cover does not hide renderer layer": "presentationCoverView" in mpv_surface and "displayLayer.isHidden = false" in mpv_surface,
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
