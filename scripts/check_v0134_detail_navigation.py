from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"::error::{message}")


detail = Path("Sources/UI/EmbyMediaDetailView.swift").read_text()
nav = Path("Sources/UI/ImmersiveUIComponents.swift").read_text()
grid = Path("Sources/UI/EmbyPosterGrid.swift").read_text()
shared = Path("Sources/UI/EmbySharedImageAndNavigation.swift").read_text()
project = Path("project.yml").read_text()

require('contentMode: .fill, onImageLoaded:' in detail, "Hero must use one clear fill image that always covers elastic height")
require('contentMode: .fit, onImageLoaded:' not in detail, "Hero must not use fit mode that exposes a second layer during overscroll")
require('.blur(radius: 13)' not in detail, "Hero must not contain the duplicated blurred image")
require('heroImageScale(' not in detail and 'heroImageSize' not in detail, "fixed-height Hero cover-scale architecture must stay removed")
require('.mask(' in detail and 'location: 1.00' in detail, "Hero must fade continuously into persistent backdrop")
require('GeometryReader { proxy in' in detail and 'persistentBackdrop' in detail, "persistent backdrop must own the viewport")

for forbidden in ['interactivePopGestureRecognizer', 'UIGestureRecognizerDelegate', 'transitionCoordinator', 'popViewController(']:
    require(forbidden not in nav, f"visual navigation layer must never own native pop behavior: {forbidden}")
require('navigationItem.standardAppearance = appearance' in nav, "immersive navigation appearance must be destination-scoped")
require('source-snapshot-install' in nav and 'snapshotView(afterScreenUpdates: false)' in nav, "native interactive pop must retain a visible source-page fallback")
require('nativeInteractivePop() -> some View { self }' in nav, "nativeInteractivePop compatibility modifier must remain a no-op")

require('route=cell-link' in grid, "stable per-cell grid route must remain")
require('EmbyGridPosterNavigationLink' in shared, "stable per-cell NavigationLink implementation must remain")
require('EmbyPosterGridNavigationHost' not in grid and 'EmbyPosterGridNavigationHost' not in shared, "rejected reusable hidden grid NavigationLink must not return")
require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
print("v0.13.4 detail/navigation visual invariants: OK")
