# v0.12.1 / Build 59 Self Review

## Scope

This revision is based on the real-device `source=0.12.0` log `EmbyPlayerLab-1786188847.log`. It intentionally changes only Unified Transport scheduling and the related regression gates. It does not change MPV rendering, AVPlayer rendering, gestures, Emby progress reporting, the STRM -> HTTP 302 -> 115/CDN direct-media path, or the iOS Deployment Target.

Deployment Target remains iOS 15.0.

## Evidence from v0.12.0

### 152901 startup

Observed sequence:

- Player Start: 11:33:01.357.
- 302/Range resolve ready: 11:33:02.931.
- The large-MP4 initial 1 MiB head completed around 11:33:04.314.
- libmpv's real near-EOF seek was byte 5,873,522,321 in a 5,883,702,464-byte file, only 10,180,143 bytes from EOF.
- v0.12.0 had already queued the fixed final 16 MiB, so it downloaded 6,597,073 bytes before libmpv's real required offset.
- The fixed 16 MiB startup metadata request was pinned to Slot 0 and took about 20.1 seconds at about 0.83 MB/s average.
- First non-zero playback position appeared around 11:33:26.221, about 24.9 seconds after Player Start.

Conclusion: the dominant startup delay was not renderer setup. It was the transport strategy: fixed proactive bytes plus one long critical metadata Range pinned to one poor connection.

### 63368 sustained throughput

Observed completed sequential samples included:

- Slot 0: ~9.51 MB/s -> 6.40 -> 4.27 -> 2.44 MB/s.
- At that time the existing completed-block health logic still had no fresh peer sample, so it could not classify Slot 0 as degraded.
- Slot 1 later produced ~16.06, 20.08 and 21.68 MB/s, proving the device/CDN path could sustain much higher throughput than the degraded lane.
- Existing lane health could therefore wait for one or more full long claims before making a useful decision.

Conclusion: end-of-claim health is too late for a 32 MiB claim when per-Range/per-connection quality can diverge dramatically.

## v0.12.1 design

### Demand-driven large-MP4 startup metadata

Removed the v0.12.0 proactive fixed final-16MiB strategy.

For MP4 >= 4 GiB:

1. Keep the small 1 MiB head path so libmpv can identify the container cheaply.
2. After that head completes, allow a 250 ms grace window for libmpv's real near-EOF byte seek to arrive before ordinary sequential prefetch resumes.
3. The first real startup tail demand defines the plan lower bound. The plan ends at EOF.
4. Split that exact range into 1 MiB-or-smaller startup-metadata chunks.
5. Give both normal upstream lanes startup-metadata work before resuming bulk sequential prefetch.
6. Do not increase the normal upstream lane count beyond two.

For the 152901 evidence above, this converts the old fixed 16 MiB request into ten 1 MiB-or-smaller chunks starting exactly at byte 5,873,522,321.

### Startup metadata straggler recovery

Each startup-metadata chunk records its start time. Each lane records the timestamp at which it most recently delivered startup-metadata bytes.

If a startup-metadata lane has delivered zero bytes after 1.5 seconds while its peer has delivered bytes after the slow chunk started:

- classify that chunk as a straggler;
- cancel only that slot task;
- put the missing chunk back at the front of the startup queue;
- reset the persistent stream lane only after the cancelled task has become idle;
- retry scheduling after reset.

The peer-progress check uses timestamps instead of only the peer's current per-task byte counter, because a fast peer may already have completed one chunk and started another before the slow lane's watchdog fires.

### Live sequential lane health

The old completed-claim lane health remains as a conservative fallback.

In addition, each sequential lane now tracks 1 MiB stream progress while the long Range is still active:

- first-byte peer timeout: 1.5 seconds when the other lane is already delivering useful data;
- hard no-first-byte guard: 3.0 seconds;
- recent throughput EWMA from delivered 1 MiB chunks;
- relative live-slow threshold: below 45% of a healthy peer >= 4 MiB/s;
- absolute live-slow threshold: below 1.25 MiB/s after at least 2 MiB has been delivered;
- two slow windows are required for rolling-throughput rotation;
- live reset cooldown: 8 seconds.

When a live sequential lane is rotated:

1. mark the lane for rotation;
2. cancel the active sequential task;
3. keep all chunks already written to the sparse ByteStore;
4. clear the slot claim;
5. reset the persistent URLSession only after the lane is idle;
6. if the reset is momentarily refused because the URLSession delegate is still completing cancellation, hold that slot in `liveLaneResetPending` and retry instead of immediately scheduling new work onto it;
7. let RangeMap select the remaining hole on the next sequential claim.

## Scenario review

### 152901 normal startup

Expected:

- initial 1 MiB head starts;
- `head warmup complete ... action=await-actual-tail-demand graceMs=250`;
- libmpv near-EOF byte-offset arrives;
- `actual-tail plan` begins at the real libmpv offset, not at EOF-16MiB;
- both slots run `role=startupMetadata` on adjacent 1 MiB pieces;
- no ordinary sequential work runs while startup metadata is queued/active;
- after the exact plan is cached, sequential prefetch resumes.

### 152901 one bad startup lane

Expected:

- peer startup lane makes progress;
- slow lane still has zero yielded bytes at the 1.5-second check;
- `action=straggler-cancel`;
- cancelled chunk returns to queue head;
- stream lane resets after idle;
- the missing lower chunk is retried instead of blocking the full tail on one poor connection.

### Startup tail never requested

Expected:

- only the 1 MiB head is fetched;
- after 250 ms, ordinary sequential scheduling resumes;
- no fixed final-16MiB network cost is paid merely because a file is large.

### 63368 steady playback with one degraded lane

Expected:

- speculative AVPlayer range-demand remains hint-only;
- both slots may preload;
- when one lane is much slower than a healthy live peer, it can be cancelled after rolling 1 MiB evidence instead of waiting for a full 32 MiB finish;
- already-downloaded bytes remain cached;
- the lane session is reset only after idle;
- protected bulk can fail over to the other physical slot.

### Whole network genuinely slow

Expected:

- peer-relative rotation does not trigger merely because both lanes are below the 4 MiB/s healthy-peer floor;
- the independent hard no-first-byte guard still prevents one connection from producing no bytes indefinitely;
- reset cooldown prevents tight reset loops.

### User seek while a live lane is being evaluated

Expected:

- concrete-read remains authoritative for reanchor;
- existing 2 MiB progressive-gap rule remains active;
- a foreground read may borrow the service lane;
- a stale watchdog cannot affect a replacement claim because every watchdog is generation-checked.

### Repeated MPV startup-tail reads

Expected:

- active startup metadata is recognized as foreground work and reused;
- cached bytes return immediately;
- rebuilding the plan filters cached and currently active exact chunks, preventing duplicate queue claims.

### Reset race

Expected:

- `RangeHTTPClient.resetStreamLane()` is never intentionally called before the slot is cleared;
- if the underlying PersistentRangeStreamLane still reports an active state during cancellation teardown, the slot is held in `liveLaneResetPending` and reset is retried before reuse;
- normal and startup schedulers both skip reset-pending slots.

### Error/cooldown

Expected:

- failed startup-metadata chunks are requeued;
- Slot 1 failure cooldown is respected by startup-metadata scheduling as well as ordinary scheduling;
- cancellation for a straggler is handled separately from a network failure and does not double-requeue the same chunk.

### Close/cancel

Expected:

- `stopped` still gates scheduling;
- transport stop cancels slot tasks and invalidates the RangeHTTPClient pool;
- delayed watchdog/reset callbacks return without restarting transport once stopped.

## Self-review findings caught before PR

1. Obsolete `configureStartupWarmupIfNeeded(...)` call remained after removing the helper; removed before compile.
2. Initial draft logged/armed `head warmup complete` on every later Slot 0 sequential completion; restricted to the first <=1 MiB large-MP4 head claim.
3. Without a short grace period, ordinary 32 MiB sequential work could start only milliseconds before libmpv's real tail seek and then be immediately cancelled; added 250 ms actual-tail grace.
4. A lane whose reset was temporarily refused could be immediately reused; added `liveLaneResetPending` and reset retries.
5. The `!secondaryEnabled` Slot 0 path initially ignored reset-pending; fixed.
6. Startup-metadata scheduling initially ignored Slot 1 failure cooldown; fixed.
7. Weak-self Task closures initially referenced instance timing constants directly; captured local delays to keep Swift closure semantics explicit.
8. Optional content-length comparison was parenthesized to remove `??` / comparison precedence ambiguity.
9. Initial startup-straggler check used the peer's current per-task byte count. A fast peer can finish and reset that count before the slow watchdog fires. Replaced with per-chunk start and peer-last-progress timestamps.
10. Temporary patch workflows were made idempotent before finalization so older construction stages could not overwrite reviewed source.

## Permanent CI gates

`check_live_lane_startup_invariants.py` adds direct v0.12.1 assertions and synthetic regressions for:

- exact 152901 tail offset and byte count;
- removal of the old proactive fixed-16MiB startup strategy;
- 1 MiB startup segmentation;
- two-lane startup scheduling;
- startup straggler timestamp recovery;
- live first-byte and rolling-throughput health;
- idle-only lane reset and reset-pending scheduling;
- exact two-lane normal transport;
- iOS 15.0, v0.12.1 / Build 59, and unsigned IPA naming.

Existing Scheduler v2, Transport v3, seek-stall, transport-stability, startup/lane-health and RangeMap gates remain; their startup assertions were upgraded rather than deleted.

## What CI cannot prove

CI can prove source invariants, synthetic state-machine cases, Xcode settings and generic-device compilation. It cannot prove 115/CDN real-device throughput, TCP/CDN path quality, or first-frame time relative to EPlayerX.

The next real-device log must therefore prove or disprove:

1. 152901 no longer spends ~20 seconds in one long startup metadata Range.
2. `actual-tail plan` starts at the real near-EOF offset.
3. Startup chunks are distributed across both lanes and a real straggler is cancelled when the peer progresses.
4. 63368 degraded sequential lanes produce `UnifiedLiveLane action=rotate-live-lane` before a full 32 MiB slow claim completes.
5. Sustained aggregate cache throughput remains materially closer to the faster lane instead of being dragged down for many seconds by a degraded peer.
