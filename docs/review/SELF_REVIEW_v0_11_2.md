# EmbyPlayerLab v0.11.2 Self Review

Version: 0.11.2 (Build 56)  
Deployment Target: iOS 15.0  
Primary runtime target: iPhone 15 Pro Max / iOS 17.0

## Scope

This release is intentionally limited to transport stability, foreground-read scheduling, live throughput observability, and truthful full-cache timeline display. It does not add new playback engines, additional upstream connections, new UI gestures, or a higher Deployment Target.

## 1. 63360 post-seek stall: confirmed root cause

The v0.11.1 device log shows the failing seek around 193.75s:

- real concrete read re-anchored to byte `160497664`;
- Slot 0's declared sequential claim was `143654912..<167772160`;
- v0.11.1 treated membership in that 32 MiB claim as sufficient and logged `action=wait-progressive-chunk`;
- the actual contiguous frontier at the new anchor was still zero;
- Slot 1 was downloading unrelated background bytes around `201326592..<234881024`;
- AVPlayer reached 194s with only ~0.53s playable, the first-frame measurement timed out at ~3148 ms, then VideoFreeze/Stall recovery fired.

The defect is therefore not another timeline-to-byte parse error. It is a scheduler error: **claim coverage was incorrectly treated as data-arrival proximity**.

### v0.11.2 change

For a concrete read inside Slot 0's sequential claim, the scheduler now measures the progressive stream head from bytes actually present in the sparse store.

- gap <= 2 MiB: keep waiting for the warm sequential stream;
- gap > 2 MiB: preserve Slot 0 and borrow Slot 1 for an exact urgent playback Range from the requested byte.

The synthetic invariant fixes the 63360 example in CI:

- claim: `143654912..<167772160`
- observed stream head: `149946368`
- requested: `160497664`
- gap: > 2 MiB => must use parallel urgent.

A second synthetic case ensures a genuinely near progressive head still reuses the warm Range.

## 2. Preserve warmed CDN connections across ordinary seeks

v0.11.1 could cancel Slot 0's sequential Range on each real seek re-anchor. Even though `PersistentRangeStreamLane` keeps its URLSession object, task cancellation frequently produced a later `reused=false` transaction and paid another connection/startup penalty.

v0.11.2 removes `real-seek-demand` cancellation of ordinary sequential Slot 0 work. Foreground demand borrows the other slot first. Slot 0 is only replaced immediately when it is already stale foreground urgent work, or when both lanes are required for critical foreground dependencies.

Tiny metadata is also allowed to use Slot 1 while Slot 0 is busy so startup tail probing does not unnecessarily kill the warmed head request.

## 3. 63368 full cache but partial gray timeline: confirmed UI/data-source mismatch

The same device log reaches:

- resource length: `996085874` bytes;
- cached: `996085874` bytes;
- holes: `0`;
- Slot 0: idle;
- Slot 1: idle.

At that point the unified sparse byte source has every byte locally. However AVPlayer's `loadedTimeRanges` / accumulated verified time ranges remain fragmented after many seeks, so the gray cache overlay can remain well below full width and `forwardPlayable` can still be small at a newly visited timestamp.

Those are different concepts:

- `loadedTimeRanges`: what AVPlayer has currently demuxed/declared playable in media time;
- Unified ByteStore completion: whether every source byte can be served locally without network.

### v0.11.2 change

`TransportMetricsSnapshot` now exposes `resourceBytes`. When and only when:

- `resourceBytes > 0`;
- `cacheBytes >= resourceBytes`;
- `cacheHoleCount == 0`;

the persistent cache overlay is promoted to `[0...duration]` and logs `action=promote-full-duration`.

Partial VBR cache is still **not** converted to media time by byte percentage. The full-width promotion is restricted to proven 0..EOF coverage.

## 4. Throughput diagnostics were stale during long Range transfers

v0.11.1 recorded `bytesDownloaded` and speed samples only when an entire Range claim finished. A healthy 32 MiB transfer could therefore be actively receiving data while `networkBps` appeared stale or zero. That distorted both user-visible diagnostics and transport-health decisions.

### v0.11.2 change

Every received chunk now calls `recordNetworkBytes(...)` in both sequential and urgent/metadata paths. Whole-claim completion no longer adds the same bytes again.

Result:

- current speed tracks bytes while the request is in flight;
- `bytesDownloaded` remains network bytes transferred, including any true duplicate refetch;
- `cacheBytes` remains unique sparse-store bytes;
- duplicate network work can therefore be diagnosed instead of hidden.

## 5. What the log says about weak-network stability

The 63368 session shows large lane-quality variance: some completed ranges reach double-digit MiB/s while other 32 MiB ranges run around only a few MiB/s, and first-chunk latency varies from a few hundred milliseconds to multiple seconds. There are also many task cancellations around seek bursts, with later transactions sometimes reporting `reused=false`.

This release addresses the part supported strongly by the log: avoid destroying warmed background work for ordinary seeks, deliver far foreground reads on the other lane, and measure live throughput correctly.

It deliberately does **not** yet implement slow-lane eviction/rotation. If v0.11.2 logs still show one persistent lane remaining materially worse than the other for an extended window, the next transport change should be health-based lane replacement/rotation before simply increasing connection count.

## 6. Deliberately unchanged

- `RangeHTTPClient` persistent-session implementation is unchanged.
- Exactly two normal upstream lanes remain.
- No third/fourth connection is introduced.
- MPV rendering and engine selection are unchanged.
- Double-tap/seek UI behavior is unchanged.
- Emby progress reporting is unchanged.
- STRM -> 302 -> 115/CDN direct media path is unchanged.
- Deployment Target remains iOS 15.0.

## 7. Permanent CI gates

`check_transport_stability_invariants.py` enforces:

1. concrete in-claim reads farther than 2 MiB from the actual progressive head must use parallel urgent;
2. near-head reads must still reuse the warm stream;
3. ordinary seek must not restore `cancelSlot(0, reason: "real-seek-demand")`;
4. long Range speed must be sampled per received chunk, not only at completion;
5. full-duration cache promotion requires byte-complete, hole-free coverage;
6. the exact 63360 and 63368 synthetic regression values remain covered.

Both Validate Source and unsigned IPA Release builds run this invariant in addition to the existing scheduler, Transport v3, and seek-stall checks.

## 8. True-device checks for v0.11.2

### 63360

Repeat rapid +10s seeks through the previous ~194s failure area.

Expected when the requested byte is substantially ahead of the sequential stream head:

`foreground gap ... action=parallel-urgent`

followed by a Slot 1 `urgentPlayback` request. The seek should no longer sit for ~3 seconds merely because the target was somewhere inside Slot 0's 32 MiB claim.

### 63368 full-cache display

Once diagnostics show cache bytes equal resource bytes and holes=0, expect:

`transport cache complete ... action=promote-full-duration`

The persistent gray cache overlay should become full width.

### Weak network / throughput

With an externally limited or naturally weak link, observe:

- `networkBps` should update during a long Range instead of dropping to zero until claim completion;
- ordinary seek bursts should cause fewer sequential Slot 0 cancellations and fewer post-seek cold/reused=false starts;
- `forwardPlayable` should stay ahead of the playhead more consistently when effective upstream throughput is sufficient for the media bitrate.

If one lane remains persistently much slower while the other remains healthy, retain the log for the next health-based lane-rotation pass.
