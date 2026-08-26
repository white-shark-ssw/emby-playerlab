# OnePlayer 0.14.39 / Build206

## Poster scroll hitch diagnostics

- Build204 was real-device rejected: visible stop/catch-up jitter still occurs on Home and library poster-heavy pages.
- Build206 is diagnostic-only; it does not change poster layout, navigation, image loading policy, carousel behavior, or playback/transport contracts.
- While poster links are visible, one shared `CADisplayLink` records only frame gaps of at least 30 ms.
- A hitch record includes the most recent poster-cell appearance route (`row` or `grid`), image commit age, and grid load-ahead age.
- Ordinary frame callbacks do not write logs, so the diagnostic does not add per-frame logging I/O before a hitch.
- Existing Build204 image/cache behavior remains unchanged.
- Deployment target remains iOS 15.0.
