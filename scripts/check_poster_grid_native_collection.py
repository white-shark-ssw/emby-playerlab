from pathlib import Path

identity = Path('Sources/Core/AppIdentity.swift').read_text()
native = Path('Sources/UI/EmbyNativePosterCollectionView.swift').read_text()
browse = Path('Sources/UI/EmbyServerBrowseV3.swift').read_text()
nav = Path('Sources/UI/EmbySharedImageAndNavigation.swift').read_text()

required_identity = ['static let sourceVersion = "0.15.6"', '?? "0.15.6"']
for value in required_identity:
    assert value in identity, f'missing Build273 identity: {value}'

required_native = [
    'UICollectionViewFlowLayout()',
    'layout.estimatedItemSize = .zero',
    'EmbyPosterGridMetrics.columnCount',
    'EmbyPosterGridMetrics.horizontalPadding',
    'EmbyPosterGridMetrics.columnSpacing',
    'EmbyPosterGridMetrics.rowSpacing',
    'V3PosterCard(item: item, client: client, width: nil)',
    '.environment(\\.embyPosterGridCellWidth, width)',
    'UIHostingController(rootView: rootView)',
    'collectionView.performBatchUpdates',
    'collectionView.insertItems(at: inserted)',
    'refreshControl.addTarget',
    'onApproachingEnd()',
    'CAFrameRateRange(minimum: 80',
    'event=reverse',
    'legal_top=',
    'legal_bottom=',
    'distance_top=',
    'distance_bottom=',
    'outside_bounds=',
    'event=session-end',
]
for value in required_native:
    assert value in native, f'missing native contract: {value}'

for forbidden in ['decelerationRate =', 'Timer.', 'DispatchSourceTimer', 'targetTime / duration', 'fileSize']:
    assert forbidden not in native, f'forbidden native behavior: {forbidden}'

assert 'case .items:\n            nativeItemsTab' in browse, 'Library items must use native collection'
assert 'case .trailers, .collections, .favorites:\n            pagedPosterTab(selectedTab)' in browse, 'other paged tabs must remain SwiftUI'
assert 'EmbyNativePosterCollectionView(' in browse, 'native collection call missing'
assert 'Task { await model.loadNextPage(tab: .items) }' in browse, 'existing Library paging owner not reused'
assert 'Task { await model.refresh(tab: .items) }' in browse, 'existing Library refresh owner not reused'
assert 'EmbyPosterDetailDestination(item: item, client: client)' in browse, 'existing detail destination not reused'
assert 'struct EmbyPosterDetailDestination: View {' in nav, 'detail destination must be module-visible'
assert 'private struct EmbyPosterDetailDestination: View {' not in nav, 'detail destination still private'

print('Build273 native poster collection checker: PASS')
