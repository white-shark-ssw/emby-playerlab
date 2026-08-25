from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label} source match count={count}")
    return text.replace(old, new, 1)


detail_path = Path("Sources/UI/EmbyMediaDetailView.swift")
text = detail_path.read_text()
text = replace_once(
    text,
    "    func selectEpisodeRange(_ offset: Int) { selectedEpisodeRangeOffset = max(0, offset); selectedEpisodeID = nil; episodeScrollTargetID = nil }\n",
    "    func selectEpisodeRange(_ offset: Int) {\n        let normalized = max(0, offset)\n        selectedEpisodeRangeOffset = normalized\n        selectedEpisodeID = episode(at: normalized)?.id\n        episodeScrollTargetID = nil\n    }\n",
    "selectEpisodeRange",
)
text = replace_once(
    text,
    """    private func applyInitialEpisodeSelection() {
        guard isSeries, !episodes.isEmpty else { return }
        if let initialEpisodeID, let requestedEpisode = episodes.first(where: { $0.id == initialEpisodeID }), let season = seasonNumber(for: requestedEpisode) {
            selectedSeason = season
            selectedEpisodeID = requestedEpisode.id
            if let offset = selectedSeasonEpisodes.firstIndex(where: { $0.id == requestedEpisode.id }) { selectedEpisodeRangeOffset = (offset / 10) * 10 }
            episodeScrollTargetID = requestedEpisode.id
        } else if let playable = primaryPlayableItem, let season = seasonNumber(for: playable) {
            selectedEpisodeID = nil
            selectedSeason = season
            if let offset = selectedSeasonEpisodes.firstIndex(where: { $0.id == playable.id }) { selectedEpisodeRangeOffset = (offset / 10) * 10 }
        } else {
            selectedEpisodeID = nil
            selectedSeason = seasonNumbers.first
            selectedEpisodeRangeOffset = 0
        }
    }
""",
    """    private func applyInitialEpisodeSelection() {
        guard isSeries, !episodes.isEmpty else { return }
        let resumeEpisode = episodes.first(where: { $0.playbackProgress > 0.001 && !$0.isPlayed })
        let requestedEpisode = initialEpisodeID.flatMap { requestedID in episodes.first(where: { $0.id == requestedID }) }
        guard let target = requestedEpisode ?? resumeEpisode ?? episodes.first else { return }
        selectedSeason = seasonNumber(for: target)
        selectedEpisodeID = target.id
        if let offset = selectedSeasonEpisodes.firstIndex(where: { $0.id == target.id }) { selectedEpisodeRangeOffset = (offset / 10) * 10 }
        else { selectedEpisodeRangeOffset = 0 }
        episodeScrollTargetID = target.id
    }
""",
    "applyInitialEpisodeSelection",
)
detail_path.write_text(text)

identity_path = Path("Sources/Core/AppIdentity.swift")
identity = identity_path.read_text()
identity = replace_once(identity, 'sourceVersion = "0.14.21"', 'sourceVersion = "0.14.22"', "sourceVersion")
identity = replace_once(identity, '?? "0.14.21"', '?? "0.14.22"', "fallback version")
identity_path.write_text(identity)

check_path = Path("scripts/check_detail_episode_selection_navigation.py")
check = check_path.read_text()
check = replace_once(
    check,
    'preview = block(detail, "    private func episodePreviewCard(_ episode: LibraryItem) -> some View {", "    private var seasonsSection: some View {")\npicker_row = block(picker, "    private func episodeRow(_ episode: LibraryItem) -> some View {", "    private func formatDuration(_ seconds: Double) -> String {")\n',
    'preview = block(detail, "    private func episodePreviewCard(_ episode: LibraryItem) -> some View {", "    private var seasonsSection: some View {")\npicker_row = block(picker, "    private func episodeRow(_ episode: LibraryItem) -> some View {", "    private func formatDuration(_ seconds: Double) -> String {")\nrange_selection = block(detail, "    func selectEpisodeRange(_ offset: Int) {", "    func selectEpisode(_ episode: LibraryItem) {")\ninitial_selection = block(detail, "    private func applyInitialEpisodeSelection() {", "    private func storeWarmPresentation() {")\n',
    "contract blocks",
)
check = replace_once(
    check,
    'require(\'selectedEpisodeRangeOffset = (offset / 10) * 10\' in detail, "explicit episode selection must keep the range pill aligned")\n',
    'require(\'selectedEpisodeRangeOffset = (offset / 10) * 10\' in detail, "explicit episode selection must keep the range pill aligned")\nrequire(\'selectedEpisodeID = episode(at: normalized)?.id\' in range_selection, "range jump must select the first episode in the target range")\nrequire(\'selectedEpisodeID = nil\' not in range_selection, "range jump must not clear the selected episode")\nrequire(\'let resumeEpisode = episodes.first(where: { $0.playbackProgress > 0.001 && !$0.isPlayed })\' in initial_selection, "detail entry must prefer the resumable episode")\nrequire(\'guard let target = requestedEpisode ?? resumeEpisode ?? episodes.first else { return }\' in initial_selection, "detail entry must fall back to the canonical first episode")\nrequire(\'selectedEpisodeID = target.id\' in initial_selection, "detail entry must visibly select its default episode")\nrequire(\'episodeScrollTargetID = target.id\' in initial_selection, "detail entry must scroll the selected default episode into view")\n',
    "contract assertions",
)
check_path.write_text(check)

changelog = Path("docs/changelog/CHANGELOG_v0_14_22_build189.md")
changelog.write_text("""# OnePlayer 0.14.22 / Build189

## Detail default episode selection follow-up

- Real-device Build188 feedback showed two selection-state gaps: entering a series did not visibly select the resume/default episode, and tapping a quick 10-episode jump cleared the selected episode/title.
- Series detail entry now selects the existing resumable episode when Emby exposes a nonzero playback position; if no resumable episode exists, it selects the canonical first episode. Explicit `initialEpisodeID` still has highest priority.
- The selected default episode also becomes the existing horizontal scroll target, so its blue outline/title are visible on entry.
- Tapping a quick episode-range button now selects the first episode in that range instead of clearing `selectedEpisodeID`; the blue outline, compact selected-episode title and main Play/Resume target remain coherent.
- No Player/Transport/Cache/PiP, canonical episode ordering, detail performance cache, or iOS deployment behavior is changed.

Evidence at changelog creation: code written only; CI/IPA/real-device follow-up pending.
""")
