from pathlib import Path

p = Path("Sources/UI/EmbyMediaDetailView.swift")
text = p.read_text()
old = text
text = text.replace('episode.indexNumber.map(String.init) ?? \\"nil\\"', 'episode.indexNumber.map(String.init) ?? "nil"')
text = text.replace('episode.parentIndexNumber.map(String.init) ?? \\"nil\\"', 'episode.parentIndexNumber.map(String.init) ?? "nil"')
text = text.replace('episode.seasonId ?? \\"nil\\"', 'episode.seasonId ?? "nil"')
text = text.replace('episode.parentId ?? \\"nil\\"', 'episode.parentId ?? "nil"')
text = text.replace('episode.seriesId ?? \\"nil\\"', 'episode.seriesId ?? "nil"')
text = text.replace('selectedSeason.map(String.init) ?? \\"nil\\"', 'selectedSeason.map(String.init) ?? "nil"')
if text == old:
    raise SystemExit("no diagnostic quote escapes replaced")
p.write_text(text)
