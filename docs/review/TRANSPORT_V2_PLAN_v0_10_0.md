# v0.10.0 Transport v2 Plan

## Goal

Stop tuning UnifiedTransport slot/block parameters and restore 115/CDN throughput as the primary project milestone.

## Evidence

- v0.9.6 item 63368 repeatedly receives about 0.7–3 MB/s per urgent Range, with frequent sequential -> urgent cancellation/reopen cycles.
- v0.9.6 item 152901 head/tail ranges are also around 0.7–1.2 MB/s.
- Historical KTVHTTPCache builds on the same device/server path reached materially higher per-lane throughput (commonly ~8–16 MB/s, with higher combined periods).
- 115 direct-link projects document User-Agent binding between direct-link resolution and media requests.

## Architecture

Automatic playback becomes local-HTTP-proxy first:

- native-friendly media: KTVHTTPCache localhost proxy -> AVPlayer
- compatibility/large indexed media: KTVHTTPCache localhost proxy -> MPV
- UnifiedTransport remains available only for explicit diagnostic/fallback engines

## Transport rules

1. All KTV remote requests use one stable 115Browser-compatible User-Agent for both the original Emby/OneStrm request and redirected 115/CDN requests.
2. Do not forward Emby authorization/token headers to 115/CDN.
3. Background prefetch uses long 512 MiB claims instead of frequent 16/32 MiB connection churn.
4. Start the second prefetch lane after a short primary warmup; keep the primary connection alive during playback starvation and yield only the secondary lane.
5. AVPlayer and MPV consume the same localhost cache/proxy architecture.
6. Deployment Target remains iOS 15.0.

## Merge gate

- final diff self-review
- static Transport v2 invariants pass
- Xcode 16.4 generic iOS device compile passes
- iOS deployment target remains 15.0
- no temporary patch workflow/scripts remain
