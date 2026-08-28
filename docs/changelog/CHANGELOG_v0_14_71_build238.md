# OnePlayer 0.14.71 / Build238

- Measurement-only carousel release-intent diagnostics on top of Build237.
- Logs actual/end translation, latest predicted endpoint, predicted extra travel, last-move delivered/coalesced real-touch velocity, terminal delivered velocity and touch duration.
- Retains Build237 white-flash correction and its existing 0.24×width predicted-total-distance release gate unchanged so the log can measure why that distance-based approach still feels too resistant.
- Retains Build236 start-step handling, Build231 foreground compositing, Build226 Hero residency and Build228 max-refresh-through-settle/release tail.
- No Player / MPV / PiP / Transport / Cache / Emby Session / STRM / 302 / Range changes.
