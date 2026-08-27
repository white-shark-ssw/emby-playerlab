from pathlib import Path
import re


def replace_once(text: str, pattern: str, replacement: str, label: str, flags: int = 0) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f"{label} anchor mismatch")
    return updated


def patch_dev() -> None:
    path = Path("docs/project/current/dev/DEV-poster-grid-smoothness.md")
    text = path.read_text(encoding="utf-8")
    status = "**Active — Build210 / 0.14.43 target-device App log captured. Multi-owner attribution is validated: Home and grid can coexist (`registered_scrolls=2`) and the grid route is now logged correctly. Four Home dragging hitches (68.9 / 34.9 / 74.5 / 39.8 ms) all occurred 6.2–11.0 ms after the latest shared image commit, making post-image-publish Home work the strongest current lead. The single grid record (70.4 ms) was only `phase=moving`, `delta_y=0.33`, velocity 0 and 855.4 ms after image commit, so it is not yet proof of a user-drag library hitch. Performance root cause remains unresolved and no fix is claimed.**"
    text = replace_once(text, r"(?s)(## Status\n\n)\*\*.*?\*\*", r"\1" + status, "DEV status")
    old_evidence = "**Build210 evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device diagnostic pending / performance fix not claimed / not stable.**"
    new_evidence = "**Build210 evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device diagnostic tested ✅ / multi-owner route attribution validated ✅ / Home image-commit correlation strong but not yet causal / user-drag grid root cause unresolved / performance fix not claimed / not stable.**"
    if old_evidence in text:
        text = text.replace(old_evidence, new_evidence, 1)
    result = """## Build210 target-device result — 2026-08-27

Latest App log: `OnePlayer-App-1787807430.log`.

Build210 emitted five motion-gated `PosterScrollHitch` records:

- Home: **68.9 ms**, `phase=dragging`, `delta_y=16.00`, `image_age_ms=11.0`, `cell_age_ms=6644.2`.
- Home: **34.9 ms**, `phase=dragging`, `delta_y=3.00`, `image_age_ms=6.2`, `cell_age_ms=7277.1`.
- Home: **74.5 ms**, `phase=dragging`, `delta_y=2.33`, `image_age_ms=8.8`, `cell_age_ms=13651.4`.
- Home: **39.8 ms**, `phase=dragging`, `delta_y=11.00`, `velocity_y=-503.8`, `image_age_ms=9.0`, `cell_age_ms=14291.9`.
- Grid: **70.4 ms**, `scroll_route=grid`, `phase=moving`, `delta_y=0.33`, `velocity_y=0.0`, `registered_scrolls=2`, `moving_scrolls=1`, `image_age_ms=855.4`, `cell_age_ms=1151.0`.

This validates the Build210 multi-owner diagnostic model: Home and grid owners coexist and only the actually moving owner is selected. Build209's zero-grid result was therefore a diagnostic ownership defect, not proof of a smooth grid.

The four Home dragging hitches all occurred only **6.2–11.0 ms** after the most recent shared image commit while the latest poster cell appearance was already **6.6–14.3 s** old. Exact Build210 source shows decode already occurs in detached utility work; `imageDidCommit()` is timestamped immediately after `@Published image` assignment on MainActor. Home carousel `onImageLoaded` callbacks then synchronously run `updateCarouselImageMetrics`, including `EmbyImageContrastAnalyzer.prefersLightForeground` → `CIAreaAverage` → `CIContext.render`, and may mutate root Home `@State` dictionaries. This is the strongest Home-specific source/device correlation so far.

However, `imageDidCommit` is global and does not identify item/route/cache source, so the 4/4 correlation is not yet enough to change image policy. The one grid record is also not a user-drag sample and has no near-image correlation. Do not claim a cross-page root cause yet.

"""
    if "## Build210 target-device result — 2026-08-27" not in text:
        text = text.replace("\n## Parallel safety", "\n" + result + "## Parallel safety", 1)
    next_block = """## Next exact action

1. Do not change runtime performance behavior from Build210 evidence alone.
2. For Home, instrument image commits with stable context sufficient to distinguish ordinary poster vs carousel artwork/logo and memory/disk/network publish path, and measure the synchronous carousel image-metric/contrast callback duration without adding timer/debounce/throttle.
3. Keep the poster task out of `EmbyHomeCarouselStateV3.swift`, `EmbyHomeHeroV3.swift` and `EmbyHomeCoreV3.swift` while Home-carousel Build208 remains Active; if the trace proves that owner is responsible, reconcile the two tasks explicitly before a runtime change.
4. Obtain at least one real `phase=dragging` or `phase=decelerating` grid hitch on Build210 (or a successor diagnostic build) before changing a shared grid path. The current 70.4 ms `phase=moving / delta_y=0.33` record is insufficient.
5. Preserve P0 playback/transport/cache/session contracts and iOS 15.0 deployment.

"""
    text = replace_once(text, r"(?s)## Next exact action\n.*?(?=## Do not repeat)", next_block, "DEV next action")
    path.write_text(text, encoding="utf-8")


def patch_index() -> None:
    path = Path("docs/project/BUILD_TEST_INDEX.md")
    text = path.read_text(encoding="utf-8")
    new209 = "| **Build209 / 0.14.42** | Motion-aware poster-scroll diagnostics | Target-device App log proved three Home motion hitches but grid attribution was invalid because Home/grid shared one global observed-scroll owner. Diagnostic tested; not stable. |"
    text = replace_once(text, r"^\| \*\*Build209 / 0\.14\.42\*\* \|.*$", new209, "INDEX Build209 row", re.M)
    new210 = "| **Build210 / 0.14.43** | Multi-owner poster-scroll diagnostics | **Current poster diagnostic baseline.** Target-device log validates simultaneous Home/grid ownership (`registered_scrolls=2`) and correct grid routing. Four Home dragging hitches all landed 6.2–11.0 ms after image commit; the single grid record was programmatic/micro-motion (`phase=moving`, `delta_y=0.33`) and not yet a user-drag grid stall. Real-device diagnostic tested; no performance fix claimed; not stable. |"
    if "| **Build210 / 0.14.43** |" in text:
        text = replace_once(text, r"^\| \*\*Build210 / 0\.14\.43\*\* \|.*$", new210, "INDEX Build210 row", re.M)
    else:
        text = text.replace(new209 + "\n", new209 + "\n" + new210 + "\n", 1)
    detail = """### Build210 — target-device multi-owner diagnostic result

- exact source `9d8fd6a62e6e7d281d4fae5ab8442754a6362f47`; run/job `33009322419 / 98311176681`; artifact ID `9621956333`; IPA SHA-256 `813811fe0301cd8c942511e3e7786c184a80966960bf029ed3366d6edaa23701`.
- latest target-device log `OnePlayer-App-1787807430.log` contains five motion-gated hitches: Home 68.9 / 34.9 / 74.5 / 39.8 ms and grid 70.4 ms.
- all four Home entries are `phase=dragging` and are only 6.2–11.0 ms after the latest shared image commit, while last cell appearance is 6.6–14.3 s old.
- grid attribution now works: `scroll_route=grid registered_scrolls=2 moving_scrolls=1`. Its only entry is `phase=moving`, `delta_y=0.33`, velocity 0, image age 855.4 ms and cell age 1151.0 ms, so it is not yet a proven user-drag grid hitch.
- exact source confirms image decode is detached; image commit timestamp follows MainActor `@Published image` assignment. Home carousel image callback then synchronously runs Core Image contrast analysis and may update root Home state. This is the strongest Home lead, but shared image events lack source identity and the active Home-carousel task owns the likely callback/state files.
- evidence: **real-device diagnostic tested / multi-owner attribution validated / Home image correlation strong but not yet causal / grid user-drag attribution still incomplete / performance root cause unresolved / not stable.**

"""
    if "### Build210 — target-device multi-owner diagnostic result" not in text:
        marker = "\n## Accepted foundation evidence"
        if marker not in text:
            raise SystemExit("INDEX detail marker missing")
        text = text.replace(marker, "\n" + detail + "## Accepted foundation evidence", 1)
    path.write_text(text, encoding="utf-8")


def patch_state() -> None:
    path = Path("docs/project/PROJECT_STATE.md")
    text = path.read_text(encoding="utf-8")
    intro = "_Last updated after poster-scroll Build210 / 0.14.43 target-device diagnostics validated multi-owner Home/grid attribution and exposed a strong Home image-publish correlation. Build199 remains the latest real-device accepted overall baseline. Home-carousel Build208 and poster-scroll remain independent Active lines._"
    text = replace_once(text, r"^_Last updated.*_$", intro, "PROJECT_STATE intro", re.M)
    start = text.index("## Active: Poster-heavy scrolling smoothness")
    end = text.index("\n## Parallel integration rule", start)
    poster = """## Active: Poster-heavy scrolling smoothness

Work: `DEV-poster-grid-smoothness`.

- Build202 / 0.14.35 and Build204 / 0.14.37 were target-device rejected; the visible stop/catch-up hitch remained on Home and library 3×3.
- Build206 added first hitch timing but lacked motion state. Build209 added motion gating but used one global Home/grid scroll owner, making its zero-grid result invalid.
- Build210 / 0.14.43 exact source `9d8fd6a62e6e7d281d4fae5ab8442754a6362f47` uses independent weak scroll observations while retaining one shared `CADisplayLink` and the ≥30 ms + real-offset-motion gate. CI/IPA passed and were independently verified; MinOS remains 15.0.
- latest target-device log `OnePlayer-App-1787807430.log` validates the owner fix: one grid record reports `registered_scrolls=2 moving_scrolls=1`, proving Home and grid can coexist without overwriting attribution.
- Home produced four `phase=dragging` long frames: **68.9 / 34.9 / 74.5 / 39.8 ms**. Every one was only **6.2–11.0 ms** after the most recent shared image commit while cell age was **6.6–14.3 s**.
- exact source shows decode already occurs in detached utility tasks; `imageDidCommit()` follows MainActor `@Published image` assignment. Home carousel image callbacks then synchronously perform Core Image contrast analysis and update root Home state. This is the strongest Home-specific lead so far.
- the only grid record was **70.4 ms**, but `phase=moving`, `delta_y=0.33`, velocity 0, image age 855.4 ms and cell age 1151.0 ms. It is not sufficient evidence of the user's drag-time library hitch.
- because image commit events are global and do not yet identify ordinary-poster vs carousel image or memory/disk/network publish path, do not change image policy yet. Also do not modify active Home-carousel owner files from the poster task without explicit integration.
- evidence: **Build210 target-device diagnostic tested / multi-owner attribution validated / Home image correlation strong but not causal / grid user-drag root cause unresolved / performance fix not claimed / not stable.**

Next: add source-aware image-commit/callback-duration diagnostics in shared infrastructure and obtain a true dragging/decelerating grid hitch before selecting a runtime performance patch.
"""
    text = text[:start] + poster + text[end:]
    path.write_text(text, encoding="utf-8")


patch_dev()
patch_index()
patch_state()
