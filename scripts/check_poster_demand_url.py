from pathlib import Path

wall = Path('Sources/UI/EmbyPosterWall.swift').read_text()
record = wall[wall.index('struct EmbyPosterRecord:'):wall.index('final class EmbyPosterCell:')]
apply = wall[wall.index('    private func applyItems('):wall.index('    private func prepareFirstScreen(')]
assert 'client.imageURL(' not in record
assert 'var url: URL? { imageRequest.url }' in record
assert 'if !isResolved {' in wall
assert 'client.imageURL(itemId: key.itemID, maxWidth: key.pixelWidth, tag: key.tag)' in wall
assert 'append ? Array(value.items.dropFirst(old.count)) : value.items' in apply
assert 'retainedRequests[key] ?? EmbyPosterImageRequest' in record
assert 'first.isResolved ? first : next' in apply
assert 'cancelPrefetch(except: Set(next.compactMap { $0.imageRequest.resolvedURL }))' in apply
assert 'next.compactMap(\\.url)' not in apply
cancel = wall[wall.index('    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt'):wall.index('    private func cancelPrefetch(')]
assert '.imageRequest.resolvedURL' in cancel and 'records[path.item].url' not in cancel
assert 'collection.performBatchUpdates' in apply
assert 'numberOfItemsInSection section: Int) -> Int { records.count }' in wall
diagnostics = Path('Sources/UI/EmbyDetailScrollDiagnostics.swift').read_text()
assert 'events < 32' in diagnostics and '>= 3' in diagnostics
assert 'view.isUserInteractionEnabled = false' in diagnostics
for forbidden in ['setContentOffset', 'addGestureRecognizer', '.delegate =', '.isScrollEnabled =', 'preferredFrameRateRange', 'preferredFramesPerSecond', 'asyncAfter']:
    assert forbidden not in diagnostics, forbidden
detail = Path('Sources/UI/EmbyMediaDetailView.swift').read_text()
assert 'EmbyDetailScrollDiagnostics().frame(width: 0, height: 0)' in detail
assert 'heroScrollState.update(value)' in detail
print('Poster demand URL / passive detail scroll checks passed')
