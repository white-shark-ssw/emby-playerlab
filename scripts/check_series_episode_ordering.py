from pathlib import Path

api = Path("Sources/Networking/EmbyAPIClient.swift").read_text()
project = Path("project.yml").read_text()

start = api.index("    func seriesEpisodes(seriesId: String")
end = api.index("\n    func seriesSeasons", start)
series_episodes = api[start:end]

assert 'guard let userId else { throw EmbyAPIError.missingSession }' in series_episodes
assert 'send(path: "Shows/\\(seriesId)/Episodes", method: "GET", query: query)' in series_episodes
assert 'URLQueryItem(name: "UserId", value: userId)' in series_episodes
assert 'URLQueryItem(name: "StartIndex", value: String(startIndex))' in series_episodes
assert 'URLQueryItem(name: "Limit", value: String(safePageSize))' in series_episodes
assert 'SortBy' not in series_episodes
assert 'ParentIndexNumber,IndexNumber' not in series_episodes
assert 'libraryItems(parentId: seriesId' not in series_episodes
assert 'return deduplicated(all)' in series_episodes
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project

print("canonical series episode ordering checks passed")
