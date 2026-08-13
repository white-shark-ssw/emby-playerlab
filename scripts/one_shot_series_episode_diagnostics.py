from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, got {count}")
    return text.replace(old, new, 1)

models_path = Path("Sources/Models/EmbyModels.swift")
models = models_path.read_text()
models = replace_once(models, "    let seriesName: String?\n    let seriesId: String?\n    let indexNumber: Int?\n", "    let seriesName: String?\n    let seriesId: String?\n    let seasonId: String?\n    let parentId: String?\n    let indexNumber: Int?\n", "model properties")
models = replace_once(models, "        case seriesName = \"SeriesName\"\n        case seriesId = \"SeriesId\"\n        case indexNumber = \"IndexNumber\"\n", "        case seriesName = \"SeriesName\"\n        case seriesId = \"SeriesId\"\n        case seasonId = \"SeasonId\"\n        case parentId = \"ParentId\"\n        case indexNumber = \"IndexNumber\"\n", "model coding keys")
models = replace_once(models, "        seriesName = try? container.decode(String.self, forKey: .seriesName)\n        seriesId = try? container.decode(String.self, forKey: .seriesId)\n        indexNumber = try? container.decode(Int.self, forKey: .indexNumber)\n", "        seriesName = try? container.decode(String.self, forKey: .seriesName)\n        seriesId = try? container.decode(String.self, forKey: .seriesId)\n        seasonId = try? container.decode(String.self, forKey: .seasonId)\n        parentId = try? container.decode(String.self, forKey: .parentId)\n        indexNumber = try? container.decode(Int.self, forKey: .indexNumber)\n", "model decode")
models_path.write_text(models)

api_path = Path("Sources/Networking/EmbyAPIClient.swift")
api = api_path.read_text()
api = replace_once(api, "SeriesName,SeriesId,IndexNumber,ParentIndexNumber,ChildCount", "SeriesName,SeriesId,SeasonId,ParentId,IndexNumber,ParentIndexNumber,ChildCount", "browse fields")
api_path.write_text(api)

detail_path = Path("Sources/UI/EmbyMediaDetailView.swift")
detail = detail_path.read_text()
detail = replace_once(detail, "                } else if selectedSeason == nil {\n                    selectedSeason = seasonNumbers.first\n                }\n            }\n\n            await loadMediaMetadata(for: primaryPlayableItem)\n", "                } else if selectedSeason == nil {\n                    selectedSeason = seasonNumbers.first\n                }\n                logEpisodeDiagnostics(seriesID: refreshed.id)\n            }\n\n            await loadMediaMetadata(for: primaryPlayableItem)\n", "diagnostic call")
helper = r'''    private func logEpisodeDiagnostics(seriesID: String) {
        func countByOptionalInt(_ values: [Int?]) -> String {
            var counts: [String: Int] = [:]
            for value in values { counts[value.map(String.init) ?? "nil", default: 0] += 1 }
            return counts.sorted { lhs, rhs in
                if lhs.key == "nil" { return true }
                if rhs.key == "nil" { return false }
                return (Int(lhs.key) ?? Int.max) < (Int(rhs.key) ?? Int.max)
            }.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
        }

        func countByOptionalString(_ values: [String?]) -> String {
            var counts: [String: Int] = [:]
            for value in values { counts[value ?? "nil", default: 0] += 1 }
            let sorted = counts.sorted { lhs, rhs in
                if lhs.key == "nil" { return true }
                if rhs.key == "nil" { return false }
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            let visible = sorted.prefix(12).map { "\($0.key)=\($0.value)" }.joined(separator: ",")
            return sorted.count > 12 ? visible + ",...groups=\(sorted.count)" : visible
        }

        func sample(_ episode: LibraryItem) -> String {
            let compactName = episode.name.replacingOccurrences(of: "|", with: "/").replacingOccurrences(of: "\n", with: " ")
            let name = String(compactName.prefix(48))
            return "id=\(episode.id)|name=\(name)|index=\(episode.indexNumber.map(String.init) ?? \"nil\")|parentIndex=\(episode.parentIndexNumber.map(String.init) ?? \"nil\")|seasonId=\(episode.seasonId ?? \"nil\")|parentId=\(episode.parentId ?? \"nil\")|seriesId=\(episode.seriesId ?? \"nil\")"
        }

        let selectedCount = selectedSeason.map { season in episodes.reduce(0) { $1.parentIndexNumber == season ? $0 + 1 : $0 } } ?? episodes.count
        let unmatchedCount = selectedSeason.map { season in episodes.reduce(0) { $1.parentIndexNumber == season ? $0 : $0 + 1 } } ?? 0
        let nilIndexCount = episodes.reduce(0) { $1.indexNumber == nil ? $0 + 1 : $0 }
        let wrongSeriesCount = episodes.reduce(0) { episode in
            guard let episodeSeriesID = episode.seriesId else { return $0 }
            return episodeSeriesID == seriesID ? $0 : $0 + 1
        }

        DiagnosticsLogger.shared.log("EpisodeDiagnostic", "series=\(seriesID) episodesTotal=\(episodes.count) seasonsTotal=\(seasons.count) selectedSeason=\(selectedSeason.map(String.init) ?? \"nil\") selectedCount=\(selectedCount) unmatched=\(unmatchedCount) nilIndex=\(nilIndexCount) wrongSeries=\(wrongSeriesCount)")
        DiagnosticsLogger.shared.log("EpisodeDiagnostic", "series=\(seriesID) parentIndex={\(countByOptionalInt(episodes.map(\.parentIndexNumber)))}")
        DiagnosticsLogger.shared.log("EpisodeDiagnostic", "series=\(seriesID) seasonId={\(countByOptionalString(episodes.map(\.seasonId)))}")
        DiagnosticsLogger.shared.log("EpisodeDiagnostic", "series=\(seriesID) parentId={\(countByOptionalString(episodes.map(\.parentId)))}")
        DiagnosticsLogger.shared.log("EpisodeDiagnostic", "series=\(seriesID) seasonIndex={\(countByOptionalInt(seasons.map(\.indexNumber)))}")
        for (index, episode) in episodes.prefix(5).enumerated() { DiagnosticsLogger.shared.log("EpisodeDiagnostic", "series=\(seriesID) sampleFirst[\(index)]=\(sample(episode))") }
        let tail = Array(episodes.suffix(5))
        for (index, episode) in tail.enumerated() { DiagnosticsLogger.shared.log("EpisodeDiagnostic", "series=\(seriesID) sampleLast[\(index)]=\(sample(episode))") }
    }

'''
detail = replace_once(detail, "    private func loadMediaMetadata(for mediaItem: LibraryItem?) async {\n", helper + "    private func loadMediaMetadata(for mediaItem: LibraryItem?) async {\n", "diagnostic helper")
detail_path.write_text(detail)

Path("scripts/check_series_episode_diagnostics.py").write_text('''from pathlib import Path\n\nmodels = Path("Sources/Models/EmbyModels.swift").read_text()\napi = Path("Sources/Networking/EmbyAPIClient.swift").read_text()\ndetail = Path("Sources/UI/EmbyMediaDetailView.swift").read_text()\nproject = Path("project.yml").read_text()\n\nassert 'let seasonId: String?' in models\nassert 'let parentId: String?' in models\nassert 'case seasonId = "SeasonId"' in models\nassert 'case parentId = "ParentId"' in models\nassert 'SeriesName,SeriesId,SeasonId,ParentId,IndexNumber,ParentIndexNumber' in api\nassert 'DiagnosticsLogger.shared.log("EpisodeDiagnostic"' in detail\nassert 'parentIndex={' in detail\nassert 'seasonId={' in detail\nassert 'parentId={' in detail\nassert 'sampleFirst[' in detail and 'sampleLast[' in detail\nassert 'episodes.filter { $0.parentIndexNumber == season }' in detail\nassert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project\nprint("series episode diagnostics checks passed")\n''')
