from pathlib import Path
import subprocess
import sys

baseline = sys.argv[1] if len(sys.argv) > 1 else '119ab10eee869488b97415746a0243f51953eba0'

def old(path):
    return subprocess.check_output(['git', 'show', f'{baseline}:{path}'], text=True)

pages = ['EmbyHomeCoreV3.swift', 'EmbyHomeRowsV3.swift', 'EmbyServerBrowseV3.swift', 'EmbySearchExperienceV3.swift', 'OnePlayerSettingsViews.swift']
for name in pages:
    path = f'Sources/UI/{name}'
    current = Path(path).read_text()
    expected = old(path).replace('    let dock: AnyView\n', '').replace('        self.dock = dock\n', '').replace(', dock: AnyView', '').replace(', dock: dock', '')
    expected = expected.replace('.overlay(alignment: .bottom) { dock }', '.serverDockPage()').replace('.padding(.bottom, 86)', '.serverDockContentPadding()')
    if name == 'EmbyHomeCoreV3.swift':
        expected = expected.replace('    @Environment(\\.serverDockBottomInset) private var serverDockBottomInset\n', '')
        expected = expected.replace('                .overlay(alignment: .bottom) {\n                    if immersive { dock.padding(.bottom, serverDockBottomInset) }\n                    else { dock }\n                }\n', '')
        expected = expected.replace('            .navigationBarHidden(true)\n', '            .serverDockPage()\n            .navigationBarHidden(true)\n', 1)
    if name == 'EmbyServerBrowseV3.swift':
        # Build295 deliberately replaces Library.items and its model, while every other page stays accepted.
        boundary = 'private struct V3LibraryGenreCard'
        assert current[current.index(boundary):] == expected[expected.index(boundary):], 'Non-pilot browse routes changed'
        assert current.count('.serverDockPage()') == expected.count('.serverDockPage()')
        assert current.count('.serverDockContentPadding()') == expected.count('.serverDockContentPadding()')
        assert 'bottomPadding: ServerDockMetrics.contentBottomPadding(bottomInset: dockBottomInset)' in current
    else:
        assert current == expected, f'Unexpected non-Dock page behavior changed: {path}' 

root = Path('Sources/UI/EmbyServerRootViewV3.swift').read_text()
original = old('Sources/UI/EmbyServerRootViewV3.swift')
previous_action = original[original.index('            if tab == .home && selectedTab == .home {'):original.index('        } label: {', original.index('            if tab == .home && selectedTab == .home {'))]
current_action = root[root.index('        if tab == .home && selectedTab == .home {'):root.index('    private func close')].rstrip().rsplit('\n', 1)[0]
assert ''.join(previous_action.split()) == ''.join(current_action.split()), 'Root selection/Search lifetime/Home tap actions changed'
assert 'serverTabBar' not in root and 'AnyView' not in root
assert root.count('serverDockConfiguration') == 1 and root.count('serverDockBottomInset') == 1
assert '.ignoresSafeArea(.keyboard, edges: selectedTab == .search ? .bottom : [])' in root

dock = Path('Sources/UI/ServerDock.swift').read_text()
assert '.frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)' in dock
assert '.overlay(alignment: .bottom) { dock.padding(.bottom, bottomInset) }' in dock
assert '.ignoresSafeArea(.keyboard, edges: .bottom)' in dock
assert 'static let height: CGFloat = 40' in dock
assert '.offset(y: 8)' in dock
assert '@State' not in dock and '@Published' not in dock
assert all(word not in dock for word in ['Timer', 'DispatchQueue', 'NavigationView', 'UINavigationController'])
immersive = Path('Sources/UI/ImmersiveUIComponents.swift').read_text()
assert '.serverDockPage(isVisible: !fullyImmersive)' in immersive
assert 'serverDockContent' not in immersive and 'ServerDockVisibilityController' not in immersive
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in Path('project.yml').read_text()
for directory in ['Sources/Player', 'Sources/Transport', 'Sources/Cache', 'Sources/Emby']:
    changed = subprocess.check_output(['git', 'diff', baseline, '--name-only', '--', directory], text=True)
    assert not changed.strip(), f'Protected core changed: {changed}'
for name in ['EmbyHomeCarouselNativePresentationV3.swift', 'EmbyHomeCarouselStateV3.swift', 'EmbyHomeCarouselInteractionV3.swift', 'EmbyHomeHeroV3.swift']:
    assert Path('Sources/UI', name).read_text() == old(f'Sources/UI/{name}'), f'Frozen carousel changed: {name}'
print('Dock page changes limited to hosting/signatures/clearance; root actions and frozen source unchanged; iOS15 retained.')

