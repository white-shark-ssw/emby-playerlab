# OnePlayer 0.14.69 / Build236

- Home carousel acquisition-start A/B based on Build234 target-device evidence.
- If the acquisition UIEvent has only the current delivered touch (`acq_predecessor_status=none`, count 1), inspect only the first post-acquisition UIEvent for a real coalesced predecessor after acquisition.
- When such a predecessor exists and continues in the already-selected horizontal direction, use it once as the render baseline while still publishing the current delivered touch; immediately return to ordinary delivered-touch ownership afterwards.
- If no valid real predecessor exists, preserve the existing fallback.
- Adds post-acquisition predecessor diagnostics; no timer, interpolation, step cap, easing, debounce/throttle, predicted-touch render authority, or second state owner.
- Retains Build231 foreground compositing, Build226 Hero residency, Build228 max-refresh-through-settle, 0.28/0.48 release rules and all Frozen/P0 playback/transport contracts.
- Deployment target remains iOS 15.0.
