# OnePlayer 0.14.70 / Build237

- Retains the Build236 carousel start-step, Build231 foreground compositing, Build226 Hero residency and Build228 release-tail contracts.
- Lowers only the predicted-distance fling commit gate from `0.48 × width` to `0.24 × width`; the ordinary actual-progress commit threshold stays `0.28`.
- Fixes the persistent-backdrop source-over crossfade so the outgoing image stays fully covering the system background while the incoming image fades over it, preventing the mid-transition light-background leak/white flash caused by two complementary semi-transparent image layers.
- No Player / MPV / PiP / Transport / Cache / Emby Session / STRM / 302 / Range path changes.
