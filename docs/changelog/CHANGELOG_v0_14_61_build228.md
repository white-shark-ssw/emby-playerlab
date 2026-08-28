# OnePlayer 0.14.61 / Build228

## Poster grid MainActor timing diagnostics

- Continues the Build220 poster-grid UIKit display baseline after target-device testing found 3×3 smoothness was basically unchanged and rejected that display-path bypass as a sufficient fix.
- This build is measurement-only. It does not add a new smoothing, pacing, retry, fallback, timer, watchdog, cache, pagination or scroll-physics behavior.
- Measures the existing MainActor image publication path around `@Published image`, including total synchronous publication duration, publish-to-Combine-sink delay, UIKit `setImage` duration and publish-to-surface completion duration.
- Keeps the existing centralized motion-gated `PosterScrollHitch` detector unchanged and emits a paired `PosterScrollTiming` record only when that detector reports a >=30 ms moving-frame gap.
- Separately measures the existing library paged-poster apply phase and the existing synchronous persistent snapshot write after a page response has already arrived. The measurement records route/reset/start/received/applied counts so a hitch can be correlated with pagination work without changing page-data ownership.
- Existing image source/role diagnostics, image request size, decoded-image pool, disk cache, UIKit display surface, callback path, 3-column grid layout, native navigation, page-cache semantics and load-ahead behavior remain unchanged.
- Build227 / 0.14.60 is owned by the parallel Home-carousel task; poster diagnostics therefore use the next verified-free identity Build228 / 0.14.61.
- Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM→302→115/CDN client-direct paths are untouched. Deployment Target remains iOS 15.0.
- Evidence at source commit time: code written only. CI/IPA and target-device conclusions must be recorded separately after they exist.