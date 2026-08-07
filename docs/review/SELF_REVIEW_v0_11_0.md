# v0.11.0 Transport v3 Self Review

## Scope

Transport v3 is a transport-architecture change. It does not change MPV surface geometry, double-tap gesture semantics, the progress-bar appearance, Emby progress reporting, or the iOS deployment target.

Version: 0.11.0 (Build 54)
Deployment Target: iOS 15.0
Primary test device remains compatible with iOS 17.0.

## Evidence that motivated the change

### EmbyPlayerLab logs

The v0.9.x Unified transport repeatedly completed, cancelled, and reopened Range requests. The background streaming path created a new URLSession inside each RangeStreamLoader and invalidated that session when the Range finished or was cancelled. This made connection/CDN warm-up disposable.

The v0.10.0 KTV localhost proxy experiment failed before receiving media bytes in the user's Emby -> 302 -> 115 path. KTVHTTPCache error -192703 maps to response-status-code rejection, so KTV is no longer the automatic playback transport.

### EPlayerX decrypted-binary observations

The uploaded decrypted EPlayerX binary does not provide the application's original Swift/JavaScript source. It does expose enough Swift/native metadata to identify a KSPlayer + FFmpegKit based player and a separate PreLoadIOContext family, including names such as CacheIOContext, ReadCacheIOContext, URLContextDownload, LimitSeparatePreLoadIOContext, logicalPos, seekOffsets and bytesRead.

Transport v3 does not copy proprietary EPlayerX code. The design lesson taken from those observations is only architectural: keep random-access player reads, sparse cache state, and background network download responsibilities separate.

## Transport v3 architecture

Automatic native media:

AVPlayer ResourceLoader -> shared TransportDataSession -> sparse byte store -> persistent Range lane pool -> 115/CDN

Automatic compatibility media:

MPV mpv_stream_cb -> the same shared TransportDataSession -> the same sparse byte store -> the same persistent Range lane pool -> 115/CDN

KTVHTTPCache remains available only as a diagnostic engine and is not used by automatic playback.

## Persistent connection rules

1. Every upstream streaming lane owns one long-lived URLSession for the lifetime of the transport.
2. Starting another Range creates a URLSessionDataTask, not another URLSession.
3. Normal Range completion never invalidates the lane session.
4. Cancelling a Range cancels only that task; the lane session remains alive.
5. The entire connection pool is explicitly invalidated only when UnifiedMediaTransportSession stops/deinitializes.
6. The resolver-derived final request headers are reused. Transport v3 does not hard-code a 115Browser User-Agent.
7. Authorization, X-Emby-*, X-MediaBrowser-* and cookie handling remains separated from unrelated redirect origins.

## Scheduler review

### Startup

The first real player demand may install an urgent range. Progressive chunks are written to the sparse store immediately. Once the scheduler enters sequential preload, later player reads inside that active sequential claim do not promote/cancel/reopen the same Range.

### Normal sequential playback

A sequential task continues across player reads that fall inside its claim. When it completes, a later Range is issued on the same lane URLSession so the underlying connection can be reused.

### User seek outside the active claim

A real post-seek byte demand may cancel the obsolete task and re-anchor playback. This is intentional: a far seek must prioritize the new position. The URLSession object is still preserved, although whether the underlying HTTP connection itself remains reusable after cancelling an in-flight HTTP/1.1 response is server/CFNetwork dependent.

### Metadata reads

Metadata remains separate from playback urgent state. Tiny metadata may use the secondary slot while urgent playback is active; larger metadata remains prioritized without merging metadata and playback pending state.

### Engine switch

ResourceLoader AVPlayer and MPV both consume PlaybackTransportContext.session. Switching between those automatic engines does not create a KTV proxy/cache handoff and does not create a second Unified transport.

### Stop

Transport stop cancels active tasks, closes the sparse store, then explicitly invalidates the RangeHTTPClient pool. This prevents idle URLSessions surviving a closed player.

## Storage-path review

DownloadFirstSparseStore uses a single open file descriptor and positional pwrite/pread. It does not reopen the media file per chunk and does not fsync every chunk. Persistent range metadata is written only after an 8 MiB delta (or on close), so no second obvious structural throughput bottleneck was found in the store path.

## Diagnostics added for the real-device test

TransportV3 logs identify persistent lane task start/finish/cancel.

TransportV3Metric logs URLSessionTaskMetrics including:

- lane/task
- isReusedConnection
- network protocol
- connect time
- redirect count

The important validation is not only raw MB/s. After the first completed Range on a lane, later normal sequential tasks should commonly report reused=true. If throughput remains low while connection reuse is true, the next investigation should move to CDN response pacing / Range sizing / socket-level behavior rather than rebuilding the player reader layer again.

## Merge gates

Before merge to main:

- transport scheduler invariant must pass;
- Transport v3 invariant must pass;
- RangeMap smoke must pass;
- KTV diagnostic dependency and MPVKit must still resolve;
- Xcode 16.4 generic iOS device compile must pass;
- project build settings must keep iOS 15.0;
- temporary migration workflows/scripts must be absent from the final diff;
- Build Unsigned IPA must name the artifact as v0.11.0 and run Transport v3 invariants before Release compilation.

## Known uncertainty / real-device acceptance

No CI test can prove 115 CDN throughput. v0.11.0 must not claim EPlayerX-level bandwidth until the iPhone test confirms it.

The first real-device acceptance test should focus on item 63368, then 152901. Primary evidence:

- automaticProfile must be UnifiedTransportV3, not KTVProxyTransportV2;
- TransportV3Metric should show connection reuse after warm-up;
- normal playback should no longer show repeated in-range sequential -> urgent cancel/reopen cycles;
- sustained networkBps should materially improve compared with the v0.9.x few-MB/s behavior;
- far seek must still prioritize the new byte position immediately;
- no video bytes may pass through the NAS.
