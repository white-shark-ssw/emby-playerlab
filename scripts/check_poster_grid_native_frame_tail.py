from pathlib import Path

identity = Path('Sources/Core/AppIdentity.swift').read_text()
native = Path('Sources/UI/EmbyNativePosterCollectionView.swift').read_text()

for value in ['static let sourceVersion = "0.15.9"', '?? "0.15.9"']:
    assert value in identity, f'missing Build276 identity: {value}'

required = [
    'UICollectionViewFlowLayout()',
    'V3PosterCard(item: item, client: client, width: nil)',
    'collectionView.performBatchUpdates',
    'collectionView.insertItems(at: inserted)',
    'event=insert-begin',
    'event=insert-end',
    'event=reconfigure',
    'event=display-gap',
    'display_interval_p50_ms=',
    'display_interval_p95_ms=',
    'display_interval_p99_ms=',
    'display_interval_max_ms=',
    'gap_ge12_5=',
    'gap_ge25=',
    'gap_ge33_3=',
    'gap12_insert_overlap=',
    'gap25_insert_overlap=',
    'gap33_insert_overlap=',
    'gap12_reconfigure_overlap=',
    'gap25_reconfigure_overlap=',
    'gap33_reconfigure_overlap=',
    'insert_active=',
    'reconfigure_visible=',
    'CAFrameRateRange(minimum: 80',
    'event=reverse',
    'distance_top=',
    'distance_bottom=',
    'outside_bounds=',
]
for value in required:
    assert value in native, f'missing Build276 frame-tail contract: {value}'

for forbidden in ['decelerationRate =', 'Timer.', 'DispatchSourceTimer', 'targetTime / duration', 'fileSize']:
    assert forbidden not in native, f'forbidden behavior: {forbidden}'

assert 'displayIntervalsMs.removeAll(keepingCapacity: true)' in native
assert 'if intervalMs >= 25 {' in native and 'DiagnosticsLogger.shared.log("NativePosterCollection", "event=display-gap' in native
assert 'if intervalMs >= 12.5 {' in native
assert 'if intervalMs >= 33.3 {' in native
print('Build276 native poster frame-tail checker: PASS')
