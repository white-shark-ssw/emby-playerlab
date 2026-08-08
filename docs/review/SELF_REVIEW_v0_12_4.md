# EmbyPlayerLab v0.12.4 / Build 62 Self Review

## Scope

This patch is intentionally limited to scheduler correctness exposed by the supplied v0.12.3 real-device log for item 63368. It does not change the two-lane transport topology, 115/CDN redirect behavior, live-window lane-health thresholds, player routing, MPV surface, or iOS Deployment Target.

Deployment Target remains **iOS 15.0**. Target device iPhone 15 Pro Max / iOS 17.0 remains supported.

## Supplied-log findings

### 1. Sequential workers were allowed to outrun the contiguous frontier

At startup the trace showed the first lane filling the head, the second lane taking the adjacent range, and then the faster lane opening a farther third range while the adjacent range was still incomplete. This produces the visible pattern:

`[cached/frontier block] [hole / slow block] [farther cached block]`

That violates the intended Playback Anchor + Contiguous Frontier model. Total cached bytes can rise while immediately playable coverage does not.

### 2. Stall recovery could move the anchor backwards using stale AVPlayer traffic

The real post-seek cache-miss demand established an anchor at byte `213,909,504`. A later stall recovered from an old AVPlayer concrete read around byte `101,842,944`, moving the scheduler back into an obsolete region even though playback had already advanced.

Ordinary AVPlayer concrete reads are not sufficiently authoritative for stall recovery because AVFoundation can continue issuing cached/demux reads from older regions around a seek.

### 3. A satisfied pending urgent request could deadlock the scheduler

The old `scheduleSlots()` only started a pending urgent request when `!store.contains(urgent)`. If another task had already completed that range, the pending variable remained non-nil. The later critical-work guard then returned forever.

The final 63368 stall showed the signature directly:

- AVPlayer `bufferEmpty=true`
- `likelyToKeepUp=false`
- `AVPlayerWaitingToMinimizeStallsReason`
- Unified transport `slot0=idle slot1=idle networkBps=0`
- no new sequential request was launched

This is a scheduler state deadlock, not a 115 bandwidth shortage.

## Changes

### Authoritative stall anchor

- Replaced `lastConcretePlaybackDemand` with `lastBlockingPlaybackDemand`.
- Only `blocked-read` (actual cache miss) and MPV `byte-offset` update stall-recovery authority.
- Blocking demand expires after 12 seconds.
- Stall recovery no longer reanchors to arbitrary AVPlayer concrete reads.
- Reanchoring resets the sequential wave state.

### Pending critical-work cleanup

Before the critical-work early return, `scheduleSlots()` now removes a pending playback/metadata range if the sparse store already contains the full range.

This prevents a satisfied pending request from keeping both lanes permanently idle.

### Idle scheduler self-heal

`metrics()` now kicks `scheduleSlots(reason: "metrics-idle-repair")` when both slots are idle and the session is otherwise eligible to schedule work. This is a last-resort state-machine repair, not the primary scheduling path.

### Strict two-segment frontier waves

Sequential prefetch is now bounded to one two-segment wave for the full session:

- both workers may fill the two adjacent segments concurrently;
- if one worker finishes early, it cannot open a third farther segment until the current wave/frontier closes;
- the wave boundary is aligned to the same `playbackAnchor + segment grid` used by `PlaybackRangeMap`;
- seek/stall reanchor resets the wave.

The alignment is important. A reset at a 68 MiB frontier with a 32 MiB segment must align the wave base to 64 MiB and cap the wave at 128 MiB. The old `frontier + 64 MiB` calculation would cap at 132 MiB and could expose an erroneous 128-132 MiB third tail.

The 4 MiB bootstrap therefore progresses into adjacent waves such as:

- `4-36 MiB` + `36-64 MiB`
- `64-96 MiB` + `96-128 MiB`
- `128-160 MiB` + `160-192 MiB`

No farther sequential block is eligible until the active pair closes.

## Speed scope

The supplied log confirms real per-connection throughput variation. Some persistent 115/CDN ranges run much faster than others, and live-window lane rotation can materially improve a bad connection after replacement.

For v0.12.4 the live-window thresholds and reset policy are intentionally unchanged. This patch first makes every downloaded byte serve the contiguous playback frontier instead of allowing a fast lane to run far ahead of a slow frontier lane.

Do **not** claim that v0.12.4 solves the ~50 MB/s EPlayerX comparison. A dedicated speed pass should use the next real-device log after scheduler correctness is verified, then evaluate connection racing/dynamic concurrency or a raw same-URLSession baseline without mixing those variables into this stall fix.

## Private pre-PR regression checks

The following scheduler models were executed before creating a PR / starting macOS Actions:

1. exact 63368 authoritative anchor `213,909,504` survives stale concrete read `101,842,944`;
2. a pending urgent range already covered by cache is cleared and cannot hold the scheduler in the critical-work return;
3. stale blocking demand older than the 12-second freshness window does not move the anchor;
4. aligned wave reset at 68 MiB produces base 64 MiB / upper 128 MiB, not 132 MiB;
5. 4 MiB bootstrap followed by 32 MiB segments advances as adjacent two-worker waves with no legal third claim while the pair is incomplete.

All private scheduler regressions passed.

## Formal validation gate

`scripts/check_v0124_regressions.py` permanently checks the supplied 63368 deadlock/anchor/wave regressions and version/release invariants. Existing Transport v3, seek-stall, Scheduler v2, live-lane/startup, v0.12.2 and v0.12.3 gates remain enabled.

The only validation intentionally deferred to GitHub Actions is the part not reproducible in the current local environment: Xcode 16.4 dependency resolution and generic `iphoneos` compilation.

## Release

Version: **0.12.4**  
Build: **62**  
Deployment Target: **iOS 15.0**

Expected prerelease after merge:

- tag: `v0.12.4-build62-dev`
- title: `EmbyPlayerLab v0.12.4 Build 62`
- asset: `EmbyPlayerLab-v0.12.4-build62-<7-char-sha>-unsigned.ipa`
