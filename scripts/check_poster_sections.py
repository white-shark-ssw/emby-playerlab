from pathlib import Path
import subprocess
import sys

baseline = sys.argv[1] if len(sys.argv) > 1 else 'dced392bbf2e3960539890121cf7d6e9d8f80e86'
def old(path):
    if Path(baseline).is_dir():
        return (Path(baseline) / path).read_text()
    return subprocess.check_output(['git', 'show', f'{baseline}:{path}'], text=True)
def region(s, start, end=None):
    return s[s.index(start):s.index(end) if end else len(s)]

browse = Path('Sources/UI/EmbyServerBrowseV3.swift').read_text()
before = old('Sources/UI/EmbyServerBrowseV3.swift')
assert region(browse, 'struct V3LibraryBrowserView:', '    private var suggestionsTab:').replace('    @State private var suggestionSelection: LibraryItem?\n', '') == region(before, 'struct V3LibraryBrowserView:', '    private var suggestionsTab:'), 'G01/P3 root changed'
assert region(browse, '    private var genresTab:', '    private func emptyState(') == region(before, '    private var genresTab:', '    private func suggestionSectionTitle('), 'G01/P3 tab/sort changed'
assert region(browse, '    private func emptyState(', 'struct V3EmbyFavoritesView:') == region(before, '    private func emptyState(', 'struct V3EmbyFavoritesView:'), 'Library queries/adapters changed'
assert region(browse, 'private struct V3FavoriteCategoryGridView:') == region(before, 'private struct V3FavoriteCategoryGridView:'), 'Favorite leaves/model/caches/old routes changed'
search = Path('Sources/UI/EmbySearchExperienceV3.swift').read_text()
before_search = old('Sources/UI/EmbySearchExperienceV3.swift')
assert search[:search.index('struct V3EmbyGlobalSearchView:')] == before_search[:before_search.index('struct V3EmbyGlobalSearchView:')], 'Search model/history/generation9/+6 changed'
root = region(search, 'struct V3EmbyGlobalSearchView:', '    private var searchResults:')
for line in ['    @State private var previewItem: LibraryItem?\n', '    @State private var previewClient: EmbyAPIClient?\n', '    @State private var previewMore: V3GlobalSearchServerResult?\n']:
    root = root.replace(line, '')
assert root == region(before_search, 'struct V3EmbyGlobalSearchView:', '    private var searchResults:'), 'Search headers/menu/keyboard/recommendations changed'
assert region(search, '    private var directSearchLink:') == region(before_search, '    private var directSearchLink:'), 'Search direct/history/more leaf query changed'
assert 'client: result.client' in region(search, '    private var searchPosterSections:', '    private var directSearchLink:')
home = Path('Sources/UI/EmbyHomeCoreV3.swift').read_text()
before_home = old('Sources/UI/EmbyHomeCoreV3.swift')
prefix = home[:home.index('    private func homeScroll(')]
for line in ['    @Environment(\\.serverDockBottomInset) var dockBottomInset\n', '    @State var posterDetailItem: LibraryItem?\n', '    @State var posterLibrary: LibraryItem?\n']:
    prefix = prefix.replace(line, '')
assert prefix == before_home[:before_home.index('    private func homeScroll(')], 'Home viewport/Hero/Dock/settings/lifetime changed'
assert region(home, '    @MainActor\n    private func refreshHome()') == region(before_home, '    @MainActor\n    private func refreshHome()'), 'Home refresh/header changed'
for host in [region(home, '    private func homeScroll(', '    @MainActor\n    private func refreshHome()'), region(browse, '    private var suggestionsTab:', '    private var genresTab:'), region(browse, 'struct V3EmbyFavoritesView:', 'private struct V3FavoriteCategoryGridView:'), region(search, '    private var searchResults:', '    private var directSearchLink:')]:
    assert 'EmbyPosterSections(' in host and 'ScrollView(' not in host and 'LazyHStack' not in host and 'AnyView' not in host
assert 'items: Array(items.prefix(20))' in browse
assert 'style: type == "Person" ? .person : .poster' in browse
assert 'heroScrollState.update(max(-heroTrackingLimit, value))' in home
assert 'scrollToTopToken: scrollToTopToken' in home
assert 'ServerDockMetrics.contentBottomPadding(bottomInset: dockBottomInset)' in home + browse + search

for directory in ['Sources/Player', 'Sources/Transport', 'Sources/Cache', 'Sources/Emby', 'Sources/Networking', 'Sources/Models', 'Sources/Session']:
    if Path(baseline).is_dir():
        for path in Path(directory).rglob('*'):
            if path.is_file(): assert path.read_bytes() == (Path(baseline) / path).read_bytes(), str(path)
    else: assert not subprocess.check_output(['git', 'diff', baseline, '--name-only', '--', directory], text=True).strip(), directory
for name in ['EmbyHomeRowsV3', 'EmbyHomeModelV3', 'EmbyHomeHeroV3', 'EmbyHomeHeroScrollStateV3', 'EmbyHomeScrollOffsetObserverV3', 'EmbyHomeRefreshControlStylerV3', 'EmbyHomeCarouselNativePresentationV3', 'EmbyHomeCarouselStateV3', 'EmbyHomeCarouselInteractionV3', 'EmbyHomeCarouselProgressPresentationV3', 'EmbyHomeCarouselCadenceDiagnosticsV3', 'EmbyHomeMediaManagementOverlayV3', 'ServerDock', 'EmbyServerRootViewV3', 'ImmersiveUIComponents', 'EmbyMediaDetailView', 'EmbyDetailPerformanceState', 'EmbyDetailScrollDiagnostics', 'EmbyPersonMediaView', 'EmbyPosterWall', 'EmbyPosterResultsPage', 'EmbyPosterSearchLanding', 'EmbyImagePreparation', 'EmbySharedImageAndNavigation', 'EmbyPagePersistentCache', 'EmbySearchRecommendationPreloader']:
    path = f'Sources/UI/{name}.swift'
    assert Path(path).read_text() == old(path), path
sections = Path('Sources/UI/EmbyPosterSections.swift').read_text()
assert 'collection.scrollsToTop = false' in sections
assert 'collection.scrollsToTop = active && visible' in sections
assert 'count < 12' in sections and 'setFirstScreen(owner: firstScreenOwner' in sections
assert 'V3HomeScrollOffsetObserver.Coordinator' in sections and 'V3HomeOwnedRefreshControl.Coordinator' in sections
assert all(word not in sections for word in ['AnyView', 'Timer', 'Task.detached', '[String: UIImage]', 'decelerationRate'])
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in Path('project.yml').read_text()
print('P5 H01–H04 native presentation scope; G01/P3/P4 query/source/navigation,293carousel/294Dock/Hero/refresh bridges/H05/P0 and image budgets preserved')
