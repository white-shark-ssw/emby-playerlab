from pathlib import Path

source = Path("Sources/UI/PlayerEpisodeSelection.swift").read_text()

checks = {
    "player loads real seasons": "seriesSeasons(seriesId: requestedSeriesID)" in source,
    "player stores real seasons": "@Published private(set) var seasons: [LibraryItem] = []" in source,
    "explicit season numbers win": "let explicitSeasons = Set(coordinator.seasons.compactMap(\\.indexNumber))" in source,
    "season id maps to real season": "if let seasonID = episode.seasonId, let season = coordinator.seasons.first(where: { $0.id == seasonID }), let number = season.indexNumber" in source,
    "season membership uses season id": "if let episodeSeasonID = episode.seasonId, let season = seasonItem(number: number) { return episodeSeasonID == season.id }" in source,
    "parent index remains fallback": "return episode.parentIndexNumber == number" in source,
    "picker uses membership helper": "return coordinator.episodes.filter { episodeBelongsToSeason($0, season: season) }" in source,
    "old parent-only picker filter removed": "return coordinator.episodes.filter { $0.parentIndexNumber == season }" not in source,
    "auto next still uses canonical episodes": "return await playbackSource(for: episodes[nextIndex], reason: \"trusted-natural-end\")" in source,
}

for name, ok in checks.items():
    print(("PASS" if ok else "FAIL"), name)
    if not ok:
        raise SystemExit(name)

season = {"id": "152156", "index": 1}
episodes = [{"season_id": "152156", "parent_index": None} for _ in range(979)] + [{"season_id": "152156", "parent_index": 1}]

def belongs(episode, number, seasons):
    matched = next((item for item in seasons if item["index"] == number), None)
    if episode["season_id"] is not None and matched is not None:
        return episode["season_id"] == matched["id"]
    return episode["parent_index"] == number

assert sum(belongs(episode, 1, [season]) for episode in episodes) == 980
assert sum(belongs(episode, 1, []) for episode in episodes) == 1
print("PASS representative 980-episode SeasonId grouping")
