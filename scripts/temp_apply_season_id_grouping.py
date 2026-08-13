from pathlib import Path

path = Path("Sources/UI/EmbyMediaDetailView.swift")
text = path.read_text()

old = '''    var seasonNumbers: [Int] {
        let values = Set(episodes.compactMap(\\.parentIndexNumber) + seasons.compactMap(\\.indexNumber))
        return values.sorted()
    }

    var selectedSeasonEpisodes: [LibraryItem] {
        guard let season = selectedSeason else { return episodes }
        return episodes.filter { $0.parentIndexNumber == season }
    }
'''
new = '''    var seasonNumbers: [Int] {
        let explicitSeasons = Set(seasons.compactMap(\\.indexNumber))
        if !explicitSeasons.isEmpty { return explicitSeasons.sorted() }
        return Set(episodes.compactMap(\\.parentIndexNumber)).sorted()
    }

    var selectedSeasonEpisodes: [LibraryItem] {
        guard let season = selectedSeason else { return episodes }
        return episodes.filter { episodeBelongsToSeason($0, season: season) }
    }
'''
if old not in text: raise SystemExit("seasonNumbers/selectedSeasonEpisodes block not found")
text = text.replace(old, new, 1)

old = '''    func seasonItem(number: Int) -> LibraryItem? { seasons.first { $0.indexNumber == number } }
    func seasonEpisodeCount(_ season: Int) -> Int { episodes.reduce(0) { $1.parentIndexNumber == season ? $0 + 1 : $0 } }
    func episode(at offset: Int) -> LibraryItem? { selectedSeasonEpisodes.indices.contains(offset) ? selectedSeasonEpisodes[offset] : nil }
'''
new = '''    func seasonItem(number: Int) -> LibraryItem? { seasons.first { $0.indexNumber == number } }

    private func seasonNumber(for episode: LibraryItem) -> Int? {
        if let seasonID = episode.seasonId, let season = seasons.first(where: { $0.id == seasonID }), let number = season.indexNumber { return number }
        return episode.parentIndexNumber
    }

    private func episodeBelongsToSeason(_ episode: LibraryItem, season number: Int) -> Bool {
        if let episodeSeasonID = episode.seasonId, let season = seasonItem(number: number) { return episodeSeasonID == season.id }
        return episode.parentIndexNumber == number
    }

    func seasonEpisodeCount(_ season: Int) -> Int { episodes.reduce(0) { episodeBelongsToSeason($1, season: season) ? $0 + 1 : $0 } }
    func episode(at offset: Int) -> LibraryItem? { selectedSeasonEpisodes.indices.contains(offset) ? selectedSeasonEpisodes[offset] : nil }
'''
if old not in text: raise SystemExit("season helper block not found")
text = text.replace(old, new, 1)

old = '''                if let playable = primaryPlayableItem, let season = playable.parentIndexNumber {
                    selectedSeason = season
                    if let offset = selectedSeasonEpisodes.firstIndex(where: { $0.id == playable.id }) { selectedEpisodeRangeOffset = (offset / 10) * 10 }
                } else if selectedSeason == nil {
                    selectedSeason = seasonNumbers.first
                }
'''
new = '''                if let playable = primaryPlayableItem, let season = seasonNumber(for: playable) {
                    selectedSeason = season
                    if let offset = selectedSeasonEpisodes.firstIndex(where: { $0.id == playable.id }) { selectedEpisodeRangeOffset = (offset / 10) * 10 }
                } else if selectedSeason == nil {
                    selectedSeason = seasonNumbers.first
                }
'''
if old not in text: raise SystemExit("playable season selection block not found")
text = text.replace(old, new, 1)

old = '''        let selectedCount = selectedSeason.map { season in episodes.reduce(0) { subtotal, episode in episode.parentIndexNumber == season ? subtotal + 1 : subtotal } } ?? episodes.count
        let unmatchedCount = selectedSeason.map { season in episodes.reduce(0) { subtotal, episode in episode.parentIndexNumber == season ? subtotal : subtotal + 1 } } ?? 0
'''
new = '''        let selectedCount = selectedSeason.map { season in episodes.reduce(0) { subtotal, episode in episodeBelongsToSeason(episode, season: season) ? subtotal + 1 : subtotal } } ?? episodes.count
        let unmatchedCount = selectedSeason.map { season in episodes.reduce(0) { subtotal, episode in episodeBelongsToSeason(episode, season: season) ? subtotal : subtotal + 1 } } ?? 0
'''
if old not in text: raise SystemExit("diagnostic selected-count block not found")
text = text.replace(old, new, 1)
path.write_text(text)

checker = Path("scripts/check_season_id_episode_grouping.py")
checker.write_text('''from pathlib import Path\n\ndetail = Path("Sources/UI/EmbyMediaDetailView.swift").read_text()\nproject = Path("project.yml").read_text()\n\nassert "let explicitSeasons = Set(seasons.compactMap(\\\\.indexNumber))" in detail\nassert "if !explicitSeasons.isEmpty { return explicitSeasons.sorted() }" in detail\nassert "return Set(episodes.compactMap(\\\\.parentIndexNumber)).sorted()" in detail\nassert "private func seasonNumber(for episode: LibraryItem) -> Int?" in detail\nassert "if let seasonID = episode.seasonId, let season = seasons.first(where: { $0.id == seasonID }), let number = season.indexNumber { return number }" in detail\nassert "private func episodeBelongsToSeason(_ episode: LibraryItem, season number: Int) -> Bool" in detail\nassert "if let episodeSeasonID = episode.seasonId, let season = seasonItem(number: number) { return episodeSeasonID == season.id }" in detail\nassert "return episodes.filter { episodeBelongsToSeason($0, season: season) }" in detail\nassert "func seasonEpisodeCount(_ season: Int) -> Int { episodes.reduce(0) { episodeBelongsToSeason($1, season: season) ? $0 + 1 : $0 } }" in detail\nassert "if let playable = primaryPlayableItem, let season = seasonNumber(for: playable)" in detail\nassert "return episodes.filter { $0.parentIndexNumber == season }" not in detail\nassert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project\nprint("SeasonId episode grouping checks passed")\n''')
