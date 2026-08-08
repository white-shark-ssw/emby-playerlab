# EmbyPlayerLab v0.12.0 Self Review

Version: 0.12.0 (Build 58)  
Deployment Target: iOS 15.0  
Primary runtime target: iPhone 15 Pro Max / iOS 17.0

## Scope

v0.12.0 is a scheduler revision, not another block-size or connection-count experiment. It keeps the Transport v3 sparse byte store and the existing two persistent URLSession lanes. The goals are:

1. keep useful bulk CDN work stable instead of letting speculative player range hints repeatedly preempt it;
2. dynamically protect the better sequential lane rather than permanently treating physical Slot 0 or Slot 1 as special;
3. let real foreground reads borrow the service lane immediately, while allowing a true second foreground read head to use both lanes when playback correctness requires it;
4. proactively warm the MP4 tail index for very large MP4 files so MPV does not download a large head cache while waiting for a late-discovered tail index;
5. keep MPV's valid demux cache visible on the timeline during transient buffering states.

No third/fourth upstream connection is introduced in this release.

## Evidence from the supplied v0.11.2 device log

The user-visible throughput problem is not a simple inability to reach high speed. The log contains sequential ranges in the tens of MiB/s and combined windows above 20 MiB/s, but also long periods in the low single-digit MiB/s range. The same session repeatedly cancels a sequential secondary task when a foreground request arrives. Persistent URLSession reuse is often working, but some post-cancellation requests return to `reused=false` and pay another first-byte/connect penalty.

This supports a scheduler-churn diagnosis: peak bandwidth exists, yet the application does not preserve the work/connection that achieved it consistently enough.

The release does **not** claim that scheduler churn is the only remaining reason EPlayerX is faster. Real-device v0.12.0 logs must still show whether CDN lane quality remains unstable after churn is reduced.

## 63368 / normal AVPlayer scheduling

### Previous behavior

AVFoundation emits both real reads and speculative range announcements. Earlier Transport v3 revisions could turn an ordinary `range-demand` into an urgent request, cancel a sequential secondary lane, and then rebuild background prefetch after the foreground request completed.

That is harmful when the speculative request never becomes an actual read.

### Scheduler v2 behavior

`range-demand` without concrete consumption is now a hint only:

- it may wake the scheduler;
- it may not install urgent foreground work;
- it may not preempt a healthy sequential connection.

`concrete-read`, `blocked-read`, and MPV `byte-offset` remain authoritative.

When both lanes are sequential and a real foreground read needs uncached bytes:

- the recently faster sequential lane is the protected bulk lane;
- the opposite lane is cancelled and borrowed for foreground work;
- the protected lane continues downloading;
- after foreground completion, the borrowed lane returns to sequential prefetch.

If the player exposes a true second simultaneous foreground read head, the remaining bulk lane may also be borrowed. This preserves the poorly-interleaved MP4 behavior fixed in earlier versions: playback dependencies outrank background throughput.

## Dynamic protected bulk lane

The scheduler keeps a peer-relative EWMA from successfully completed sequential claims. When one fresh lane is at least 20% faster than its peer, that lane becomes `preferredBulkSlot`.

This is deliberately independent of physical Slot 0/Slot 1 identity. The foreground service lane is normally the opposite physical lane.

Existing conservative slow-lane rotation remains:

- only successful sequential completions are health samples;
- a recent peer must prove the whole network is not simply slow;
- two clearly degraded samples are required;
- the lane session is rotated only while idle;
- rotation has a cooldown;
- if the protected lane is rotated, protection fails over to the peer.

Known limitation: a lane repeatedly preempted before completing a sequential claim may accumulate health samples slowly. v0.12.0 does not add partial-task health scoring because that would broaden the state machine in the same release.

## 63360 progressive-gap regression remains covered

A concrete read may fall inside a 32 MiB sequential claim even though the network head is still many MiB behind it. The 2 MiB progressive-gap rule remains, but it is now physical-lane agnostic:

- if the requested byte is <= 2 MiB ahead of the actual sparse-store progressive head, wait for the warm stream;
- otherwise create foreground urgent work on the other available lane.

This preserves the v0.11.2 63360 fix after dynamic bulk-lane selection.

## 152901 large-MP4 startup

The supplied log shows a 5,883,702,464-byte MP4 and prior investigation identified the relevant startup tail read at byte 5,873,522,321, only about 10.18 MiB from EOF.

### Previous behavior

MPV could trigger this tail access only after substantial head downloading had already begun. If the critical tail request landed on a cold/slower lane, `file-loaded` could be delayed even while the application had already cached 100+ MiB from the head.

### Scheduler v2 behavior

For MP4 resources >= 4 GiB:

1. start with the existing 1 MiB head warmup on Slot 0;
2. plan the final 16 MiB as startup-tail metadata immediately when the resource resolves;
3. do not cancel the 1 MiB head request if MPV asks for the tail before it finishes;
4. after the first head claim completes, queue the final-16MiB tail warmup;
5. the planned startup tail may only start on Slot 0's already-warmed persistent session;
6. the generic metadata path explicitly excludes this planned startup tail, so an idle cold Slot 1 cannot steal it;
7. once secondary preload is enabled, Slot 1 may continue sequential head prefetch while Slot 0 loads the critical tail.

The final 16 MiB covers the known 152901 startup tail offset.

This does not parse MP4 atoms itself and does not claim every large MP4 stores all required indexes in the final 16 MiB. It is a targeted warmup based on the actual 152901 access pattern. If another file requests an index outside that window, its concrete read still falls back to ordinary foreground scheduling.

## MPV timeline visibility

MPV already exposes `demuxer-cache-duration`. The previous persistent-history filter discarded ranges whenever `snapshot.isBuffering` was true, which can make the gray buffer history look absent during startup even when MPV reports a valid current-position cache range.

v0.12.0 no longer uses transient `isBuffering` as that gate. It requires a real MPV buffered range that covers the current position and extends at least 0.25 seconds forward, then retains it only when `time-pos` progression confirms a valid playback sequence.

No byte-percentage-to-time conversion is introduced for partial VBR media. Proven full-file byte coverage still promotes the persistent cache overlay to the full duration using the existing full-cache rule.

## Self-review findings caught before PR

The pre-PR review caught and corrected:

1. a temporary patch workflow re-entered and inserted `configureStartupWarmupIfNeeded` three times; cleanup now collapses it and the permanent gate requires exactly one helper;
2. stale urgent cancellation still inspected only Slot 0 after foreground roles became dynamic; it now checks both lanes;
3. the 63360 progressive-gap path still inspected only Slot 0; it now finds whichever physical lane owns the sequential claim;
4. planned startup-tail metadata could age out of the old 35-second heuristic on a weak connection; a planned warmup remains startup metadata until completed;
5. generic metadata scheduling could steal planned 152901 tail work onto idle Slot 1 before Slot 0 head warmup finished; generic scheduling now explicitly excludes planned startup-tail work;
6. old CI invariants encoded physical Slot 1 as the permanent foreground victim and were updated to behavior-level, slot-agnostic checks.

## Permanent CI gates

`check_scheduler_v2_invariants.py` verifies:

- speculative range hints return before urgent installation;
- protected bulk is dynamic rather than physical-slot hardcoded;
- foreground uses the service lane first;
- a second real foreground head may borrow the remaining bulk lane;
- progressive-gap lookup works on either sequential lane;
- large-MP4 final-16MiB warmup exists;
- startup tail uses the dedicated Slot 0 path before generic metadata;
- generic metadata cannot steal planned startup-tail work;
- startup helper is unique;
- stale urgent cancellation covers both lanes;
- MPV cache history does not disappear solely because of transient buffering;
- v0.12.0 / Build 58 and iOS 15.0 settings are consistent;
- both Validate Source and unsigned IPA workflows run this gate;
- temporary construction files are absent from the final repository.

The older scheduler, Transport v3, seek-stall, startup/lane-health, 63360 and 63368 regressions remain active as well.

## Deliberately unchanged

- exactly two normal upstream 115/CDN connections;
- `RangeHTTPClient` persistent-session implementation;
- sparse ByteStore and RangeMap storage model;
- MPV renderer / Metal surface;
- AVPlayer ResourceLoader consumer interface;
- double-tap gesture behavior;
- Emby progress reporting;
- STRM -> Emby/OneStrm -> 302 -> 115/CDN direct media path;
- Deployment Target iOS 15.0.

## Real-device acceptance focus

### 63368

Observe long normal-play intervals, not only peak values. Expected Scheduler v2 logs include:

- `UnifiedSchedulerV2 hint-only ... action=keep-bulk` for speculative range announcements;
- `protected bulk changed slot=...` only when completed-lane evidence justifies it;
- `foreground borrow slot=... preserveBulk=...` for actual uncached reads;
- fewer sequential cancellations caused by ordinary AVPlayer range churn.

The important metric is whether the medium/low throughput periods become shorter and whether effective cache lead stays ahead of playback on a 5-6 MiB/s constrained link.

### 152901

Expected startup order:

- `large-mp4 warmup planned`;
- 1 MiB head sequential request;
- `head warmup complete ... action=queue-tail`;
- Slot 0 `role=metadata reason=startup-tail-...` for the final 16 MiB;
- `tail warmup complete`;
- MPV `file-loaded` / first picture should occur without first downloading 100+ MiB from the head while waiting on the index.

The gray timeline should retain valid MPV demux cache once MPV reports a current-position buffer range and time-pos progresses.

## Remaining uncertainty

v0.12.0 does not claim EPlayerX-level sustained throughput until device evidence confirms it. If throughput still falls into distinct high/medium/low plateaus after Scheduler v2 removes speculative preemption, the next investigation should focus on live lane health and 115/CDN connection behavior (including partial-task throughput and controlled lane replacement), not another round of block-size guessing.
