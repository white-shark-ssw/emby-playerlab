#!/usr/bin/env python3
from pathlib import Path

grid_source = Path("Sources/UI/EmbyPosterGrid.swift").read_text(encoding="utf-8")
image_source = Path("Sources/UI/EmbySharedImageAndNavigation.swift").read_text(encoding="utf-8")
poster_source = Path("Sources/UI/EmbyServerSharedV3.swift").read_text(encoding="utf-8")
person_source = Path("Sources/UI/EmbyPersonMediaView.swift").read_text(encoding="utf-8")

required_grid = [
    "return LazyVGrid(columns: columns, alignment: .leading, spacing: EmbyPosterGridMetrics.rowSpacing)",
    "ForEach(items) { item in",
    ".onAppear {\n                        guard let handler = onApproachingEnd, loadAheadIDs.contains(item.id) else { return }\n                        handler()\n                    }",
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
    "_loader = StateObject(wrappedValue: EmbyCachedImageLoader(initialURL: onImageLoaded == nil ? url : nil))",
    "if let onImageLoaded {\n            imageBody.onReceive(loader.$image.compactMap { $0 })",
    "} else {\n            imageBody\n        }",
    "loader.load(url, reportsLoadingState: showsLoadingIndicator)",
    "loader.cancel(reportsLoadingState: showsLoadingIndicator)",
    "if onImageLoaded != nil { reportedImageIdentifier = nil }",
    "reportedImageIdentifier = identifier\n                onImageLoaded(image)",
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

pixel_width_contract = "private var posterImageMaxWidth: Int { min(440, max(1, Int(ceil(resolvedWidth * UIScreen.main.scale)))) }"
if pixel_width_contract not in poster_source:
    raise SystemExit("V3PosterCard must request no more than its rendered device-pixel width")
if "guard width == nil else { return 440 }" in poster_source:
    raise SystemExit("fixed 440px request for 118pt Home poster cards reintroduced")

person_image_contract = "contentMode: .fill, showsLoadingIndicator: false)"
if person_image_contract not in person_source:
    raise SystemExit("person result poster grid must use the non-animated loading-state path")

print("poster grid smoothness source contract: PASS")
