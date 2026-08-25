from pathlib import Path

DETAIL = Path("Sources/UI/EmbyMediaDetailView.swift")
APP_ID = Path("Sources/Core/AppIdentity.swift")
PROJECT = Path("project.mdklab.yml")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f"missing expected pattern: {label}")
    return text.replace(old, new, 1)


detail = DETAIL.read_text()
detail = replace_once(
    detail,
    '.fullScreenCover(item: $model.selectedSource) { source in PlayerScreen(source: source, client: client, preference: .automatic) }',
    '.fullScreenCover(item: $model.selectedSource, onDismiss: { Task { await model.refreshPlaybackUserDataAfterPlayerDismiss() } }) { source in PlayerScreen(source: source, client: client, preference: .automatic) }',
    'player cover onDismiss refresh',
)

anchor = '''    func refreshPlaybackUserData(itemID: String) async {\n'''
method = '''    func refreshPlaybackUserDataAfterPlayerDismiss() async {\n        let targetID = primaryPlayableItem?.id ?? item.id\n        DiagnosticsLogger.shared.log("EmbyDetail", "player dismissed; authoritative playback userdata refresh item=\\(targetID) phase=immediate")\n        await refreshPlaybackUserData(itemID: targetID)\n        do { try await Task.sleep(nanoseconds: 400_000_000) } catch { return }\n        guard !Task.isCancelled else { return }\n        DiagnosticsLogger.shared.log("EmbyDetail", "player dismissed; authoritative playback userdata refresh item=\\(targetID) phase=convergence")\n        await refreshPlaybackUserData(itemID: targetID)\n    }\n\n'''
if method not in detail:
    if anchor not in detail:
        raise SystemExit('missing refreshPlaybackUserData anchor')
    detail = detail.replace(anchor, method + anchor, 1)
DETAIL.write_text(detail)

app_id = APP_ID.read_text()
app_id = app_id.replace('sourceVersion = "0.13.30"', 'sourceVersion = "0.13.31"')
app_id = app_id.replace('?? "0.13.30"', '?? "0.13.31"')
APP_ID.write_text(app_id)

project = PROJECT.read_text()
project = project.replace('MARKETING_VERSION: "0.13.30"', 'MARKETING_VERSION: "0.13.31"')
project = project.replace('CURRENT_PROJECT_VERSION: "97"', 'CURRENT_PROJECT_VERSION: "98"')
PROJECT.write_text(project)

print('Build98 materialized: detail dismiss refresh + Build97 MDK startup isolation baseline')
