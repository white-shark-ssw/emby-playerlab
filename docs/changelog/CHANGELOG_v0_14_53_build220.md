# OnePlayer 0.14.53 / Build220

## Grid display presentation A/B + transparent-image regression correction

- Continues the Build218 grid/display-only UIKit presentation A/B based on Build212 target-device evidence: 11 real grid dragging hitches landed 0.0–20.1 ms after newly visible 378px network/display poster publication.
- Preserves the accepted Build216 overall product baseline, including Build213 Favorites/Library page persistence and Build216 detail episode-range inertia behavior.
- Pure display images with no loading indicator and no `onImageLoaded` callback keep the existing loader, disk cache, decoded-image pool, request size, diagnostic source tags and immediate delivery, while the existing loader publisher feeds a UIKit `UIImageView` surface directly so surrounding SwiftUI poster cells do not observe loader `objectWillChange` for this path.
- Build218 target-device Home testing confirmed a visual regression on transparent carousel Logo images: the shared UIKit surface retained `secondarySystemBackground` after an image loaded, exposing a rectangular backdrop through transparent pixels. Exact source proved the carousel owner file itself was unchanged.
- Build220 changes that shared surface only so image-present state uses a clear background while nil-image placeholder state keeps `secondarySystemBackground`. No Home carousel owner source is modified.
- Callback/loading-indicator paths remain on the existing SwiftUI implementation. Existing 3-column layout, rendered-device poster pixel width, person-result poster policy, native navigation and grid diagnostics remain unchanged.
- Build218 Home vertical scrolling still visibly hitched on the target device; Build220 does not claim to fix Home and must not be evaluated as a carousel change. The grid A/B remains the runtime purpose of this candidate.
- Build219 poster identity was retired before distribution after the independent Home-carousel task created a Build219 branch. Build220 is the next verified-free poster identity.
- No image-quality reduction, timer, debounce, throttle, retry, fallback, page-data ownership change, scroll-physics change or carousel interaction change.
- Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM→302→115/CDN client-direct paths are untouched. Deployment Target remains iOS 15.0.
