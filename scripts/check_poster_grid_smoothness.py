#!/usr/bin/env python3
from pathlib import Path

grid_source = Path("Sources/UI/EmbyPosterGrid.swift").read_text(encoding="utf-8")
image_source = Path("Sources/UI/EmbySharedImageAndNavigation.swift").read_text(encoding="utf-8")

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
    "if onImageLoaded != nil { reportedImageIdentifier = nil }",
    "guard let onImageLoaded else { return }",
    "reportedImageIdentifier = identifier\n            onImageLoaded(image)",
]
for needle in required_image:
    if needle not in image_source:
        raise SystemExit(f"missing poster-image update contract: {needle}")

if "reportedImageIdentifier = identifier\n            onImageLoaded?(image)" in image_source:
    raise SystemExit("poster images without callbacks must not publish redundant reported-image state")

print("poster grid smoothness source contract: PASS")
