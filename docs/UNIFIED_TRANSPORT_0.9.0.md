# Unified Transport 0.9.0

## Boundary
`UnifiedMediaTransportSession` owns network and byte-cache policy. Playback engines are consumers only.

```text
Emby stream URL -> 302 -> 115/CDN
          |
          v
UnifiedMediaTransportSession
  - RedirectResolver
  - two RangeHTTPClient slots
  - DownloadFirstSparseStore
  - PlaybackRangeMap
          |
      +---+---+
      |       |
      v       v
local HTTP   mpv stream_cb
AVPlayer     libmpv
```

## Scheduling invariants
1. No media-time-to-byte estimate is allowed.
2. Background claims are sequential from a byte anchor and use bounded lookahead.
3. User Seek only marks `awaitingRealDemand`; the next real non-metadata byte demand becomes the new anchor.
4. Metadata probes can be random but do not advance playback frontier.
5. Slot 0 is latency-sensitive and may service urgent holes. Slot 1 is kept alive for throughput.
6. If an urgent demand is already inside Slot 1's unfinished large block, Slot 0 may duplicate at most the urgent 2 MiB window instead of waiting for the whole Slot 1 block.
7. Wi-Fi continuous preload is bounded by session disk budget; cellular background preload is opt-in.

## Engine profiles
- Native-friendly MP4/MOV/M4V + H264/HEVC + common Apple audio: AVPlayer + unified local Range HTTP.
- Large/long MP4, non-native container/codec, or stored compatibility media: MPV + unified stream callback.
- Runtime speed/stall does not trigger engine switching after playback establishes.

## Buffer UI semantics
- Dim gray: verified media-time history for this playback session.
- Bright gray: current engine live playable range.
- Played track: current position.
- Byte-cache totals are diagnostic only and never converted to media time by file-size ratio.
