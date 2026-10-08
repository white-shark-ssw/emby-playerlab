from pathlib import Path
import subprocess
import sys

baseline = sys.argv[1] if len(sys.argv) > 1 else '83a239dc259651755315d52e9028d159830d9960'
def old(path):
    if Path(baseline).is_dir():
        return (Path(baseline) / path).read_text()
    return subprocess.check_output(['git', 'show', f'{baseline}:{path}'], text=True)

path = 'Sources/UI/EmbySearchExperienceV3.swift'
before = old(path); current = Path(path).read_text()
start = 'private struct V3GlobalSearchServerGridView:'
assert current[current.index(start):] == before[before.index(start):], 'G13/G14 leaves changed'
def model(text):
    return text[:text.index('\n\nprivate struct V3SearchRecommendationPosterCard:') if 'private struct V3SearchRecommendationPosterCard:' in text else text.index('struct V3EmbyGlobalSearchView:')].strip()
expected_model = model(before).replace('    private var recommendationPosterImages: [String: UIImage] = [:]\n', '')
a = expected_model.index('    func recommendationPosterImage('); b = expected_model.index('    private func recordHistory', a)
expected_model = expected_model[:a] + expected_model[b:]
actual_model = model(current).replace('    private(set) var recommendationRevision = 0\n', '').replace('            recommendationRevision += 1\n', '').replace('            if !newItems.isEmpty { recommendationRevision += 1 }\n', '')
assert actual_model == expected_model, 'Search query/generation9/+6/dedup/error/history/selection owners changed'
def root(text):
    s = text[text.index('struct V3EmbyGlobalSearchView:'):text.index(start)]
    a = s.index('    private var searchLanding:'); b = s.index('    private var searchResults:', a)
    return (s[:a] + s[b:]).replace('    @Environment(\\.serverDockBottomInset) private var dockBottomInset\n', '')
assert root(current) == root(before), 'Search keyboard/direct/history/multi-server routes or lifetime changed'
preloader = Path('Sources/UI/EmbySearchRecommendationPreloader.swift').read_text()
expected = old('Sources/UI/EmbySearchRecommendationPreloader.swift')
expected = expected.replace('        warmPosterImages(accepted.compactMap { item in client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: V3SearchRecommendationPolicy.posterImageMaxWidth, tag: item.preferredPrimaryImageTag) })\n', '')
a = expected.index('        let urls = items.compactMap'); b = expected.index('        DiagnosticsLogger.shared.log', a); expected = expected[:a] + expected[b:]
expected = expected[:expected.index('    private func warmPosterImages')].rstrip() + '\n}\n'
assert preloader == expected, 'Random API limits/types/exclusions or pixel spec changed'
assert all(word not in current + preloader for word in ['recommendationPosterImages', 'pinRecommendationPosterImage', 'warmPosterImages', 'Task.detached'])
landing = Path('Sources/UI/EmbyPosterSearchLanding.swift').read_text()
assert 'horizontalPadding: 6' in landing and 'loadAheadItemCount: 1' in landing
assert 'imagePixelWidth: V3SearchRecommendationPolicy.posterImageMaxWidth' in landing
assert 'EmbyPosterResultsPage(' in landing and 'ScrollView' not in landing and '[String: UIImage]' not in landing
assert 'historyList.scrollsToTop = false' in landing and 'showsRecommendations' in landing
wall = Path('Sources/UI/EmbyPosterWall.swift').read_text()
assert 'referenceSizeForHeaderInSection' in wall and 'landingHeader' in wall
assert 'loadAheadItemCount: Int = EmbyPosterGridMetrics.loadAheadItemCount' in wall
for path in ['Sources/UI/EmbyServerBrowseV3.swift', 'Sources/UI/EmbyPersonMediaView.swift', 'Sources/UI/EmbyMediaDetailView.swift', 'Sources/UI/EmbyServerRootViewV3.swift', 'Sources/UI/EmbySharedImageAndNavigation.swift', 'Sources/UI/EmbyImagePreparation.swift', 'Sources/UI/ServerDock.swift', 'Sources/UI/EmbyHomeCoreV3.swift', 'Sources/UI/EmbyHomeRowsV3.swift', 'Sources/Networking/EmbyAPIClient.swift', 'Sources/Networking/EmbyLibraryHubAPI.swift', 'Sources/Session/SessionStore.swift', 'Sources/Cache/EmbyImageDiskCache.swift']:
    assert Path(path).read_text() == old(path), path + ': protected source changed'
print('G15 one native landing host;9/+6/random/exclusion/generation/history/routes/keyboard and frozen native sources preserved; no second image authority')
