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
shared = (root / "Sources/UI/EmbyServerSharedV3.swift").read_text()
image = (root / "Sources/UI/EmbySharedImageAndNavigation.swift").read_text()

assert 'static let sourceVersion = "0.15.5"' in identity
assert '<key>CADisableMinimumFrameDurationOnPhone</key>' in info
assert '<true/>' in info.split('<key>CADisableMinimumFrameDurationOnPhone</key>', 1)[1][:80]

assert 'diagnosticRoute: String = "grid"' in grid
assert 'EmbyPosterGridCadenceProbe(ownerID: diagnosticOwnerID, route: diagnosticRoute, itemCount: items.count)' in grid
assert 'cellDidAppear(ownerID: diagnosticOwnerID)' in grid
assert 'loadAheadDidTrigger(ownerID: diagnosticOwnerID)' in grid
assert 'LazyVGrid(' not in grid
assert 'return LazyVStack(alignment: .leading, spacing: EmbyPosterGridMetrics.rowSpacing)' in grid
assert 'let rowStarts = Array(stride(from: 0, to: items.count, by: EmbyPosterGridMetrics.columnCount))' in grid
assert 'HStack(alignment: .top, spacing: EmbyPosterGridMetrics.columnSpacing)' in grid
assert 'ForEach(items[rowStart..<rowEnd])' in grid
assert 'usesFixedStandardPosterRowHeight: Bool = false' in grid
assert 'private var standardPosterRowHeight: CGFloat?' in grid
assert '.frame(height: usesFixedStandardPosterRowHeight ? standardPosterRowHeight : nil, alignment: .topLeading)' in grid
assert 'usesFixedStandardPosterRowHeight: true' in server
assert server.count('usesFixedStandardPosterRowHeight: true') == 1
assert '@Environment(\.embyPosterGridDiagnosticOwnerID)' in shared
assert 'onImageLoaded: { _ in' in shared and 'imageDidPublish(ownerID: ownerID)' in shared

assert 'private final class MotionSession' in diag
assert 'var displayIntervalsMS: [Double] = []' in diag
assert 'offsetIntervalsMS' not in diag
assert 'decelerationDisplayDeltas' not in diag
assert 'decelerationDisplayStepRatios' not in diag
assert 'CFRunLoopObserver' not in diag
assert 'maxAbsVelocityY' not in diag
assert diag.count('CADisplayLink(target:') == 1
assert 'scrollView.observe(\\.contentOffset' in diag
assert 'owners.values.contains { $0.session != nil }' in diag
assert 'CAFrameRateRange(minimum: 80, maximum: maximum, preferred: maximum)' in diag
assert 'displayLink.preferredFrameRateRange = .default' in diag
assert 'offsetSampleCount += 1' in diag
assert 'offset_hz=' in diag and 'display_hz=' in diag
assert 'decel_display_zero=' in diag and 'decel_display_catchup=' in diag
assert 'decel_reverse_ge1=' in diag
assert 'decel_reverse_max_pt=' in diag
assert 'decel_reverse_content_height_delta_pt=' in diag
assert 'decel_reverse_inset_top_delta_pt=' in diag
assert 'decel_reverse_inset_bottom_delta_pt=' in diag
assert 'decel_zero_ratio=' in diag and 'decel_catchup_ratio=' in diag
assert 'display_p50_ms=' in diag and 'display_p95_ms=' in diag and 'display_p99_ms=' in diag
assert 'display_ge12_5=' in diag and 'display_ge25=' in diag and 'display_ge33_3=' in diag
assert 'item_count_changes=' in diag and 'cell_appear=' in diag and 'image_publish=' in diag and 'load_ahead=' in diag
assert 'decelerationRate' not in diag

# Keep the Build266 image-loading A/B inherited unchanged while testing only container layout.
assert 'private let publishesLoadingState: Bool' in image
assert 'publishesLoadingState: width != nil' in shared
assert 'showsLoadingIndicator: false, publishesLoadingState: publishesLoadingState' in shared

# Protected shared routes and Home high-refresh path remain present.
for token in ['library-', 'library-genres', 'library-genre-results', 'library-folder', 'favorites-category', 'server-search-results']:
    assert token in server, token
for token in ['global-search-recommendations', 'global-search-results']:
    assert token in search, token
assert 'person-results' in person
assert 'detail-filter-results' in detail
assert home.count('CADisplayLink(target:') == 1
assert 'CAFrameRateRange(minimum: 80, maximum: maximum, preferred: maximum)' in home
assert 'HomeScrollCadence' in home
assert 'decelerationRate' not in home

print('poster grid row-stack source contract: PASS')
