from pathlib import Path

root = Path(__file__).resolve().parents[1]
core = (root / "Sources/Core/EmbyUserDataChange.swift").read_text()
api = (root / "Sources/Networking/EmbyAPIClient.swift").read_text()
player = (root / "Sources/Player/PlayerController.swift").read_text()
detail = (root / "Sources/UI/EmbyMediaDetailView.swift").read_text()
home = (root / "Sources/UI/EmbyServerRootViewV3.swift").read_text()

checks = {
    "playback stop has explicit acknowledgement reason": "playbackStoppedReason" in core,
    "stopped report exposes success": "reportStopped(source: ResolvedPlaybackSource, position: Double) async -> Bool" in api,
    "player notifies only after stopped success": "let succeeded = await stoppedClient.reportStopped" in player and "guard succeeded else { return }" in player,
    "detail refreshes playback userdata": "refreshPlaybackUserData(itemID: itemID)" in detail and "func refreshPlaybackUserData(itemID: String) async" in detail,
    "home no longer removes active resume navigation source": "invalidateResumeItem" not in home and "model.markResumeDirty(itemID)" in home,
    "pull refresh is user initiated": ".refreshable { await model.refresh(userInitiated: true) }" in home,
    "menu refresh is user initiated": 'Label("刷新首页", systemImage: "arrow.clockwise")' in home and "model.refresh(userInitiated: true)" in home,
    "user refresh waits for active refresh": 'while isLoading { try? await Task.sleep(nanoseconds: 50_000_000) }' in home,
    "dirty resume refreshes on home reappear": "refreshResumeIfNeeded()" in home,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise SystemExit("resume refresh acknowledgement regression: " + "; ".join(failed))
print("resume refresh acknowledgement regression: OK")
