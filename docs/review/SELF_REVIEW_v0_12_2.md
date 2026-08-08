# v0.12.2 self-review

## Evidence from source=0.12.1 device log

- 63368/152901 total ByteStore cache grows hundreds of MiB while the timeline is driven by AVPlayer/mpv playable ranges. The transport cache and engine buffer are different concepts and must be rendered separately.
- v0.12.1 live lane health logged impossible peer rates above 100-500 MB/s after ordinary ~1-3 MB/s first chunks. Root cause: bytes divided by adjacent URLSession callback intervals.
- 152901 far seek showed ~800 MB total cache and up to ~12.7 MB/s network, yet only 1 MiB contiguous at the new anchor, Slot 0 deep in an older urgent claim and Slot 1 idle. Being inside an urgent claim did not mean the requested byte had arrived.
- 144799 rotation showed portrait `view=430x932` while Metal drawable became landscape `2796x1290` (932x430 at scale 3), proving host geometry and swapchain orientation diverged.

## Changes and invariants

1. Rolling lane health samples cumulative byte deltas over >=1.0 s windows. Back-to-back callback timing can never directly trigger a lane rotation.
2. First-byte watchdog remains independent and may still reject a lane that produces no bytes at all.
3. A concrete playback read more than 2 MiB ahead of an active urgent stream head may create a parallel urgent request on the other lane.
4. UnifiedTransport cache coverage is shown as its own timeline layer and percentage; AVPlayer/mpv playable ranges remain separate overlays.
5. MPV Surface follows MPVKit's controller-hosting pattern (`UIViewControllerRepresentable`) so UIKit rotation callbacks participate in layout. MoltenVK continues to own `drawableSize`.
6. Exactly two normal upstream lanes remain. No NAS media relay is introduced.
7. Deployment Target remains iOS 15.0.

## Scenario review

- 63368 sustained playback: a fast callback burst cannot manufacture a 100+ MB/s peer and reset a healthy connection. Real 1 s window samples can still rotate a repeatedly degraded lane.
- 63368 seek inside an active sequential claim: existing progressive-gap rule remains unchanged.
- 63368/152901 seek inside an active urgent claim: when the needed read is still >2 MiB beyond that urgent stream head, the second lane can fill from the real demand instead of idling.
- Whole-link slowdown: rolling relative rotation requires a fresh live peer; it does not compare a current lane against stale completed throughput. Absolute slow rotation still requires >=3 s runtime and >=4 MiB received.
- 152901 startup: v0.12.1 actual-tail 1 MiB dual-lane startup metadata logic is unchanged.
- Sparse cache after far seeks: download cache percentage may grow independently of forward playable seconds; UI labels the two concepts separately.
- 144799 portrait/landscape: UIKit view-controller transition is logged and causes a post-transition layout pass; no forced Metal drawable size is added.
- Close/cancel: no lifecycle changes to transport or mpv teardown.

## Not claimed by CI

CI can prove source invariants, iOS 15 deployment settings, and compilation. It cannot prove a particular 115 CDN throughput or real-device orientation behavior. Those remain device-log validation targets.
