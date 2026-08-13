from pathlib import Path
p = Path('Sources/UI/EmbyMediaDetailView.swift')
text = p.read_text()
old = '''        let selectedCount = selectedSeason.map { season in episodes.reduce(0) { $1.parentIndexNumber == season ? $0 + 1 : $0 } } ?? episodes.count
        let unmatchedCount = selectedSeason.map { season in episodes.reduce(0) { $1.parentIndexNumber == season ? $0 : $0 + 1 } } ?? 0
        let nilIndexCount = episodes.reduce(0) { $1.indexNumber == nil ? $0 + 1 : $0 }
        let wrongSeriesCount = episodes.reduce(0) { episode in
            guard let episodeSeriesID = episode.seriesId else { return $0 }
            return episodeSeriesID == seriesID ? $0 : $0 + 1
        }
'''
new = '''        let selectedCount = selectedSeason.map { season in episodes.reduce(0) { subtotal, episode in episode.parentIndexNumber == season ? subtotal + 1 : subtotal } } ?? episodes.count
        let unmatchedCount = selectedSeason.map { season in episodes.reduce(0) { subtotal, episode in episode.parentIndexNumber == season ? subtotal : subtotal + 1 } } ?? 0
        let nilIndexCount = episodes.reduce(0) { subtotal, episode in episode.indexNumber == nil ? subtotal + 1 : subtotal }
        let wrongSeriesCount = episodes.reduce(0) { subtotal, episode in
            guard let episodeSeriesID = episode.seriesId else { return subtotal }
            return episodeSeriesID == seriesID ? subtotal : subtotal + 1
        }
'''
if text.count(old) != 1:
    raise SystemExit(f'reduce block match count={text.count(old)}')
p.write_text(text.replace(old, new, 1))
