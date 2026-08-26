# OnePlayer 0.14.37 / Build204

Poster-heavy scrolling follow-up after Build202 target-device rejection.

## Real-device evidence driving this build

The Build202 target-device recording `RPReplay_Final1787766039.mp4` is 510×1108, 30 fps, 205 frames / 6.833 s. Around 4.067 s, content movement stalls for one recorded frame: prior vertical motion is about -6.36 px, the stalled frame is 0 px, and the next frame catches up about -26.19 px. Build202 therefore did not solve the visible stop/catch-up hitch.

## Build204 product delta from Build202

- Ordinary poster images with no `onImageLoaded` callback no longer install the `loader.$image` Combine subscriber at all.
- For those ordinary images only, `EmbyCachedImageLoader` is seeded from the existing decoded-memory cache when its `StateObject` is first created. A warm-cache cell can render the cached `UIImage` in its first body pass instead of `onAppear` synchronously publishing `image = rendered` and causing an immediate second SwiftUI invalidation.
- Real callback paths used by Hero/detail/carousel are intentionally not seeded through this shortcut; their existing image-publication/callback semantics are preserved.
- Build202's existing lazy-container, image-size, loading-state and callback-state reductions remain.

No Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM→302→115/CDN path and no active Home-carousel gesture/state-owner file is changed.

Evidence at changelog creation: code written + source-contract checker updated; CI / IPA / Build204 real-device result pending.
