# v0.12.3 Self Review

## Evidence from source=0.12.2 device log

- 63368 can begin above 20 MiB/s aggregate, but the legacy completed-claim LaneHealth still reset a lane that had just completed a 32 MiB claim at about 10.9 MiB/s because its peer retained a much higher historical average.
- During a large user seek, a cached/stale AVPlayer concrete read around 237 MiB consumed the pending-seek token before the true cache-miss dependency around 781 MiB. Bulk prefetch therefore stayed anchored in the old region while current playback was serviced by small urgent requests.
- The aggregate cache fraction is not positional coverage after sparse seeks. Rendering it as one solid bar falsely implies every byte to that visual edge is cached.
- 152901 repeatedly reached MPV file-loaded and active download, then the process restarted without normal close/stop. The regression began after v0.12.2 replaced the previously stable UIViewRepresentable external-layer host with a custom UIViewControllerRepresentable wrapper. No native crash stack is present, so the wrapper is treated as the highest-confidence regression suspect rather than a proven libmpv root cause.

## Changes reviewed

1. User-seek reanchor is now cache-miss authoritative: ordinary concrete-read is deferred while a seek is pending; blocked-read or explicit MPV byte-offset owns the new anchor. Stale sequential claims away from the new anchor are cancelled as tasks only, preserving persistent URLSession lanes.
2. Completed sequential Range statistics are advisory only. They may choose the protected bulk lane but cannot reset a connection. First-byte and live >=1 second window health remain the only automatic sequential connection reset paths.
3. Timeline renders actual sparse playback-byte cache ranges. AVPlayer/mpv verified/current buffer overlays are removed. Aggregate cache percentage remains diagnostic text only.
4. MPV surface returns to the v0.12.1 UIViewRepresentable ownership model. PlayerScreen supplies orientation-sensitive GeometryReader sizing; UI still does not force CAMetalLayer.drawableSize or set a layer delegate.
5. Deployment Target remains iOS 15.0. Media data path remains Emby control request -> 302 -> direct 115/CDN Range traffic; NAS media relay is not introduced.

## Limits

- Static gates and generic iOS compilation cannot prove sustained 115 CDN throughput or a native-device MoltenVK crash is eliminated.
- The three repeated 152901 restarts strongly correlate with the v0.12.2 surface-host change, but the supplied app log contains no iOS crash backtrace. Real-device v0.12.3 testing is required to confirm the regression is gone.
- Live-window rotation is intentionally retained for truly degraded connections; this build removes only the redundant completed-claim reset path.
