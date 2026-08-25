from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label} source match count={count}")
    return text.replace(old, new, 1)


detail_path = Path("Sources/UI/EmbyMediaDetailView.swift")
detail = detail_path.read_text()
old_summary = '''    var selectedEpisodeSelectionSummary: String? {
        guard let selectedEpisodeID, let episode = episodes.first(where: { $0.id == selectedEpisodeID }) else { return nil }
        let trimmed = episode.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = episode.indexNumber ?? selectedSeasonEpisodes.firstIndex(where: { $0.id == episode.id }).map { $0 + 1 }
        guard let number, number > 0 else { return trimmed.isEmpty ? nil : trimmed }
        if trimmed.isEmpty || isGenericEpisodeName(trimmed, number: number) { return "第 \\(number) 集" }
        return "第 \\(number) 集 · \\(trimmed)"
    }
'''
new_summary = '''    var selectedEpisodeSelectionSummary: String? {
        guard let selectedEpisodeID, let episode = episodes.first(where: { $0.id == selectedEpisodeID }) else { return nil }
        return displayEpisodeTitle(episode)
    }
'''
detail = replace_once(detail, old_summary, new_summary, "selectedEpisodeSelectionSummary")
detail_path.write_text(detail)

identity_path = Path("Sources/Core/AppIdentity.swift")
identity = identity_path.read_text()
identity = replace_once(identity, 'sourceVersion = "0.14.23"', 'sourceVersion = "0.14.24"', "sourceVersion")
identity = replace_once(identity, '?? "0.14.23"', '?? "0.14.24"', "fallbackVersion")
identity_path.write_text(identity)

check_path = Path("scripts/check_detail_episode_selection_navigation.py")
check = check_path.read_text()
check = replace_once(
    check,
    'initial_selection = block(detail, "    private func applyInitialEpisodeSelection() {", "    private func storeWarmPresentation() {")\n',
    'initial_selection = block(detail, "    private func applyInitialEpisodeSelection() {", "    private func storeWarmPresentation() {")\nsummary = block(detail, "    var selectedEpisodeSelectionSummary: String? {", "    var visiblePeople: [EmbyPerson] {")\n',
    "summary contract block",
)
check = replace_once(
    check,
    'require(\'selectedEpisodeSelectionSummary\' in detail, "detail must expose selected episode summary")\n',
    'require(\'selectedEpisodeSelectionSummary\' in detail, "detail must expose selected episode summary")\nrequire(\'return displayEpisodeTitle(episode)\' in summary, "selected episode summary must reuse the exact card title formatter")\nrequire(\'第 \\(number) 集 · \\(trimmed)\' not in summary, "selected episode summary must not maintain a second title format")\n',
    "summary contract assertions",
)
check_path.write_text(check)

Path("docs/changelog/CHANGELOG_v0_14_24_build191.md").write_text('''# OnePlayer 0.14.24 / Build191

## Selected episode summary display unification

- Build190 real-device screenshots confirmed the selected-episode state/range behavior works, but the compact summary could differ from the episode card title because it maintained a separate formatting path.
- The compact selected-episode summary now directly reuses `displayEpisodeTitle(episode)`, the exact formatter already used by the horizontal episode card.
- Therefore the summary and selected card title are intentionally identical for every episode, including Emby generic names such as `10.第十集` / `20.第二十集` and real episode titles.
- No selection state, playback action, canonical ordering, full-picker return path, Player/Transport/Cache/PiP, detail performance cache or iOS deployment behavior is changed.

Evidence at changelog creation: code written; CI/IPA/real-device follow-up pending.
''')
