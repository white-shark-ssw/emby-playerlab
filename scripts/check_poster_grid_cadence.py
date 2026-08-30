from pathlib import Path

root = Path(__file__).resolve().parents[1]
grid = (root / "Sources/UI/EmbyPosterGrid.swift").read_text()
diag = (root / "Sources/UI/EmbyPosterGridCadenceDiagnostics.swift").read_text()
server = (root / "Sources/UI/EmbyServerBrowseV3.swift").read_text()
search = (root / "Sources/UI/EmbySearchExperienceV3.swift").read_text()
person = (root / "Sources/UI/EmbyPersonMediaView.swift").read_text()
detail = (root / "Sources/UI/EmbyMediaDetailView.swift").read_text()
identity = (root / "Sources/Core/AppIdentity.swift").read_text()
info = (root / "Config/Info.plist").read_text()

assert 'static let sourceVersion = "0.14.93"' in identity
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
assert 'preferredFramesPerSecond' not in diag
assert 'scrollView.observe(\\.contentOffset' in diag
assert 'offset_p50_ms=' in diag and 'offset_p95_ms=' in diag and 'offset_p99_ms=' in diag
assert 'display_p50_ms=' in diag and 'display_p95_ms=' in diag and 'display_p99_ms=' in diag
assert 'offset_ge10=' in diag and 'offset_ge12_5=' in diag and 'offset_ge16_7=' in diag and 'offset_ge25=' in diag and 'offset_ge33_3=' in diag
assert 'item_count_changes=' in diag and 'cell_appear=' in diag and 'load_ahead=' in diag
for token in ['library-', 'library-genres', 'library-genre-results', 'library-folder', 'favorites-category', 'server-search-results']:
    assert token in server, token
for token in ['global-search-recommendations', 'global-search-results']:
    assert token in search, token
assert 'person-results' in person
assert 'detail-filter-results' in detail
print('poster grid cadence diagnostic source contract: PASS')
