# v0.9.6 Self Review

## Why this review exists

v0.9.5 compiled successfully but regressed startup scheduling on item 63368. The regression was architectural rather than syntactic: Slot 1 background preload competed with startup-critical metadata while Slot 0 was occupied by urgent playback. This review is a merge gate in addition to CI.

## Required invariants

1. Slot 0 owns urgent playback reads.
2. Background Slot 1 must yield immediately whenever playback becomes urgent.
3. A cancelled Slot 1 sequential task must not restart from `finishSlot -> scheduleSlots` while critical work is still queued or active.
4. Playback urgent and metadata demand use independent pending state; one must never overwrite the other.
5. Tiny tail metadata may use an idle Slot 1 while Slot 0 is urgent. Large metadata stays on Slot 0 to avoid a slow worker-1 cold start.
6. Slot 1 sequential may run only when Slot 0 is sequential and no playback urgent/metadata work is pending.
7. Sequential Slot 0 and Slot 1 must not intentionally overlap an urgent playback range.
8. Seek/blocked-read priority is higher than throughput optimization.
9. Closing playback must not requeue cancelled critical work.
10. Deployment Target remains iOS 15.0.

## Scenario walk-through

### 63368 AVPlayer startup

Expected sequence:

- Slot 0 initial sequential is promoted to urgent 0..16 MiB.
- Slot 1 remains idle; it does not start background sequential merely because Slot 0 became urgent.
- AVPlayer tail metadata probe (~331 KiB) is classified metadata.
- Because metadata is <= 2 MiB and Slot 0 is already urgent, Slot 1 may serve that metadata immediately.
- Metadata completion does not start background Slot 1 while Slot 0 is still urgent.
- After critical startup work clears, both slots may return to sequential preload.
- No ResourceLoader read should wait behind a 32 MiB background claim.

### 152901 large indexed MP4 startup

Expected sequence:

- Slot 0 serves initial urgent playback.
- Tail metadata is about 10 MiB, so it must not be sent to Slot 1 under the tiny-metadata shortcut.
- Slot 1 stays idle during this critical phase.
- After Slot 0 urgent completes, Slot 0 serves large metadata.
- Only after critical work clears may dual sequential preload begin.

### 144799 MKV startup

Expected sequence:

- Slot 0 serves urgent playback.
- Tiny tail metadata may use Slot 1 concurrently.
- MPV startup fixes from v0.9.5 remain unchanged.

### Buffered continuous playback

Expected sequence:

- With no critical work, Slot 0 and Slot 1 may both run non-overlapping sequential claims.
- Long Range progressive writes remain enabled.

### Continuous double-tap seek

Expected sequence:

- Real byte demand installs playback urgent state.
- Any Slot 1 sequential task is cancelled immediately.
- If Slot 0 sequential owns the demanded byte, it is promoted/cancelled and replaced by Slot 0 urgent.
- Slot 1 cannot restart sequential while Slot 0 is urgent or critical work is pending.
- After urgent demand settles, dual sequential preload may resume.

### Far seek while metadata is pending

Expected sequence:

- Playback urgent and metadata are stored independently.
- Neither pending range can overwrite the other.
- Playback urgent is served first by Slot 0; tiny metadata may use Slot 1 only when safe.

### Close / cancellation

Expected sequence:

- Cancellation does not count as a network failure.
- Cancellation must not requeue metadata.
- `stopped` prevents scheduler restart.

## Merge gate

Do not merge unless:

- the source code matches every invariant above;
- temporary patch workflows/scripts are removed;
- final PR diff contains only intended source/config/review/changelog changes;
- Xcode 16.4 generic iOS device build passes;
- build settings still report `IPHONEOS_DEPLOYMENT_TARGET = 15.0`.
