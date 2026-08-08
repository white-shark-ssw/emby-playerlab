# v0.11.1 Seek Stall Self-Review

## Scope

This patch addresses post-seek stalls observed on item 63368 in the v0.11.0 Transport v3 build. It deliberately does not change the persistent RangeHTTPClient connection-pool architecture or make new throughput claims.

## Log evidence

The supplied `EmbyPlayerLab-1786172982.log` showed three independent scheduler problems:

1. During a pending user seek, AVFoundation could still issue stale/cached range hints from the old timeline. The old scheduler allowed such a range hint to consume the seek token and move `playbackAnchor` before the actual read position was known.
2. 63368 has legitimate far-apart demux read heads. Around one seek the actual reads alternated near 195,035,138 and 611,385,344 bytes; around another they alternated near 236,257,280 and 772,734,976 bytes. The old single-anchor rule treated each distant actual read as another timeline seek, repeatedly cancelling Slot 0 and ping-ponging between the two byte regions.
3. The log reported `cellularWindow=67108864` but Unified Transport started with `preloadWindow=0`. v3 was incorrectly inheriting the legacy KTV `ktvPreloadOnCellular` switch. After urgent ranges finished, both slots could become idle even with only ~0.25 seconds of playable buffer left.

The log also contained several `ResourceLoader request failed: 下载优先缓存已经关闭。` lines in the earlier long 63368 session. That symptom is not required to reproduce the later ~92 second stall, so this patch does not claim to have identified or fixed that lifecycle event. It remains a next-log observation item.

## Behavioral changes

- Every actual `session.read(offset:length:)` reports a `concrete-read` to the scheduler before cache lookup.
- During a pending seek, speculative/cached `range-demand` hints cannot consume the seek token. The first actual read (or MPV explicit byte offset) is authoritative.
- Actual reads are never classified as metadata by the old tiny/far-distance heuristic. Metadata heuristics remain available only for speculative range hints.
- The first post-seek concrete read establishes the primary playback anchor. Later far-apart concrete reads are classified as parallel demux read heads instead of re-anchoring/cancelling the primary head.
- Slot 1 can serve a second `urgentPlayback` claim while Slot 0 keeps the first real playback head warm.
- A failed urgent playback claim is requeued instead of being silently lost.
- A seek that reanchors onto already cached bytes immediately reschedules sequential preload.
- On cellular, Unified Transport uses `cellularPreloadBytes` directly. A zero-byte window is the explicit opt-out; the legacy KTV proxy toggle no longer disables Unified v3 preload.

## Scenario review

### Startup and metadata

Speculative range hints can still be classified as metadata. Actual demux reads override the heuristic and are always critical playback dependencies. This prevents tiny real audio/video reads from being mistaken for tail metadata.

### Normal contiguous playback

No behavior change to the persistent RangeHTTPClient pool. A real read that falls inside an active sequential Slot 0 claim still waits for progressive chunks instead of cancelling/reopening the warmed request.

### Single +10 second seek

The seek token remains pending until the first actual read. Old cached range hints cannot move the anchor. A cache-hit target still causes preload scheduling after the reanchor.

### Continuous +10 second seeks

Each new user seek refreshes the pending token. Intermediate speculative range hints remain hints. The final actual read establishes the final primary anchor.

### Far slider seek

The first concrete read at the new timeline position can still cancel Slot 0 when the active primary request does not contain the new target. This preserves immediate retargeting for a real user seek.

### Poorly interleaved dual read heads

After the post-seek primary anchor is established, a second far actual read is logged as `parallel-read-head` and does not overwrite the primary anchor. If Slot 0 is busy, Slot 1 may take the second urgent playback range. Synthetic regression pairs cover the 63368 byte offsets seen in the supplied log.

### Cached seek target

A real reanchor that immediately hits the sparse cache still calls `scheduleSlots(reason: "reanchor-cache-hit")`, so the downloader cannot stay idle solely because the first target bytes were already cached.

### Cellular playback

The configured cellular window is now authoritative for Unified Transport. With the observed 64 MiB configuration, `preloadWindow` should no longer be zero.

### Slot 1 failure and cooldown

A non-cancelled Slot 1 urgent failure requeues the playback range. Existing secondary cooldown behavior still applies before the slot is reused.

### Stop / teardown

No changes to Transport v3 teardown: transport stop cancels slot tasks, closes the sparse store, and explicitly invalidates the persistent RangeHTTPClient pool.

## Deliberate limits

- `pendingPlaybackUrgentRange` remains a single pending urgent slot rather than a general N-head queue. The supplied 63368 trace shows two dominant simultaneous read heads, matching the two available upstream lanes. Expanding to an arbitrary multi-head scheduler is intentionally deferred until logs prove it is needed.
- Background sequential preload still follows the primary anchor. The second far demux head is demand-driven urgent in this patch. If future logs show the second track is continuously bandwidth-limited, a dedicated secondary preload frontier can be considered separately.
- The unexplained `下载优先缓存已经关闭` messages remain an observation item and are not folded into this patch without stronger evidence.

## Merge gates

- Existing Transport scheduler invariants must pass.
- Existing Transport v3 invariants must pass.
- New `check_seek_stall_invariants.py` must pass, including synthetic 63368 dual-read-head regression pairs.
- Xcode 16.4 generic iOS device compile must pass.
- Deployment Target must remain iOS 15.0.
- Final diff must contain no temporary patch workflow or construction scripts.
