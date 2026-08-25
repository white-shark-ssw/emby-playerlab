# OnePlayer 0.14.19 Build186

- Integrates the Build185 home-carousel interaction contract onto the current accepted Build184 `main` runtime baseline.
- Preserves the established full-page foreground slide: Logo, rating, year, type and overview continue to move with their carousel page.
- Preserves zero-distance drag delivery, one-time 0.5 pt axis acquisition and continuous left/right reversal from Build185.
- Adds passive per-gesture timing diagnostics only: first DragGesture sample, axis-lock translation, first transition translation, sample count/duration, average callback Hz and maximum sample gap.
- Emits one `HomeCarouselDragTiming` log line when the gesture ends; no per-frame logging, interpolation, debounce, throttle, timer, retry or fallback is added.
- Keeps ProMotion opt-in, persistent backdrop/blur, commit/cancel/auto-advance timings, detail interaction and vertical Home scrolling unchanged.
- Does not change PlayerController, MPV fast Seek, PiP, UnifiedTransport, Range/302/115 client-direct playback, session cache, episode selection/order or native navigation.
- Deployment Target remains iOS 15.0; target validation remains iPhone 15 Pro Max / iOS 17.0.
