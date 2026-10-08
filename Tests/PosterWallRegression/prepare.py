from pathlib import Path
import sys
import subprocess

repo = Path(sys.argv[1]).resolve()
target = Path(sys.argv[2]).resolve()
target.mkdir(parents=True, exist_ok=True)
for path in ['Sources/Core/AppIdentity.swift', 'Sources/UI/EmbyPosterWall.swift', 'Sources/UI/EmbyImagePreparation.swift', 'Sources/UI/EmbyPagePersistentCache.swift', 'Sources/Cache/EmbyImageDiskCache.swift', 'Sources/Models/EmbyModels.swift']:
    (target / Path(path).name).write_text((repo / path).read_text())
for path in ['Sources/UI/EmbyPosterSearchLanding.swift', 'Sources/UI/EmbySearchRecommendationPreloader.swift']:
    (target / Path(path).name).write_text((repo / path).read_text())
for path in ['Sources/UI/EmbyPosterSections.swift', 'Sources/UI/EmbyHomeScrollOffsetObserverV3.swift', 'Sources/UI/EmbyHomeRefreshControlStylerV3.swift']:
    (target / Path(path).name).write_text((repo / path).read_text())
shared_cards = (repo / 'Sources/UI/EmbyServerSharedV3.swift').read_text()
(target / 'RowSubtitle.swift').write_text('import Foundation\n' + shared_cards[shared_cards.index('func v3MediaSubtitle('):])
# Visibility only: tests inspect demand materialization and retained production prefetch tokens.
wall = target / 'EmbyPosterWall.swift'
text = wall.read_text()
for old, new in [('private var records:', 'private(set) var records:'), ('private var prefetch:', 'private(set) var prefetch:')]:
    assert text.count(old) == 1, old
    text = text.replace(old, new)
wall.write_text(text)
(target / 'EmbyDetailScrollDiagnostics.swift').write_text((repo / 'Sources/UI/EmbyDetailScrollDiagnostics.swift').read_text())
baseline = (Path(sys.argv[3]) / 'Sources/UI/EmbyPosterWall.swift').read_text() if len(sys.argv) > 3 else subprocess.check_output(['git', '-C', str(repo), 'show', '07f2f7c97953aba5e7f3ffde867632215c52c211:Sources/UI/EmbyPosterWall.swift'], text=True)
baseline_record = baseline[baseline.index('struct EmbyPosterRecord:'):baseline.index('final class EmbyPosterCell:')]
(target / 'EagerRecordBaseline.swift').write_text('import UIKit\n' + baseline_record.replace('EmbyPosterRecord', 'EagerRecordBaseline'))
shared = (repo / 'Sources/UI/EmbySharedImageAndNavigation.swift').read_text()
pool = shared[shared.index('final class EmbyDecodedImageRenderPool'):shared.index('@MainActor\nprivate final class EmbyCachedImageLoader')]
decoder = shared[shared.index('enum EmbyImageDecoder'):shared.index('private final class EmbyPosterNavigationGate')]
(target / 'ImageServices.swift').write_text('import UIKit\nimport ImageIO\nimport os\n' + pool + decoder)
metrics = (repo / 'Sources/UI/EmbyPosterGrid.swift').read_text().split('final class EmbyPosterGridNavigationState')[0]
(target / 'Metrics.swift').write_text(metrics)
recommendations = (repo / 'Sources/Networking/EmbyLibraryHubAPI.swift').read_text().split('extension EmbyAPIClient')[0]
(target / 'Recommendations.swift').write_text(recommendations)
api = (repo / 'Sources/Networking/EmbyAPIClient.swift').read_text()
image_url = api[api.index('    func imageURL('):api.index('    func setFavorite(')]
(target / 'Services.swift').write_text('''import Foundation
final class DiagnosticsLogger {
    static let shared = DiagnosticsLogger()
    private let lock = NSLock()
    private var messages: [String] = []
    var onRecord: ((String) -> Void)?
    func log(_ category: String, _ message: String) { lock.lock(); messages.append(message); lock.unlock(); onRecord?(message) }
    func records() -> [String] { lock.lock(); defer { lock.unlock() }; return messages }
}
final class EmbyAPIClient {
    let baseURL: URL
    let userId: String?
    let accessToken: String?
    init(baseURL: URL, userId: String = "test", accessToken: String? = nil) { self.baseURL = baseURL; self.userId = userId; self.accessToken = accessToken }
''' + image_url + '}\n')
browse = (repo / 'Sources/UI/EmbyServerBrowseV3.swift').read_text()
tabs = browse[browse.index('private enum V3LibraryTab'):browse.index('struct V3LibraryBrowserView: View')].replace('private enum V3LibraryTab', 'enum V3LibraryTab')
model = browse[browse.index('@MainActor\nprivate final class V3LibraryBrowserViewModel'):browse.index('private enum V3LibraryPosterDestination')].replace('private final class V3LibraryBrowserViewModel', 'final class V3LibraryBrowserViewModel')
(target / 'LibraryModel.swift').write_text('import SwiftUI\nimport Combine\n' + tabs + model)
view = browse[browse.index('struct V3LibraryBrowserView: View'):browse.index('@MainActor\nprivate final class V3LibraryBrowserViewModel')]
(target / 'LibraryView.swift').write_text('import SwiftUI\nimport Combine\nimport UIKit\n' + view)
# Compile every P3 adapter and both original result models; only access levels change for cross-file tests.
adapters = browse[browse.index('private enum V3LibraryPosterDestination'):browse.index('struct V3EmbyFavoritesView:')]
for name in ['enum V3LibraryPosterDestination', 'struct V3LibraryPosterPage', 'struct V3LibraryGenreGridView', 'final class V3LibraryGenreGridViewModel', 'struct V3LibraryFolderBrowserView', 'final class V3LibraryFolderBrowserViewModel', 'func v3LibraryIsBrowsableFolder']:
    assert adapters.count('private ' + name) == 1, name
    adapters = adapters.replace('private ' + name, name)
(target / 'LibraryAdapters.swift').write_text('import SwiftUI\nimport UIKit\n' + adapters)
favorites_root = browse[browse.index('struct V3EmbyFavoritesView:'):browse.index('private struct V3FavoriteCategoryGridView:')]
favorites_model = browse[browse.index('private struct V3FavoriteSections'):browse.index('private enum V3SearchDefaults')]
(target / 'FavoritesRoot.swift').write_text('import SwiftUI\n' + favorites_root + favorites_model)
header = shared_cards[shared_cards.index('enum V3ServerHeaderMetrics'):shared_cards.index('struct V3LibraryTile:')]
(target / 'PageHeader.swift').write_text('import SwiftUI\n' + header)
# P4 production leaves/models and shared navigation adapter; access levels only are changed.
favorite = browse[browse.index('private struct V3FavoriteCategoryGridView:'):browse.index('private struct V3FavoritePersonLink:')]
search = (repo / 'Sources/UI/EmbySearchExperienceV3.swift').read_text()
(target / 'SearchProduction.swift').write_text(search[:search.index('private struct V3GlobalSearchServerGridView:')])
search = search[search.index('private struct V3GlobalSearchServerGridView:'):]
detail_leaf = (repo / 'Sources/UI/EmbyMediaDetailView.swift').read_text()
detail_leaf = detail_leaf[detail_leaf.index('struct EmbyDetailFilter:'):detail_leaf.index('@MainActor\nfinal class EmbyMediaDetailViewModel')]
person = (repo / 'Sources/UI/EmbyPersonMediaView.swift').read_text()
results = favorite + search + detail_leaf + person.replace('import SwiftUI\n', '').replace('import UIKit\n', '')
for name in ['struct V3FavoriteCategoryGridView', 'final class V3FavoriteCategoryGridViewModel', 'struct V3GlobalSearchServerGridView', 'final class V3GlobalSearchServerGridViewModel', 'struct EmbyDetailFilterResultsView', 'final class EmbyDetailFilterResultsViewModel', 'final class EmbyPersonMediaViewModel']:
    assert results.count('private ' + name) == 1, name
    results = results.replace('private ' + name, name)
(target / 'ResultLeaves.swift').write_text('import SwiftUI\nimport UIKit\n' + results)
(target / 'EmbyPosterResultsPage.swift').write_text((repo / 'Sources/UI/EmbyPosterResultsPage.swift').read_text())
(target / 'ServerDock.swift').write_text((repo / 'Sources/UI/ServerDock.swift').read_text())
detail = (repo / 'Sources/UI/EmbyDetailPerformanceState.swift').read_text()
trace = detail[detail.index('// One bounded timeline'):detail.index('final class EmbyDetailHeroScrollState')]
(target / 'DetailTrace.swift').write_text('import Foundation\n' + trace)
services = target / 'Services.swift'
text = services.read_text()
text = text[:-2] + (Path(__file__).parent / 'APIStub.swift').read_text() + '}\n'
services.write_text(text)
(target / 'PosterTests.swift').write_text((Path(__file__).parent / 'PosterTests.swift').read_text())
(target / 'LibraryAdapterTests.swift').write_text((Path(__file__).parent / 'LibraryAdapterTests.swift').read_text())
(target / 'ResultAdapterTests.swift').write_text((Path(__file__).parent / 'ResultAdapterTests.swift').read_text())
(target / 'SearchLandingTests.swift').write_text((Path(__file__).parent / 'SearchLandingTests.swift').read_text())
(target / 'SearchLandingHost.swift').write_text((Path(__file__).parent / 'SearchLandingHost.swift').read_text())
(target / 'Host.swift').write_text((Path(__file__).parent / 'MotionHost.swift').read_text())
(target / 'ReturnHost.swift').write_text((Path(__file__).parent / 'ReturnHost.swift').read_text())
(target / 'SectionTests.swift').write_text((Path(__file__).parent / 'SectionTests.swift').read_text())
(target / 'SectionHost.swift').write_text((Path(__file__).parent / 'SectionHost.swift').read_text())
(target / 'MotionUITests.swift').write_text((Path(__file__).parent / 'MotionUITests.swift').read_text())
(target / 'project.yml').write_text('''name: PosterWallRegression
options:
  deploymentTarget:
    iOS: "15.0"
targets:
  PosterHost:
    type: application
    platform: iOS
    sources:
      - path: .
        excludes: [project.yml, PosterTests.swift, LibraryAdapterTests.swift, ResultAdapterTests.swift, SearchLandingTests.swift, SectionTests.swift, MotionUITests.swift]
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: com.oneplayer.poster-host
        SWIFT_VERSION: "5.0"
  PosterWallRegression:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: .
        excludes: [project.yml, Host.swift, MotionUITests.swift]
    dependencies:
      - target: PosterHost
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: com.oneplayer.poster-regression
        SWIFT_VERSION: "5.0"
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/PosterHost.app/PosterHost"
        BUNDLE_LOADER: "$(TEST_HOST)"
  PosterMotionUITests:
    type: bundle.ui-testing
    platform: iOS
    sources: [MotionUITests.swift]
    dependencies:
      - target: PosterHost
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: com.oneplayer.poster-motion-ui
        SWIFT_VERSION: "5.0"
        TEST_TARGET_NAME: PosterHost
schemes:
  PosterWallRegression:
    build:
      targets:
        PosterWallRegression: [test]
        PosterMotionUITests: [test]
    test:
      targets: [PosterWallRegression, PosterMotionUITests]
  PosterMotionUITests:
    build:
      targets:
        PosterMotionUITests: [test]
    test:
      targets: [PosterMotionUITests]
''')
