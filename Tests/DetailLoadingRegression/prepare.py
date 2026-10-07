from pathlib import Path
import sys

repo, target = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
target.mkdir(parents=True, exist_ok=True)
for path in ['Sources/Core/AppIdentity.swift', 'Sources/Core/EmbyUserDataChange.swift', 'Sources/Models/EmbyModels.swift', 'Sources/Models/EmbyImageInfo.swift', 'Sources/Networking/EmbyAPIError.swift']:
    (target / Path(path).name).write_text((repo / path).read_text())
detail = (repo / 'Sources/UI/EmbyMediaDetailView.swift').read_text()
model = detail[detail.index('@MainActor\nfinal class EmbyMediaDetailViewModel'):detail.index('private struct EmbyDetailRemoteImage')]
ranges = detail[detail.index('struct EmbyEpisodeRange'):detail.index('struct EmbyMediaDetailView:')]
filters = detail[detail.index('struct EmbyDetailFilter:'):detail.index('private struct EmbyDetailFilterResultsView:')]
(target / 'DetailModel.swift').write_text('import SwiftUI\nimport Combine\nimport UIKit\n' + ranges + filters + model)
state = (repo / 'Sources/UI/EmbyDetailPerformanceState.swift').read_text()
# Visibility only: tests instantiate an isolated production cache and inspect its actual disk path/queue.
for old, new in [('private init()', 'init()'), ('private let cache =', 'let cache ='), ('private let writeQueue =', 'let writeQueue ='), ('private func key(', 'func key('), ('private func cacheFileURL(', 'func cacheFileURL(')]:
    assert state.count(old) == 1, old
    state = state.replace(old, new)
(target / 'DetailState.swift').write_text(state)
for path in ['Services.swift', 'DetailTests.swift']:
    (target / path).write_text((Path(__file__).parent / path).read_text())
(target / 'Host.swift').write_text('import SwiftUI\n@main struct Host: App { var body: some Scene { WindowGroup { Color.clear } } }\n')
(target / 'project.yml').write_text('''name: DetailLoadingRegression
options:
  deploymentTarget:
    iOS: "15.0"
targets:
  DetailHost:
    type: application
    platform: iOS
    sources:
      - path: .
        excludes: [project.yml, DetailTests.swift]
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: com.oneplayer.detail-host
        SWIFT_VERSION: "5.0"
  DetailLoadingRegression:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: .
        excludes: [project.yml, Host.swift]
    dependencies:
      - target: DetailHost
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: com.oneplayer.detail-tests
        SWIFT_VERSION: "5.0"
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/DetailHost.app/DetailHost"
        BUNDLE_LOADER: "$(TEST_HOST)"
schemes:
  DetailLoadingRegression:
    build:
      targets:
        DetailLoadingRegression: [test]
    test:
      targets: [DetailLoadingRegression]
''')
