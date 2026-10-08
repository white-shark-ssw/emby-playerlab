from pathlib import Path
import subprocess
import sys

baseline = sys.argv[1] if len(sys.argv) > 1 else '44cdd845f3e822dde0215d0a47f180fbb73544a8'
def old(path):
    return subprocess.check_output(['git', 'show', f'{baseline}:{path}'], text=True)

browse_path = 'Sources/UI/EmbyServerBrowseV3.swift'
browse = Path(browse_path).read_text()
original = old(browse_path)
native_detail_route = '            if let item = nativePosterSelection { EmbyPosterDetailDestination(item: item, client: client) }\n            else { EmptyView() }'
native_folder_route = '            if let item = nativePosterSelection {\n                if v3LibraryIsBrowsableFolder(item) { V3LibraryFolderBrowserView(folder: item, client: client) }\n                else { EmbyPosterDetailDestination(item: item, client: client) }\n            } else { EmptyView() }'
assert native_folder_route in browse, 'Library root Folder route missing'
normalized_browse = browse.replace(native_folder_route, native_detail_route, 1)
assert normalized_browse[:normalized_browse.index('    private func pagedPosterTab(')] == original[:original.index('    private func pagedPosterTab(')], 'Accepted G01/root navigation changed outside Folder route'
boundary = 'struct V3EmbyFavoritesView:'
def without_favorite_more(text):
    start = text.index('private struct V3FavoriteCategoryGridView:')
    end = text.index('private struct V3FavoritePersonLink:')
    return text[:start] + text[end:]
assert without_favorite_more(browse[browse.index(boundary):]) == without_favorite_more(original[original.index(boundary):]), 'P5 Favorites/old Search changed'
suggestions = '    private var suggestionsTab:'
end = '    private var genresTab:'
assert browse[browse.index(suggestions):browse.index(end)] == original[original.index(suggestions):original.index(end)], 'P5 Library suggestions changed'
adapters = browse[browse.index('private enum V3LibraryPosterDestination'):browse.index(boundary)]
assert 'EmbyPosterGrid(' not in adapters and 'ScrollView(' not in adapters
assert 'case .genre(let library): V3LibraryGenreGridView(library: library, genre: item, client: client)' in adapters
assert 'if v3LibraryIsBrowsableFolder(item) { V3LibraryFolderBrowserView(folder: item, client: client) }' in adapters
assert 'else { EmbyPosterDetailDestination(item: item, client: client) }' in adapters
assert 'queryIdentity: "\(library.id)|genre|\(genre.name)"' in adapters
folder = adapters[adapters.index('@MainActor\nprivate final class V3LibraryFolderBrowserViewModel'):]
assert 'libraryFolderChildren(parentId: folder.id)' in folder
assert 'libraryHubItemsPage' not in folder and 'loadNextPage' not in folder
assert adapters.count('private let pageSize = 60') == 1
assert adapters.count('sortBy: "SortName", sortOrder: "Ascending", includeItemTypes: expectedTypes, genres: [genre.name]') == 2
assert 'nextStartIndex = start + page.items.count' in adapters
assert 'if tab == .items && liveItemsSortBy == sortBy { return }' in browse

# Preserve the actual providers, P0/transport/cache, detail destinations, image budgets and frozen hosts.
for directory in ['Sources/Player', 'Sources/Transport', 'Sources/Cache', 'Sources/Emby', 'Sources/Networking', 'Sources/Models']:
    assert not subprocess.check_output(['git', 'diff', baseline, '--name-only', '--', directory], text=True).strip(), directory
for path in ['Sources/UI/EmbySharedImageAndNavigation.swift', 'Sources/UI/EmbyImagePreparation.swift', 'Sources/UI/EmbyPagePersistentCache.swift', 'Sources/UI/EmbyDetailPerformanceState.swift', 'Sources/UI/EmbyDetailScrollDiagnostics.swift', 'Sources/UI/ServerDock.swift', 'Sources/UI/ImmersiveUIComponents.swift', 'Sources/UI/EmbyHomeCarouselNativePresentationV3.swift', 'Sources/UI/EmbyHomeCarouselStateV3.swift', 'Sources/UI/EmbyServerRootViewV3.swift']:
    assert Path(path).read_text() == old(path), path
print('P3 Library adapters scoped; root Folder routing added while accepted G01 view, queries, details, frozen hosts and P0 source remain preserved')
