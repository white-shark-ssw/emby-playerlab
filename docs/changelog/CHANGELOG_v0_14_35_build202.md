# OnePlayer 0.14.35 / Build202

## Poster-heavy scrolling smoothness candidate

Target: iPhone 15 Pro Max / iOS 17.0.

This candidate responds to target-device recording evidence showing a visible stop-one-recorded-frame then catch-up cadence while scrolling poster-heavy pages. The symptom is not limited to the shared 3-column LazyVGrid because Home poster rows use LazyHStack + V3PosterCard and show the same behavior.

Changes are intentionally narrow:

- keep the existing `LazyVGrid`, but move its two identical grid-owned Environment values from every cell to the grid ancestor;
- ordinary poster images with no `onImageLoaded` consumer no longer publish redundant callback-tracking `@State` updates;
- image loading state is published only when a loading indicator is actually rendered, and already-nil image state is not republished;
- `V3PosterCard` requests artwork at its actual rendered device-pixel width (capped at the existing 440 px), so a 118 pt Home poster on a 3× device requests about 354 px instead of the old fixed 440 px;
- actor/person result posters use the same no-loading-indicator path as the other poster grids.

Unchanged contracts:

- no list truncation, fake pagination or quality degradation;
- no timer/debounce/throttle/watchdog/retry/fallback;
- Home carousel gesture/state-owner files are unchanged;
- Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM→302→115-CDN client-direct paths are unchanged;
- Deployment Target remains iOS 15.0.

Evidence at source creation: code written. CI, IPA and target-device improvement are not claimed until separately observed.