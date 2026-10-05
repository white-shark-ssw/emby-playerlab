from pathlib import Path
import subprocess
import sys

repo = Path(sys.argv[1]).resolve()
target = Path(sys.argv[2]).resolve()
baseline = sys.argv[3]
target.mkdir(parents=True, exist_ok=True)
control = Path(__file__).parent
for name in ['Stubs.swift', 'CarouselTests.swift', 'DockTests.swift']:
    (target / name).write_text((control / name).read_text())
for name, source in [('Native.swift', 'EmbyHomeCarouselNativePresentationV3.swift'), ('Dock.swift', 'ServerDock.swift')]:
    text = (repo / 'Sources/UI' / source).read_text()
    if name == 'Dock.swift':
        # Transparent UIKit instrumentation only; all production layout expressions remain intact.
        text = text.replace('.frame(height: ServerDockMetrics.height)', '.frame(height: ServerDockMetrics.height).background(DockMarker())', 1)
    (target / name).write_text(text)
state = (repo / 'Sources/UI/EmbyHomeCarouselStateV3.swift').read_text().split('extension V3EmbyHomeView')[0]
(target / 'Runtime.swift').write_text(state)
metrics = (repo / 'Sources/UI/ImmersiveUIComponents.swift').read_text().split('struct AdaptiveHeroRevealMetrics {')[1].split('final class AdaptiveHeroScrollProbeUIView')[0]
(target / 'Metrics.swift').write_text('import UIKit\nstruct AdaptiveHeroRevealMetrics {' + metrics)
immersive = (repo / 'Sources/UI/ImmersiveUIComponents.swift').read_text()
policy = immersive[immersive.index('enum DetailPresentationSettingsKey {'):immersive.index('struct ImmersiveBackdrop: View {')]
(target / 'DetailPolicy.swift').write_text('import SwiftUI\n' + policy + '\nstruct DetailPolicyProbe: View { var body: some View { Color.clear.modifier(DetailPagePresentationModifier()) } }\n')

def layout_probe(core, name, accepted):
    start = core.index('                ZStack(alignment: .top) {')
    end = core.index('                .onAppear {', start)
    expression = core[start:end]
    declaration = 'let dock = AnyView(DockMarker().frame(height: 40))' if accepted else ''
    modifier = '' if accepted else '.serverDockPage()'
    return '''struct NAME: View {
    let immersive: Bool
    let serverDockBottomInset: CGFloat
    DECLARATION
    let carouselPresentationBridge = V3HomeCarouselPresentationBridge()
    let carouselPresentationItems: [V3HomeCarouselPresentationItem] = []
    let carouselDisplayRange = 0.30
    func header(immersive: Bool) -> some View { Color.clear.frame(height: 32) }
    func homeScroll(width: CGFloat, viewportHeight: CGFloat, immersive: Bool) -> some View { ScrollView { Color.clear.frame(width: width, height: 1200) } }
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let viewportHeight = geometry.size.height + geometry.safeAreaInsets.top
                let nativeSurfaceHeight = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
EXPRESSION
            } MODIFIER
            .navigationBarHidden(true)
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}
'''.replace('NAME', name).replace('DECLARATION', declaration).replace('MODIFIER', modifier).replace('EXPRESSION', expression)

old = subprocess.check_output(['git', '-C', str(repo), 'show', baseline + ':Sources/UI/EmbyHomeCoreV3.swift'], text=True)
current = (repo / 'Sources/UI/EmbyHomeCoreV3.swift').read_text()
root = (repo / 'Sources/UI/EmbyServerRootViewV3.swift').read_text()
action = root[root.index('    private func selectTab'):root.index('    private func close')].replace('private func selectTab', 'func selectTab')
support = (control / 'Support.swift').read_text()
(target / 'LayoutProbe.swift').write_text(support + layout_probe(old, 'AcceptedHomeProbe', True) + layout_probe(current, 'CurrentHomeProbe', False) + '''
final class RootActionProbe {
    var selectedTab: V3ServerTab = .home
    var searchModel: V3GlobalSearchViewModel?
    var homeRefreshToken = 0
    var homeScrollToTopToken = 0
    var lastHomeTap = Date.distantPast
''' + action + '}\n')
(target / 'DockRegressionHost.swift').write_text('''import UIKit
@main final class DockRegressionAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask { .portrait }
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
''')
(target / 'project.yml').write_text('''name: ServerDockRegression
options:
  deploymentTarget:
    iOS: "15.0"
targets:
  DockRegressionHost:
    type: application
    platform: iOS
    sources: [DockRegressionHost.swift]
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: com.oneplayer.dock-regression-host
        SWIFT_VERSION: "5.0"
        INFOPLIST_KEY_UISupportedInterfaceOrientations: UIInterfaceOrientationPortrait
        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad: UIInterfaceOrientationPortrait
  ServerDockRegression:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: .
        excludes: [project.yml, DockRegressionHost.swift]
    dependencies:
      - target: DockRegressionHost
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: com.oneplayer.server-dock-regression
        SWIFT_VERSION: "5.0"
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/DockRegressionHost.app/DockRegressionHost"
        BUNDLE_LOADER: "$(TEST_HOST)"
schemes:
  ServerDockRegression:
    build:
      targets:
        ServerDockRegression: [test]
    test:
      targets: [ServerDockRegression]
''')
