from pathlib import Path
import subprocess
import sys

repo = Path(sys.argv[1]).resolve()
target = Path(sys.argv[2]).resolve()
target.mkdir(parents=True, exist_ok=True)
control = Path(__file__).parent
for name in ['Stubs.swift', 'CarouselTests.swift', 'LayoutTests.swift']:
    (target / name).write_text((control / name).read_text())
(target / 'Native.swift').write_text((repo / 'Sources/UI/EmbyHomeCarouselNativePresentationV3.swift').read_text())
state = (repo / 'Sources/UI/EmbyHomeCarouselStateV3.swift').read_text().split('extension V3EmbyHomeView')[0]
(target / 'Runtime.swift').write_text(state)
metrics = (repo / 'Sources/UI/ImmersiveUIComponents.swift').read_text().split('struct AdaptiveHeroRevealMetrics {')[1].split('final class AdaptiveHeroScrollProbeUIView')[0]
(target / 'Metrics.swift').write_text('import UIKit\nstruct AdaptiveHeroRevealMetrics {' + metrics)

def layout_probe(core, name):
    start = core.index('                ZStack(alignment: .top) {')
    end = core.index('                .onAppear {', start)
    expression = core[start:end]
    return '''struct NAME: View {
    let dock: AnyView
    let serverDockBottomInset: CGFloat
    let carouselPresentationBridge = V3HomeCarouselPresentationBridge()
    let carouselPresentationItems: [V3HomeCarouselPresentationItem] = []
    let carouselDisplayRange = 0.30
    let carouselTransitionState = 0
    var carouselPreloadLayer: some View { Color.clear.frame(width: 1, height: 1) }
    func persistentCarouselBackdrop(size: CGSize) -> some View { Color.clear.frame(width: size.width, height: size.height) }
    func header(immersive: Bool) -> some View { Color.clear.frame(height: 32) }
    func homeScroll(width: CGFloat, viewportHeight: CGFloat, immersive: Bool) -> some View { ScrollView { Color.clear.frame(width: width, height: 1200) } }
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let immersive = true
                let viewportHeight = geometry.size.height + geometry.safeAreaInsets.top
                let nativeSurfaceHeight = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
EXPRESSION
            }.navigationBarHidden(true)
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}
'''.replace('NAME', name).replace('EXPRESSION', expression)

baseline = subprocess.check_output(['git', '-C', str(repo), 'show', '7e7b2ec944f5c0e74bc291e37683f1529e3d46b4:Sources/UI/EmbyHomeCoreV3.swift'], text=True)
current = (repo / 'Sources/UI/EmbyHomeCoreV3.swift').read_text()
support = '''import SwiftUI
import UIKit
struct V3HomeCarouselTransitionScope<Content: View>: View {
    let content: Content
    init(state: Int, @ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View { content }
}
struct DockMarker: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { let view = UIView(); view.accessibilityIdentifier = "dock-probe"; return view }
    func updateUIView(_ view: UIView, context: Context) {}
}
struct LayoutServerProbe: View {
    let current: Bool
    var body: some View {
        GeometryReader { geometry in
            let fullHeight = geometry.size.height + geometry.safeAreaInsets.bottom
            let dock = AnyView(DockMarker().frame(height: 64))
            ZStack {
                if current { CurrentHomeProbe(dock: dock, serverDockBottomInset: geometry.safeAreaInsets.bottom) }
                else { AcceptedHomeProbe(dock: dock, serverDockBottomInset: geometry.safeAreaInsets.bottom) }
            }
            .frame(width: geometry.size.width, height: fullHeight, alignment: .top)
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}
'''
(target / 'LayoutProbe.swift').write_text(support + layout_probe(baseline, 'AcceptedHomeProbe') + layout_probe(current, 'CurrentHomeProbe'))
(target / 'project.yml').write_text('''name: CarouselRegression
options:
  deploymentTarget:
    iOS: "15.0"
targets:
  CarouselRegression:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: .
        excludes: [project.yml]
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: com.oneplayer.carousel-regression
        SWIFT_VERSION: "5.0"
schemes:
  CarouselRegression:
    build:
      targets:
        CarouselRegression: [test]
    test:
      targets: [CarouselRegression]
''')
