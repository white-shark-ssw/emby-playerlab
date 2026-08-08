# EmbyPlayerLab v0.11.3 Self Review

Version: 0.11.3 (Build 57)  
Deployment Target: iOS 15.0  
Primary runtime target: iPhone 15 Pro Max / iOS 17.0

## Evidence from the v0.11.2 device log

### 63368 throughput is genuinely unstable

Completed sequential Range averages vary by several multiples on the same persistent lanes. Representative values include Slot 0 around 23 MiB/s, later about 4.6 MiB/s, then about 1.9 MiB/s. Slot 1 likewise spends long periods around 2.5-4 MiB/s before later recovering into double digits. This is not just a UI-speed issue.

v0.11.2 preserved persistent lanes but had no way to retire a connection that had become materially worse than its peer.

### v0.11.2 also inflated foreground throughput metrics

The urgent/metadata receive path accidentally called `recordNetworkBytes(...)` six times for each received chunk. Sequential traffic was counted once. This inflated `bytesDownloaded` and the rolling `networkBps` during foreground work, making transport diagnostics and health decisions unreliable.

v0.11.3 restores exactly one network-byte accounting call in each receive path and permanently guards the count in CI.

## 152901 startup root cause

The current 5,883,702,464-byte MP4 starts MPV, reads the head, then immediately seeks to byte 5,873,522,321: only 10,180,143 bytes from EOF. That is the MOV/MP4 tail index/sample table required to finish opening the file.

In v0.11.2 that explicit byte seek was forcibly classified as `urgentPlayback` because every concrete read was treated as playback. Slot 1 abandoned background sequential work and fetched the roughly 9.7 MiB tail index on a fresh connection. Its first MiB took about 1.77s and the full tail averaged about 1.14 MB/s.

Meanwhile Slot 0 continued downloading the head quickly. By the time the tail index was ready the sparse store already held more than 140 MB, explaining the observed state: "100+ MB cached but still no picture". `file-loaded` appeared roughly 11.2s after Player Start and the position began advancing roughly 12.4s after Player Start.

## v0.11.3 startup-tail policy

A concrete read is treated as startup metadata only when all of these are true:

- media container is MP4;
- resource is at least 4 GiB;
- the transport session is younger than 35 seconds;
- playback anchor is still zero;
- no user timeline seek token is active;
- requested byte lies within 64 MiB of EOF.

This deliberately distinguishes libmpv's container-open tail probe from a real user seek near the end of the movie.

For this startup-critical metadata path:

- Slot 1 background sequential work is preserved;
- Slot 0 sequential work is cancelled;
- the tail metadata is queued on Slot 0 so it reuses the primary persistent connection instead of forcing a fresh secondary connection;
- the existing slow-start metadata recovery now applies because the claim role is correctly `.metadata`.

Ordinary distant concrete reads after startup remain playback dependencies, preserving the poorly-interleaved MP4 fix.

## Lane health / connection rotation

v0.11.3 keeps exactly two normal upstream lanes. It does not increase concurrency.

Health is measured only from successful completed sequential claims of at least 8 MiB. Each lane maintains a recent weighted speed estimate. A lane becomes rotation-eligible only when:

- the peer has a recent sample (within 20s);
- the peer average is at least 4 MiB/s, proving the whole link is not simply weak;
- the current completed claim is below 50% of the peer average;
- this happens for two qualifying completed claims;
- the lane is idle;
- the lane is outside a 25-second reset cooldown.

The reset discards only that idle lane's URLSession and creates a fresh persistent session. It cannot reset an active foreground or sequential task. If both lanes are slow because the whole network is weak, peer-floor gating prevents connection churn.

This is deliberately conservative. If device logs show a degraded lane remains bad for too long before the second completed block, a later revision can add an in-flight health checkpoint; v0.11.3 does not cancel a long Range merely from one slow first chunk.

## MPV buffer timeline

The v0.11.2 152901 session produced no `BufferHistory` lines even though MPV repeatedly reported about 90 seconds of `playableRanges` after playback began. The persistent gray history gate required `value.isPlaying == true`, but that property was not reliably established for this session.

v0.11.3 no longer trusts that flag for MPV history. It requires:

- MPV is not buffering;
- position advances by more than 0.03s and less than 2s between snapshots.

Advancing `time-pos` is direct evidence that playback is progressing. A stalled/static snapshot still cannot grow persistent history. Partial byte cache is still not converted into time by file-size percentage; only engine-demuxed playable time is shown until byte-complete/hole-free full-cache promotion is reached.

## Permanent regressions

`check_startup_lane_health_invariants.py`, executed by the existing transport-stability CI gate, verifies:

- exactly two `recordNetworkBytes(chunk)` call sites remain;
- large-MP4 startup tail metadata classification exists;
- active user startup seeks cannot enter the metadata shortcut;
- startup metadata preempts the primary sequential lane and preserves the secondary prefetch lane;
- lane reset is allowed only when the persistent lane has no active state;
- lane rotation is evaluated only after a successful sequential slot has become idle;
- peer-relative two-sample / floor / cooldown health policy remains present;
- whole-link weak-network synthetic case does not rotate;
- MPV persistent buffer history no longer depends on `isPlaying`.

Both Validate Source and unsigned IPA builds already run `check_transport_stability_invariants.py`, which now executes this new regression file.

## Intentionally unchanged

- Exactly two upstream 115/CDN connections.
- STRM -> HTTP 302 -> 115/CDN direct media path.
- No NAS media-byte relay.
- MPV renderer / VideoToolbox configuration.
- AVPlayer engine route for native-friendly media.
- double-tap seek behavior and timing.
- Emby playback progress reporting.
- Deployment Target iOS 15.0.
