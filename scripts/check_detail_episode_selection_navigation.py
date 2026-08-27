from pathlib import Path

root = Path(__file__).resolve().parents[1]
detail = (root / "Sources/UI/EmbyMediaDetailView.swift").read_text()
episode_scroll_control = (root / "Sources/UI/EmbyDetailEpisodeScrollControl.swift").read_text()
picker = (root / "Sources/UI/EmbyEpisodePickerView.swift").read_text()
shared_navigation = (root / "Sources/UI/EmbySharedImageAndNavigation.swift").read_text()
project = (root / "project.yml").read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def block(text: str, start: str, end: str) -> str:
    start_index = text.index(start)
    end_index = text.index(end, start_index)
    return text[start_index:end_index]


preview = block(detail, "    private func episodePreviewCard(_ episode: LibraryItem) -> some View {", "    private var seasonsSection: some View {")
picker_row = block(picker, "    private func episodeRow(_ episode: LibraryItem) -> some View {", "    private func formatDuration(_ seconds: Double) -> String {")
range_selection = block(detail, "    func selectEpisodeRange(_ offset: Int) {", "    func selectEpisode(_ episode: LibraryItem) {")
initial_selection = block(detail, "    private func applyInitialEpisodeSelection() {", "    private func storeWarmPresentation() {")
summary = block(detail, "    var selectedEpisodeSelectionSummary: String? {", "    var visiblePeople: [EmbyPerson] {")
range_jump = block(detail, "    private func jumpToEpisodeRange(_ range: EmbyEpisodeRange, proxy: ScrollViewProxy) {", "    private func episodePreviewCard(_ episode: LibraryItem) -> some View {")

require('return Button { model.selectEpisode(episode) } label:' in preview, "detail episode card must select only")
require('model.play(episode)' not in preview, "detail episode card must not directly start playback")
require('Button { Task { await model.play(playableItem) } }' in detail, "detail primary play button must remain the playback action")
require('selectedEpisodeSelectionSummary' in detail, "detail must expose selected episode summary")
require('return displayEpisodeTitle(episode)' in summary, "selected episode summary must reuse the exact card title formatter")
require('第 \(number) 集 · \(trimmed)' not in summary, "selected episode summary must not maintain a second title format")
require('selectedEpisodeRangeOffset = (offset / 10) * 10' in detail, "explicit episode selection must keep the range pill aligned")
require('selectedEpisodeID = episode(at: normalized)?.id' in range_selection, "range jump must select the first episode in the target range")
require('selectedEpisodeID = nil' not in range_selection, "range jump must not clear the selected episode")
require('@StateObject private var episodeScrollController = EmbyDetailEpisodeScrollController()' in detail, "detail must retain one episode-row native scroll controller")
require('.background(EmbyDetailEpisodeNativeScrollProbe(controller: episodeScrollController))' in detail, "episode row must attach the native scroll probe")
require('episodeScrollController.stopDeceleration()' in range_jump, "range jump must stop native episode-row deceleration")
require(range_jump.index('episodeScrollController.stopDeceleration()') < range_jump.index('model.selectEpisodeRange(range.startOffset)'), "deceleration must stop before range selection executes")
require('guard let scrollView, scrollView.isDecelerating else { return false }' in episode_scroll_control, "native stop must be scoped to actual deceleration")
require('scrollView.setContentOffset(scrollView.contentOffset, animated: false)' in episode_scroll_control, "native stop must freeze at the current horizontal content offset")
require('let resumeEpisode = episodes.first(where: { $0.playbackProgress > 0.001 && !$0.isPlayed })' in initial_selection, "detail entry must prefer the resumable episode")
require('guard let target = requestedEpisode ?? resumeEpisode ?? episodes.first else { return }' in initial_selection, "detail entry must fall back to the canonical first episode")
require('selectedEpisodeID = target.id' in initial_selection, "detail entry must visibly select its default episode")
require('episodeScrollTargetID = target.id' in initial_selection, "detail entry must scroll the selected default episode into view")
require('Text(model.selectedEpisodeSelectionSummary ?? " ")' in detail, "selected episode summary must render above episode cards")
require('.font(.system(size: 12, weight: .medium))' in detail, "selected episode summary must stay visually small")
require('Binding(get: { showAllEpisodes ? nil : model.selectedSource }, set: { model.selectedSource = $0 })' in detail, "detail playback presenter must be gated while full episode picker is active")
require('.fullScreenCover(item: detailPlaybackSourceBinding)' in detail, "detail must keep its normal player presentation route")
require('@Environment(\\.presentationMode)' not in picker, "episode picker must not own pop/dismiss for playback")
require('presentationMode.wrappedValue.dismiss()' not in picker_row, "episode picker playback must not dismiss the picker")
require('Task.sleep' not in picker_row, "episode picker playback must not use the old fixed delay")
require('return Button { model.selectEpisode(episode); Task { await model.play(episode) } } label:' in picker_row, "episode picker must select and play from the existing model")
require('.fullScreenCover(item: $model.selectedSource)' in picker, "visible episode picker must present the shared selected source")
require('initialEpisodeID: episode.id' in shared_navigation, "favorite/episode-to-series initial selection route must remain")
require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "deployment target must remain iOS 15.0")
print("Detail episode selection/navigation checks passed")
