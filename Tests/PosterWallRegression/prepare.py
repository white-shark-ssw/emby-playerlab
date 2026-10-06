from pathlib import Path
import sys

repo = Path(sys.argv[1]).resolve()
target = Path(sys.argv[2]).resolve()
target.mkdir(parents=True, exist_ok=True)
for path in ['Sources/Core/AppIdentity.swift', 'Sources/UI/EmbyPosterWall.swift', 'Sources/UI/EmbyImagePreparation.swift', 'Sources/UI/EmbyPagePersistentCache.swift', 'Sources/Cache/EmbyImageDiskCache.swift', 'Sources/Models/EmbyModels.swift']:
    (target / Path(path).name).write_text((repo / path).read_text())
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
    let accessToken: String? = nil
    init(baseURL: URL, userId: String = "test") { self.baseURL = baseURL; self.userId = userId }
''' + image_url + '}\n')
browse = (repo / 'Sources/UI/EmbyServerBrowseV3.swift').read_text()
tabs = browse[browse.index('private enum V3LibraryTab'):browse.index('struct V3LibraryBrowserView: View')].replace('private enum V3LibraryTab', 'enum V3LibraryTab')
model = browse[browse.index('@MainActor\nprivate final class V3LibraryBrowserViewModel'):browse.index('private struct V3LibraryGenreCard')].replace('private final class V3LibraryBrowserViewModel', 'final class V3LibraryBrowserViewModel')
(target / 'LibraryModel.swift').write_text('import SwiftUI\nimport Combine\n' + tabs + model)
services = target / 'Services.swift'
text = services.read_text()
text = text[:-2] + (Path(__file__).parent / 'APIStub.swift').read_text() + '}\n'
services.write_text(text)
(target / 'PosterTests.swift').write_text((Path(__file__).parent / 'PosterTests.swift').read_text())
(target / 'Host.swift').write_text((Path(__file__).parent / 'MotionHost.swift').read_text())
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
        excludes: [project.yml, PosterTests.swift, MotionUITests.swift]
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
