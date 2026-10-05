# OnePlayer 0.15.25 / Build292 — consecutive swipe takeover and artwork fade

Build291 device feedback confirms reverse motion, logo/text overlap and Dock alignment corrections. This candidate addresses two newly reported Home issues.

- Rebase same-direction takeover of a committed release to its target, while preserving the visible foreground offsets and outgoing resident page. A fresh qualifying swipe can commit the following page before the old release ends. Opposite-direction takeover remains presentation-relative. Retain 0.28 distance, 500pt/s fling and 0.22/0.18s tails.
- Extend the clear artwork mask to the Hero/content extent and broaden its fade into the same sampled solid base. No additional full-screen blur or per-frame layout.
- Preserve Build291 bounds/center geometry, Dock root extent, shared image loading, Home vertical behavior, native navigation and Frozen/P0 playback contracts. Minimum iOS15.0.

Source/CI/IPA and real-device results are separate. No 120FPS or stable claim before device evidence.
