from pathlib import Path

info = Path("Config/Info.plist").read_text()
shared = Path("Sources/UI/EmbySharedImageAndNavigation.swift").read_text()
v3_root = Path("Sources/UI/EmbyServerRootViewV3.swift").read_text()
v3_rows = Path("Sources/UI/EmbyHomeRowsV3.swift").read_text()
v3_shared = Path("Sources/UI/EmbyServerSharedV3.swift").read_text()
grid = Path("Sources/UI/EmbyPosterGrid.swift").read_text()
project = Path("project.yml").read_text()

assert "<key>CADisableMinimumFrameDurationOnPhone</key>" in info
assert "<true/>" in info.split("<key>CADisableMinimumFrameDurationOnPhone</key>", 1)[1][:80]
assert "import ImageIO" in shared
assert "CGImageSourceCreateThumbnailAtIndex" in shared
assert "kCGImageSourceShouldCacheImmediately" in shared
assert "Task.detached(priority: .utility)" in shared
assert ".onDisappear { loader.cancel() }" in shared
assert "showsLoadingIndicator" in shared
assert v3_rows.count("LazyHStack") >= 3
assert "showsLoadingIndicator: false" in v3_shared
assert "if selectedTab == .favorites" in v3_root
assert "if selectedTab == .search" in v3_root
assert "if selectedTab == .settings" in v3_root
assert "ForEach(Array(items.enumerated())" not in grid
assert "let loadAheadIDs = Set(items.suffix" in grid
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project
print("Scroll performance checks passed")
