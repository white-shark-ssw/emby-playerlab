from pathlib import Path

root = Path(__file__).resolve().parents[1]
grid = (root / "Sources/UI/EmbyPosterGrid.swift").read_text()
diag = (root / "Sources/UI/EmbyPosterGridCadenceDiagnostics.swift").read_text()
server = (root / "Sources/UI/EmbyServerBrowseV3.swift").read_text()
search = (root / "Sources/UI/EmbySearchExperienceV3.swift").read_text()
person = (root / "Sources/UI/EmbyPersonMediaView.swift").read_text()
detail = (root / "Sources/UI/EmbyMediaDetailView.swift").read_text()
home = (root / "Sources/UI/EmbyHomeScrollOffsetObserverV3.swift").read_text()
identity = (root / "Sources/Core/AppIdentity.swift").read_text()
info = (root / "Config/Info.plist").read_text()

assert 'static let sourceVersion = "0.14.99"' in identity
assert '<key>CADisableMinimumFrameDurationOnPhone</key>' in info
assert '<true/>' in info.split('<key>CADisableMinimumFrameDurationOnPhone</key>', 1)[1][:80]
assert 'diagnosticRoute: String = "grid"' in grid
assert 'EmbyPosterGridCadenceProbe(ownerID: diagnosticOwnerID, route: diagnosticRoute, itemCount: items.count)' in grid
assert 'cellDidAppear(ownerID: diagnosticOwnerID)' in grid
assert 'loadAheadDidTrigger(ownerID: diagnosticOwnerID)' in grid
assert diag.count('CADisplayLink(target:') == 1
assert 'owners.values.contains { $0.session != nil }' in diag
assert 'CAFrameRateRange(minimum: 80, maximum: maximum, preferred: maximum)' in diag
assert 'displayLink.preferredFrameRateRange = .default' in diag
assert 'refresh_request=' in diag and 'requested_min_fps=' in diag and 'requested_max_fps=' in diag
assert 'decel_display_frames=' in diag and 'decel_display_zero=' in diag and 'decel_display_catchup=' in diag and 'decel_display_reverse=' in diag
assert 'decel_delta_p50_pt=' in diag and 'decel_delta_p95_pt=' in diag and 'decel_delta_p99_pt=' in diag
assert 'decel_step_ratio_p50=' in diag and 'decel_step_ratio_p95=' in diag and 'decel_step_ratio_p99=' in diag
assert 'lastDecelerationDisplayOffsetY' in diag and 'previousDecelerationDisplayWasZero' in diag
assert 'long_gap_ge12_5=' in diag and 'long_gap_cell_churn=' in diag and 'long_gap_load_ahead=' in diag and 'long_gap_item_change=' in diag and 'long_gap_untracked=' in diag
assert 'long_gap_max_cell_appear=' in diag and 'long_gap_max_cell_disappear=' in diag and 'long_gap_max_offset_updates=' in diag
assert 'embyPosterGridDiagnosticOwnerID' in grid
shared = (root / "Sources/UI/EmbyServerSharedV3.swift").read_text()
assert '@Environment(\.embyPosterGridDiagnosticOwnerID)' in shared
assert 'onImageLoaded: { _ in' in shared and 'imageDidPublish(ownerID: ownerID)' in shared
assert 'image_publish=' in diag and 'long_gap_image_publish=' in diag and 'long_gap_max_image_publish=' in diag

image = (root / "Sources/UI/EmbySharedImageAndNavigation.swift").read_text()
assert 'private let publishesLoadingState: Bool' in image
assert 'init(publishesLoadingState: Bool)' in image
assert 'private func setLoading(_ value: Bool) { if publishesLoadingState { isLoading = value } }' in image
assert 'publishesLoadingState: Bool = true' in image
assert '_loader = StateObject(wrappedValue: EmbyCachedImageLoader(publishesLoadingState: publishesLoadingState))' in image
assert 'publishesLoadingState: width != nil' in shared
assert 'showsLoadingIndicator: false, publishesLoadingState: publishesLoadingState' in shared
assert 'severe25_ge25=' in diag and 'severe25_image_publish=' in diag and 'severe25_untracked=' in diag
assert 'severe33_ge33_3=' in diag and 'severe33_image_publish=' in diag and 'severe33_untracked=' in diag
assert diag.count('CFRunLoopObserverCreateWithHandler') == 1
assert 'CFRunLoopActivity.beforeWaiting.rawValue' in diag and 'CFRunLoopMode.commonModes' in diag
assert 'severe25_no_runloop_wait=' in diag and 'severe25_with_runloop_wait=' in diag
assert 'severe33_no_runloop_wait=' in diag and 'severe33_with_runloop_wait=' in diag
assert 'preferredFramesPerSecond' not in diag
assert 'scrollView.observe(\\.contentOffset' in diag
assert 'offset_p50_ms=' in diag and 'offset_p95_ms=' in diag and 'offset_p99_ms=' in diag
assert 'display_p50_ms=' in diag and 'display_p95_ms=' in diag and 'display_p99_ms=' in diag
assert 'offset_ge10=' in diag and 'offset_ge12_5=' in diag and 'offset_ge16_7=' in diag and 'offset_ge25=' in diag and 'offset_ge33_3=' in diag
assert 'item_count_changes=' in diag and 'cell_appear=' in diag and 'load_ahead=' in diag
assert home.count('CADisplayLink(target:') == 1
assert 'CAFrameRateRange(minimum: 80, maximum: maximum, preferred: maximum)' in home
assert 'HomeScrollCadence' in home and 'display_p50_ms=' in home and 'display_p95_ms=' in home and 'display_p99_ms=' in home
assert 'decelerationRate' not in home and 'decelerationRate' not in diag
for token in ['library-', 'library-genres', 'library-genre-results', 'library-folder', 'favorites-category', 'server-search-results']:
    assert token in server, token
for token in ['global-search-recommendations', 'global-search-results']:
    assert token in search, token
assert 'person-results' in person
assert 'detail-filter-results' in detail
print('poster grid cadence diagnostic source contract: PASS')
