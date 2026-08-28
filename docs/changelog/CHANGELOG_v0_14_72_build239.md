# OnePlayer 0.14.72 / Build239

- Replaces the rejected predicted-total-distance carousel fling gate with a direction-aware latest-delivered-move velocity gate.
- Keeps the ordinary slow-drag commit threshold at 0.28 progress.
- Uses 600 pt/s as the first target-device A/B threshold, selected inside Build238's measured empty interval between short slow drags (0–160 pt/s) and intentional quick flicks (~1140–2240 pt/s); this is a OnePlayer tuning value, not an asserted EX constant.
- Retains Build237 persistent source-over white-flash correction, Build236 start-step handling, Build231 foreground compositing, Build226 Hero residency and Build228 max-refresh-through-settle/release tail.
- Adds release-decision logging only at touch release; no timer/interpolation/debounce/throttle or second gesture owner.
- No Player / MPV / PiP / Transport / Cache / Emby Session / STRM / 302 / Range changes.
