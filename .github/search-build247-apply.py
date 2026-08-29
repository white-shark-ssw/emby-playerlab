from pathlib import Path

path = Path('Sources/UI/EmbySearchExperienceV3.swift')
text = path.read_text()

def replace_once(old: str, new: str, label: str):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    text = text.replace(old, new, 1)

replace_once(
'''    private var recommendationGeneration = 0
    private var recommendationLimit = 12
    private var recommendationPosterImages: [String: UIImage] = [:]''',
'''    private var recommendationGeneration = 0
    private var recommendationPosterImages: [String: UIImage] = [:]''',
'remove incremental recommendation limit')

start = text.index('    func loadRecommendations(client: EmbyAPIClient) async {')
end = text.index('    private func recordHistory(_ term: String) {', start)
new_block = '''    func loadRecommendations(session: EmbySession, client: EmbyAPIClient) async {
        guard recommendationsEnabled, !isLoadingRecommendations else { return }
        recommendationGeneration += 1
        let generation = recommendationGeneration
        isLoadingRecommendations = true
        defer { if generation == recommendationGeneration { isLoadingRecommendations = false } }

        do {
            let items = try await V3SearchRecommendationPreloader.shared.recommendations(for: session, client: client)
            guard generation == recommendationGeneration, recommendationsEnabled else { return }
            recommendationItems = items.filter(V3SearchRecommendationPolicy.allows)
            hasMoreRecommendations = false
        } catch {
            guard generation == recommendationGeneration else { return }
            hasMoreRecommendations = false
            if !isEmbyRequestCancellation(error) { DiagnosticsLogger.shared.log("Search", "recommendations failed: \\(error.localizedDescription)") }
        }
    }

    func recommendationPosterImage(for itemID: String) -> UIImage? { recommendationPosterImages[itemID] }
    func pinRecommendationPosterImage(_ image: UIImage, for itemID: String) { recommendationPosterImages[itemID] = image }

'''
text = text[:start] + new_block + text[end:]

old_width = '''    private var posterImageMaxWidth: Int {
        let available = UIScreen.main.bounds.width - EmbyPosterGridMetrics.horizontalPadding * 2 - EmbyPosterGridMetrics.columnSpacing * CGFloat(EmbyPosterGridMetrics.columnCount - 1)
        let gridWidth = floor(max(1, available) / CGFloat(EmbyPosterGridMetrics.columnCount))
        return min(440, max(1, Int(ceil(gridWidth * UIScreen.main.scale))))
    }'''
replace_once(old_width, '    private var posterImageMaxWidth: Int { V3SearchRecommendationPolicy.posterImageMaxWidth }', 'shared recommendation poster width')

replace_once(
'''            .task {
                model.reconcileServers(sessionStore.sessions)
                await model.loadRecommendations(client: currentClient)
            }''',
'''            .task {
                model.reconcileServers(sessionStore.sessions)
                await model.loadRecommendations(session: currentSession, client: currentClient)
            }''',
'landing preload consumer')

replace_once(
'''                model.toggleRecommendations()
                if model.recommendationsEnabled { Task { await model.loadRecommendations(client: currentClient) } }''',
'''                model.toggleRecommendations()
                if model.recommendationsEnabled { Task { await model.loadRecommendations(session: currentSession, client: currentClient) } }''',
'toggle recommendation preload consumer')

old_grid = '''                EmbyPosterGrid(items: model.recommendationItems, horizontalPadding: 6, onApproachingEnd: {
                    guard model.hasMoreRecommendations else { return }
                    Task { await model.loadMoreRecommendations(client: currentClient) }
                }) { item in
                    EmbyPosterDetailLink(item: item, client: currentClient) {
                        V3SearchRecommendationPosterCard(item: item, client: currentClient, pinnedImage: model.recommendationPosterImage(for: item.id)) { image in
                            model.pinRecommendationPosterImage(image, for: item.id)
                        }
                    }
                }'''
new_grid = '''                EmbyPosterGrid(items: model.recommendationItems, horizontalPadding: 6) { item in
                    EmbyPosterDetailLink(item: item, client: currentClient) {
                        V3SearchRecommendationPosterCard(item: item, client: currentClient, pinnedImage: model.recommendationPosterImage(for: item.id)) { image in
                            model.pinRecommendationPosterImage(image, for: item.id)
                        }
                    }
                }'''
replace_once(old_grid, new_grid, 'fixed recommendation grid')

path.write_text(text)
