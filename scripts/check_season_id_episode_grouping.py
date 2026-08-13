from pathlib import Path

detail = Path("Sources/UI/EmbyMediaDetailView.swift").read_text()
project = Path("project.yml").read_text()

assert "let explicitSeasons = Set(seasons.compactMap(\\.indexNumber))" in detail
assert "if !explicitSeasons.isEmpty { return explicitSeasons.sorted() }" in detail
assert "return Set(episodes.compactMap(\\.parentIndexNumber)).sorted()" in detail
assert "private func seasonNumber(for episode: LibraryItem) -> Int?" in detail
assert "if let seasonID = episode.seasonId, let season = seasons.first(where: { $0.id == seasonID }), let number = season.indexNumber { return number }" in detail
assert "private func episodeBelongsToSeason(_ episode: LibraryItem, season number: Int) -> Bool" in detail
assert "if let episodeSeasonID = episode.seasonId, let season = seasonItem(number: number) { return episodeSeasonID == season.id }" in detail
assert "return episodes.filter { episodeBelongsToSeason($0, season: season) }" in detail
assert "func seasonEpisodeCount(_ season: Int) -> Int { episodes.reduce(0) { episodeBelongsToSeason($1, season: season) ? $0 + 1 : $0 } }" in detail
assert "if let playable = primaryPlayableItem, let season = seasonNumber(for: playable)" in detail
assert "return episodes.filter { $0.parentIndexNumber == season }" not in detail
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project
print("SeasonId episode grouping checks passed")
