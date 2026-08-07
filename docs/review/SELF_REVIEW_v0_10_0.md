# v0.10.0 Transport v2 Self Review

## Why v0.10.0 is an architecture change

v0.9.6 still showed 115/CDN throughput around hundreds of KiB/s to a few MiB/s on items 63368 and 152901, while the same device/network can reach much higher throughput in EPlayerX. Repeated UnifiedTransport slot/block tuning did not solve the bottleneck.

The old UnifiedTransport stream path also creates a new URLSession for each streamed Range and repeatedly cancels/reopens ranges when foreground demand crosses preload boundaries. Historical KTVHTTPCache builds in this repository reached materially higher throughput on the same media path. Therefore v0.10.0 stops treating UnifiedTransport as the automatic main transport.

## Transport v2 architecture

- Native-friendly media: KTVHTTPCache localhost HTTP proxy -> AVPlayer.
- Compatibility/large-indexed media: the same KTVHTTPCache localhost HTTP proxy -> MPV.
- UnifiedTransport remains available for explicit diagnostic/fallback engines only.
- KTVHTTPCache owns the remote HTTP connection pool, Range requests and sparse cache.
- Both AVPlayer and MPV consume localhost HTTP rather than custom byte callbacks.

## 115 request invariants

1. The original Emby/OneStrm media request and redirected 115/CDN requests use one stable `115Browser/36.0.0` User-Agent profile.
2. KTV additional headers are the final outbound header authority; player-localhost User-Agent cannot override the remote UA.
3. `Authorization`, `X-Emby-Token`, `X-MediaBrowser-Token`, and cookies are not forwarded as remote cache headers. The original Emby media URL keeps its query authentication.
4. The old independent RedirectResolver diagnostic probe is disabled in Transport v2 so a second UA-bound 115 link is not created beside the real KTV request.
5. No NAS video relay is introduced. KTV runs locally on the iPhone; after the server 302, media bytes still travel directly from 115/CDN to the phone.

## Throughput invariants

1. Background preload claims are 512 MiB long ranges, not repeated 16/32 MiB churn.
2. Primary lane starts first and remains alive across normal playback starvation.
3. Secondary lane starts after a short session-owned warmup; its start does not depend on UI/metrics polling.
4. Foreground starvation stops only Lane B. Lane A remains warm to preserve URLSession/TCP/CDN connection state.
5. A user Seek immediately stops Lane B and gives foreground traffic a one-second priority window while keeping Lane A alive.
6. Repeated Seek extends that priority window, so an earlier delayed resume cannot immediately restart Lane B during a later tap.
7. Lane B may resume after foreground priority clears.
8. KTVHTTPCache's persistent downloader is used as the shared remote connection pool.

## Session cache / engine switching

1. KTVAVPlayerEngine can hand off its KTVCachePlaybackSession before engine teardown.
2. KTVMPVPlayerEngine can receive and hand off the same session.
3. AVPlayer <-> MPV switches preserve already cached bytes and the KTV session rather than deleting/recreating it.
4. Closing the entire player still stops the owned KTV session normally.

## 63368 scenario walk-through

Expected:

- Automatic profile is `AVPlayer+KTVProxyTransportV2`.
- AVPlayer opens localhost immediately.
- The KTV primary long-range preload starts shortly afterward.
- Lane B joins after the short primary warmup.
- AVPlayer's own current-byte Range requests share KTV's persistent downloader/cache instead of promoting/cancelling UnifiedTransport ranges.
- No `UnifiedSlot` traffic should appear for the automatic path.
- The log should show `segment=536870912`, `uaProfile=115Browser/36.0.0`, and KTV `networkBps` as the primary throughput measurement.

## 152901 scenario walk-through

Expected:

- Automatic profile is `MPV+KTVProxyTransportV2`.
- MPV opens the localhost KTV proxy as a normal HTTP URL.
- MPV may request head/tail metadata through KTV without waiting for a serial 16 MiB UnifiedTransport head claim to finish first.
- Background long-range preload can continue through the same KTV cache/session.
- No `embyunified://media` stream is used in automatic MPV Transport v2.

## Continuous double-tap Seek

Expected:

- The first tap reaches the engine immediately; there is no debounce.
- KTV Lane B is stopped immediately on each Seek.
- KTV Lane A remains alive.
- Foreground localhost requests receive priority for at least one second after the most recent Seek.
- A newer tap extends the priority window.
- Cached Seek still benefits from the shared KTV cache.

## Failure / fallback review

- If KTV proxy preparation fails, the existing engine fallback remains available; this is not the performance target path.
- UnifiedTransport is retained for explicit diagnostic engines so Transport v2 can be compared against the previous architecture without deleting diagnostics.
- MPV surface, crash fixes and thumb-less timeline from v0.9.5/v0.9.6 are unchanged.
- Premature EOF and playback progress reporting remain in PlayerController and are not moved into the transport layer.

## Compatibility review

- Deployment Target remains iOS 15.0.
- KTVHTTPCache is already pinned at 3.1.0 in the existing project.
- No new third-party dependency is added.
- MPVKit remains the existing pinned package.
- Transport v2 uses APIs already exercised by the existing iOS 15 build path.

## Merge gate

Do not merge unless all are true:

- temporary Transport v2 patch workflow/scripts are deleted;
- final diff contains only intended source/config/permanent audit/docs changes;
- `scripts/check_transport_scheduler_invariants.py` passes for the retained Unified fallback;
- `scripts/check_transport_v2_invariants.py` passes for the new automatic path;
- Xcode 16.4 generic iOS device build succeeds;
- project settings still report `IPHONEOS_DEPLOYMENT_TARGET = 15.0`;
- the final PR diff is reviewed again after CI;
- no claim is made that v0.10.0 reaches 50 MB/s until the real iPhone/115 route proves it.
