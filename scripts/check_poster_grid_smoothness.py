#!/usr/bin/env python3
from pathlib import Path

grid_source = Path("Sources/UI/EmbyPosterGrid.swift").read_text(encoding="utf-8")
image_source = Path("Sources/UI/EmbySharedImageAndNavigation.swift").read_text(encoding="utf-8")
poster_source = Path("Sources/UI/EmbyServerSharedV3.swift").read_text(encoding="utf-8")
person_source = Path("Sources/UI/EmbyPersonMediaView.swift").read_text(encoding="utf-8")

required_grid = [
    "return LazyVGrid(columns: columns, alignment: .leading, spacing: EmbyPosterGridMetrics.rowSpacing)",
    "ForEach(items) { item in",
    ".onAppear {\n                        guard let handler = onApproachingEnd, loadAheadIDs.contains(item.id) else { return }\n                        EmbyPosterScrollHitchDiagnostics.shared.loadAheadDidTrigger(itemID: item.id)\n                        handler()\n                    }",
    "        .environment(\\.embyPosterGridNavigationState, navigationState)\n        .environment(\\.embyPosterGridCellWidth, cellWidth)\n        .padding(.horizontal, horizontalPadding)",
]
for needle in required_grid:
    if needle not in grid_source:
        raise SystemExit(f"missing poster-grid contract: {needle}")

if grid_source.count(".environment(\\.embyPosterGridNavigationState, navigationState)") != 1:
    raise SystemExit("grid navigation environment must be owned once at the LazyVGrid level")
if grid_source.count(".environment(\\.embyPosterGridCellWidth, cellWidth)") != 1:
    raise SystemExit("grid cell-width environment must be owned once at the LazyVGrid level")
if "content(item)\n                    .environment(" in grid_source:
    raise SystemExit("per-cell environment wrappers reintroduced")

required_image = [
    "init(initialURL: URL? = nil)",
    "image = initialURL.flatMap { EmbyDecodedImageRenderPool.shared.image(for: $0) }",
    "private func setLoading(_ value: Bool, reportsLoadingState: Bool)",
    "if image != nil { image = nil }",
    "_loader = StateObject(wrappedValue: EmbyCachedImageLoader(initialURL: onImageLoaded == nil && showsLoadingIndicator ? url : nil))",
    "private final class EmbyCachedDisplayImageSurfaceView: UIView",
    "func configure(contentMode: SwiftUI.ContentMode, placeholderSystemImage: String)",
    "private struct EmbyCachedDisplayRemoteImage: View",
    "@State private var loader: EmbyCachedImageLoader",
    "_loader = State(initialValue: EmbyCachedImageLoader(initialURL: url))",
    "EmbyCachedDisplayImageSurface(loader: loader, contentMode: contentMode, placeholderSystemImage: placeholderSystemImage)",
    "imageCancellable = loader.$image.sink",
    "if onImageLoaded == nil && !showsLoadingIndicator {",
    "if let onImageLoaded {\n            imageBody.onReceive(loader.$image.compactMap { $0 })",
    "loader.load(url, reportsLoadingState: showsLoadingIndicator, diagnosticRole: onImageLoaded == nil ? \"display\" : \"callback\")",
    "loader.cancel(reportsLoadingState: showsLoadingIndicator)",
    "if onImageLoaded != nil { reportedImageIdentifier = nil }",
    "let startedAt = CACurrentMediaTime()\n                onImageLoaded(image)",
]
for needle in required_image:
    if needle not in image_source:
        raise SystemExit(f"missing poster-image update contract: {needle}")

if "image = nil\n        isLoading = true" in image_source:
    raise SystemExit("poster loader must not publish unconditional loading state")
if "guard let onImageLoaded else { return }" in image_source:
    raise SystemExit("ordinary poster images must not install a no-op image publisher subscriber")
if image_source.count("imageBody.onReceive(loader.$image.compactMap { $0 })") != 1:
    raise SystemExit("image-loaded publisher must exist only on the real callback path")
display_fast_path = image_source[image_source.index("private final class EmbyCachedDisplayImageSurfaceView"):image_source.index("struct EmbyCachedRemoteImage")]
if "func configure(contentMode: ContentMode," in display_fast_path:
    raise SystemExit("UIKit display surface must explicitly use SwiftUI.ContentMode")
if "@StateObject" in display_fast_path or ".onReceive(" in display_fast_path:
    raise SystemExit("display-only poster fast path must not observe loader.objectWillChange through SwiftUI")
if display_fast_path.count("loader.$image.sink") != 1:
    raise SystemExit("display-only poster fast path must have exactly one UIKit image publisher sink")
for needle in [
    'loader.load(url, reportsLoadingState: false, diagnosticRole: "display")',
    'loader.cancel(reportsLoadingState: false)',
    'surface.setImage(loader.image)',
    'imageView.contentMode = contentMode == .fill ? .scaleAspectFill : .scaleAspectFit',
]:
    if needle not in display_fast_path:
        raise SystemExit(f"missing UIKit display-image fast-path contract: {needle}")

required_diagnostics = [
    "final class EmbyPosterScrollHitchDiagnostics: NSObject",
    "private var displayLink: CADisplayLink?",
    "func observeVerticalScrollView(_ scrollView: UIScrollView, ownerID: UUID, route: String)",
    "private var scrollObservations: [UUID: ScrollObservation] = [:]",
    "let deltaY = currentOffsetY - observation.lastOffsetY",
    "if deltaY != 0 { movingSamples.append((scrollView, observation.route, deltaY)) }",
    "guard gap >= 0.030 else { return }",
    "guard let sample = movingSamples.max(by:",
    r"scroll_route=\(sample.route) phase=\(phase) offset_y=\(offsetText) delta_y=\(deltaText) velocity_y=\(velocityText) registered_scrolls=\(scrollObservations.count) moving_scrolls=\(movingSamples.count)",
    "DiagnosticsLogger.shared.log(\"PosterScrollHitch\"",
    "posterDidAppear(itemID: item.id, route: gridNavigationState == nil ? \"row\" : \"grid\")",
    "EmbyPosterScrollHitchDiagnostics.shared.imageDidCommit(url: url, source: \"memory\", role: diagnosticRole)",
    "EmbyPosterScrollHitchDiagnostics.shared.imageDidCommit(url: url, source: \"disk\", role: diagnosticRole)",
    "EmbyPosterScrollHitchDiagnostics.shared.imageDidCommit(url: url, source: \"network\", role: diagnosticRole)",
    "image_role=\\(lastImageRole)",
    "callback_duration_ms=\\(callbackDurationText)",
    "contrast_duration_ms=\\(contrastDurationText)",
    "EmbyPosterScrollHitchDiagnostics.shared.loadAheadDidTrigger(itemID: item.id)",
]
for needle in required_diagnostics:
    if needle not in image_source and needle not in grid_source:
        raise SystemExit(f"missing poster hitch diagnostic contract: {needle}")

for legacy in ["observedScrollOwnerID", "observedScrollRoute", "lastScrollOffsetY"]:
    if legacy in image_source:
        raise SystemExit(f"single-owner poster motion diagnostic reintroduced: {legacy}")

if image_source.count('DiagnosticsLogger.shared.log("PosterScrollHitch"') != 1:
    raise SystemExit("PosterScrollHitch must log only after one centralized display-link gap detector")

if 'EmbyPosterScrollMotionProbe(route: "grid")' not in grid_source:
    raise SystemExit("3-column grid must register its vertical scroll owner for motion-gated hitch diagnostics")
if image_source.count("CADisplayLink(target: self") != 1:
    raise SystemExit("poster diagnostics must keep exactly one shared CADisplayLink implementation")

for source_name in ["memory", "disk", "network"]:
    if f'source: "{source_name}"' not in image_source:
        raise SystemExit(f"missing image publish source diagnostic: {source_name}")
if 'role: diagnosticRole' not in image_source or 'diagnosticRole: onImageLoaded == nil ? "display" : "callback"' not in image_source:
    raise SystemExit("image publish role diagnostics must distinguish callback from display-only paths")
if 'imageCallbackDidComplete(url:' not in image_source or 'callback_duration_ms=' not in image_source:
    raise SystemExit("callback duration diagnostic missing")
if 'contrastDidComplete(durationMS:' not in image_source or 'contrast_duration_ms=' not in image_source:
    raise SystemExit("contrast duration diagnostic missing")
if 'api_key' in image_source[image_source.index('private func imageContext'):image_source.index('private func imageContext') + 1200]:
    raise SystemExit("image diagnostics must not log authentication query data")

pixel_width_contract = "private var posterImageMaxWidth: Int { min(440, max(1, Int(ceil(resolvedWidth * UIScreen.main.scale)))) }"
if pixel_width_contract not in poster_source:
    raise SystemExit("V3PosterCard must request no more than its rendered device-pixel width")
if "guard width == nil else { return 440 }" in poster_source:
    raise SystemExit("fixed 440px request for 118pt Home poster cards reintroduced")

person_image_contract = "contentMode: .fill, showsLoadingIndicator: false)"
if person_image_contract not in person_source:
    raise SystemExit("person result poster grid must use the non-animated loading-state path")

print("poster grid smoothness source contract: PASS")
