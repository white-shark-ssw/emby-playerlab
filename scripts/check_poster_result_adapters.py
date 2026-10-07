from pathlib import Path
import subprocess
import sys

baseline = sys.argv[1] if len(sys.argv) > 1 else 'cfe1b84c816bae1c37b07e7ac007da972c0b3510'
def old(path):
    if Path(baseline).is_dir():
        return (Path(baseline) / path).read_text()
    return subprocess.check_output(['git', 'show', f'{baseline}:{path}'], text=True)
def region(text, start, end=None):
    return text[text.index(start):text.index(end) if end else len(text)]
def strip_events(text):
    for line in ['    private(set) var posterRevision = 0\n', '    private(set) var posterReplacement = 0\n', '        posterReplacement += 1; posterRevision += 1\n']:
        text = text.replace(line, '')
    return text.replace('; posterRevision += 1', '')

browse_path = 'Sources/UI/EmbyServerBrowseV3.swift'
browse = Path(browse_path).read_text(); previous = old(browse_path)
start = 'private struct V3FavoriteCategoryGridView:'
end = 'private struct V3FavoritePersonLink:'
assert browse[:browse.index(start)] == previous[:previous.index(start)], 'G01/P3/Favorites root changed'
assert browse[browse.index(end):] == previous[previous.index(end):], 'Favorites Person preview/old Search changed'
leaves = [(browse, previous, 'private final class V3FavoriteCategoryGridViewModel:', end)]
detail_path = 'Sources/UI/EmbyMediaDetailView.swift'
detail = Path(detail_path).read_text(); previous_detail = old(detail_path)
start = 'private struct EmbyDetailFilterResultsView:'
end = '@MainActor\nfinal class EmbyMediaDetailViewModel'
assert detail[:detail.index(start)] == previous_detail[:previous_detail.index(start)], 'Detail main view/Hero/entry paths changed'
assert detail[detail.index(end):] == previous_detail[previous_detail.index(end):], 'Detail main model/playback/images changed'
leaves.append((detail, previous_detail, 'private final class EmbyDetailFilterResultsViewModel:', 'private struct EmbyDetailPosterCard:'))
search_path = 'Sources/UI/EmbySearchExperienceV3.swift'
search = Path(search_path).read_text(); previous_search = old(search_path)
start = 'private struct V3GlobalSearchServerGridView:'
assert search[:search.index(start)] == previous_search[:previous_search.index(start)], 'Search direct/history/multi-server sources or9/+6/lifetime changed'
leaves.append((search, previous_search, 'private final class V3GlobalSearchServerGridViewModel:', None))
person = Path('Sources/UI/EmbyPersonMediaView.swift').read_text()
leaves.append((person, old('Sources/UI/EmbyPersonMediaView.swift'), 'private final class EmbyPersonMediaViewModel:', None))
for text, before, start, end in leaves:
    # The removed detail card is after the model; strip its leading @MainActor separator equivalently.
    a = region(text, start, '@MainActor\nfinal class EmbyMediaDetailViewModel') if 'EmbyDetailFilterResultsViewModel' in start else region(text, start, end)
    b = region(before, start, end)
    assert strip_events(a).strip() == b.strip(), start + ': business query/frontier/error policy changed'
for text, start, end in [(browse, 'private struct V3FavoriteCategoryGridView:', '@MainActor\nprivate final class V3FavoriteCategoryGridViewModel'), (detail, 'private struct EmbyDetailFilterResultsView:', '@MainActor\nprivate final class EmbyDetailFilterResultsViewModel'), (search, 'private struct V3GlobalSearchServerGridView:', '@MainActor\nprivate final class V3GlobalSearchServerGridViewModel'), (person, 'struct EmbyPersonMediaView:', '@MainActor\nprivate final class EmbyPersonMediaViewModel')]:
    view = region(text, start, end)
    assert 'EmbyPosterResultsPage(' in view and 'ScrollView' not in view and 'EmbyPosterGrid(' not in view
    assert 'if !model.hasLoaded' in view
adapter = Path('Sources/UI/EmbyPosterResultsPage.swift').read_text()
assert adapter.count('NavigationLink(') == 1 and 'NavigationView' not in adapter and 'AnyView' not in adapter
assert 'EmbyPosterDetailDestination(item: item, client: client)' in adapter
assert 'EmbyPerson(itemId: item.id, name: item.name, role: nil, type: item.type, primaryImageTag: item.primaryImageTag)' in adapter
assert 'allowsRefresh: false' in adapter and 'isActive: selection == nil' in adapter
assert 'content: .plainMedia' in person and 'content: .plainMedia' in detail
for path in ['Sources/UI/EmbySharedImageAndNavigation.swift', 'Sources/UI/EmbyImagePreparation.swift', 'Sources/UI/EmbyPagePersistentCache.swift', 'Sources/UI/ServerDock.swift', 'Sources/UI/EmbyServerRootViewV3.swift', 'Sources/UI/EmbyDetailPerformanceState.swift']:
    assert Path(path).read_text() == old(path), path
print('P4 G09–G14 single-host adapters; original models/queries/lifetime/routes and main detail frozen bytes preserved; G15 unchanged/pending')
