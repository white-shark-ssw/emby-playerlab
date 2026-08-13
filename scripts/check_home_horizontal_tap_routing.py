from pathlib import Path

v3 = Path("Sources/UI/EmbyServerRootViewV3.swift").read_text()
shared = Path("Sources/UI/EmbySharedImageAndNavigation.swift").read_text()
project = Path("project.yml").read_text()

start = v3.index("    private func landscapeRow")
end = v3.index("\n}", v3.index("    private func posterRow", start))
rows = v3[start:end]
assert "EmbyPosterDetailLink(item: item, client: client)" in rows
assert ".environment(\\.embyPosterGridNavigationState, posterNavigationState)" not in rows
assert '.frame(width: 118, alignment: .leading)' in rows
assert 'NavigationLink(destination: EmbyMediaDetailView(item: item, client: client)) { V3PosterCard' not in rows
assert 'EmbyGridPosterNavigationLink' in shared
assert 'route=cell-link' in Path("Sources/UI/EmbyPosterGrid.swift").read_text()
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project
print("Home horizontal poster tap routing checks passed")
