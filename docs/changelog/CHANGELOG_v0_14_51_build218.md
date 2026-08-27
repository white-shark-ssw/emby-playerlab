# OnePlayer 0.14.51 / Build218

## Grid display presentation A/B candidate

- Based directly on Build212 target-device grid evidence: 11 real dragging hitches landed 0.0–20.1 ms after newly visible 378px network/display poster publication.
- Build218 is based on the accepted Build213 page-cache main baseline; Favorites/Library page persistence remains included and unchanged. Build214/215 are independently owned by the Home-carousel task and are not included.
- The candidate is grid/display-only. It does not carry the old poster Home motion-probe file and does not modify Home carousel owner files.
- Pure display images with no loading indicator and no `onImageLoaded` callback keep the existing loader, disk cache, decoded-image pool, request size, diagnostic source tags and immediate delivery, but stop observing loader `objectWillChange` through the surrounding SwiftUI poster cell.
- The existing loader publisher feeds a UIKit `UIImageView` surface directly for that display-only path. Callback/loading-indicator paths remain on the existing SwiftUI implementation.
- Existing 3-column layout, rendered-device poster pixel width, person-result poster policy, native navigation and grid hitch diagnostics are preserved.
- No image-quality reduction, timer, debounce, throttle, retry, fallback, page-data ownership change, scroll-physics change or carousel interaction change.
- Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM→302→115/CDN client-direct paths are untouched. Deployment Target remains iOS 15.0.

- Build218 compiler correction: the UIKit display surface now explicitly accepts `SwiftUI.ContentMode`, avoiding the `UIView.ContentMode` name shadowing proven by the retired poster Build216 Release compiler log. No runtime behavior is added by this correction.
- Poster Build217 identity was retired before distribution after the independent Home-carousel cadence task claimed Build217; Build218 is the next verified-free poster identity.
