# v0.9.0 Player Transport Lab checklist

## Build
- [ ] GitHub `Validate Source` resolves MPVKit `0.41.0-n8.1.2`.
- [ ] iPhoneOS Release links without KSPlayer/duplicate FFmpeg/MoltenVK symbols.
- [ ] `scripts/check_min_os.sh` reports no embedded framework above iOS 15.0.
- [ ] Unsigned IPA installs on iPhone 15 Pro Max / iOS 17.0 through TrollStore.

## 63368 / native profile
- [ ] Log: `automaticProfile=AVPlayer+UnifiedTransport`.
- [ ] Log: `UnifiedTransport ready` and both `UnifiedSlot` workers after Slot 0 first stable block.
- [ ] Normal Wi-Fi download does not intentionally stop after 128 MiB when continuous preload + disk cache are enabled.
- [ ] Repeated +10/-10 Seek remains immediate.
- [ ] Post-Seek AVPlayer HTTP Range causes `UnifiedAnchor real-demand reanchor` when the target is outside the existing anchor.
- [ ] Slot 1 is not cancelled just because playback needs a hole.
- [ ] No repeated dropped-frame growth while `forwardPlayable` is healthy.

## 152901 / compatibility profile
- [ ] Log: `automaticProfile=MPV+UnifiedTransport reason=large-indexed-mp4`.
- [ ] Log: `MPVStream registered`, `MPVStream open`, then real byte `MPVStream seek` calls during MP4 probe.
- [ ] No fixed 8 MiB head + 16 MiB tail startup gate before creating MPV.
- [ ] First frame appears without old KTV+KSPlayer startup path.
- [ ] +10 Seek log order: `UnifiedAnchor user-seek ... awaitingRealDemand=true` → `MPVSeekRequest` → `MPVStream seek byte=...` → `UnifiedAnchor real-demand reanchor`.
- [ ] After Seek completion, playback clock continues advancing for at least 10 seconds; it must not freeze at the landing timestamp.
- [ ] Seeking to already verified gray cache is visibly faster than seeking outside verified cache.

## Buffer timeline
- [ ] Dim gray verified history remains when seeking backward 10 seconds.
- [ ] Bright gray current buffer can move/shrink independently.
- [ ] History never expands solely because MPV claims a huge `playableTime`; it expands only after actual playback clock/frame progression verifies the range.

## Network / 115
- [ ] 302 final media bytes remain client → 115/CDN; NAS never relays video bytes.
- [ ] Only two unified upstream slots are used for background Range traffic.
- [ ] A real urgent hole can use Slot 0 while Slot 1 remains alive.
- [ ] 403/410 temporary URL expiry triggers source re-resolution and retries the same byte range.
- [ ] Wi-Fi sustained throughput is measured over complete worker transfers; note both per-slot and aggregate values.
