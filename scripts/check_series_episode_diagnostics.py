from pathlib import Path

models = Path("Sources/Models/EmbyModels.swift").read_text()
api = Path("Sources/Networking/EmbyAPIClient.swift").read_text()
detail = Path("Sources/UI/EmbyMediaDetailView.swift").read_text()
project = Path("project.yml").read_text()

assert 'let seasonId: String?' in models
assert 'let parentId: String?' in models
assert 'case seasonId = "SeasonId"' in models
assert 'case parentId = "ParentId"' in models
assert 'seasonId = try? container.decode(String.self, forKey: .seasonId)' in models
assert 'parentId = try? container.decode(String.self, forKey: .parentId)' in models
assert 'SeriesName,SeriesId,SeasonId,ParentId,IndexNumber,ParentIndexNumber' in api
assert 'DiagnosticsLogger.shared.log("EpisodeDiagnostic"' in detail
assert 'episodesTotal=' in detail and 'selectedCount=' in detail and 'unmatched=' in detail
assert 'parentIndex={' in detail
assert 'seasonId={' in detail
assert 'parentId={' in detail
assert 'sampleFirst[' in detail and 'sampleLast[' in detail
assert 'episodes.reduce(0) { subtotal, episode in' in detail
assert 'episodes.filter { $0.parentIndexNumber == season }' in detail
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project
print("series episode diagnostics checks passed")
