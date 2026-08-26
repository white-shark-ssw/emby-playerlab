# DEV-home-carousel-drag-smoothness

## Status

**Active — Build207 / 0.14.40 was target-device tested and exposed a structural foreground-layout problem: the first displacement is still too large, and using two full-width foreground pages with only `0.80 × width` center travel forces adjacent foreground content to overlap during the transition. User screenshots versus EX show EX preserves visible separation between adjacent foreground pages. Build208 / 0.14.41 changes the foreground to full-width page-slot spacing (`pageStep = width`) while keeping the same single UIKit owner; CI running.**

- Work ID: `DEV-home-carousel-drag-smoothness`
- Routing aliases / keywords: 轮播图滑动卡顿 / 轮播图丝滑 / 首页轮播 / carousel drag / carousel smoothness
- Accepted overall baseline remains OnePlayer **0.14.32 / Build199** on `main`.
- Target device: iPhone 15 Pro Max / iOS 17.0.
- Build206 is owned by the independent poster-scroll task; Build208 / 0.14.41 was confirmed unallocated before use.

## Retained input contract

Build198 remains the input foundation:

`one UIKit interaction surface → one begin/move/end/cancel owner → one V3HomeCarouselTransitionState → SwiftUI render`

Do not change without new direct evidence:

- 0.5pt axis acquisition;
- vertical acquisition yields to Home `UIScrollView`;
- horizontal acquisition owns the gesture through end/cancel;
- actual touch drives raw `transitionProgress`; predicted touch is release-only;
- commit threshold 0.28;
- predicted-distance gate 0.48 × width;
- existing settle ownership/timings;
- no second SwiftUI drag/release owner;
- no interpolation/timer/watchdog/retry/debounce/throttle.

Player / MPV / PiP / Transport / Cache / Emby Session / STRM→302→115/CDN client-direct paths remain outside this task.

## Retained real-device history

- Build185/187: first visible/useful horizontal motion remained much coarser than EX even with 120 Hz available.
- Build189/193: split native move / separate SwiftUI release ownership could freeze between pages; rejected architecture.
- Build198 / 0.14.31: single UIKit owner fixed lifecycle/settle/reversal behavior, but minimum/subtle drag still felt too coarse versus EX.
- Build200 / 0.14.33: fixed foreground was rejected because required horizontal slide disappeared.
- Build201 / 0.14.34: 15% horizontal travel received partially positive **“有点那种感觉了”** feedback but total travel was too short.
- Build203 / 0.14.36: 30% travel still too short; raw-linear spatial mapping exposed coarse first displacement again.
- Build205 / 0.14.38: 80% + whole-range `progress²` was rejected because start was over-restrained and the nonlinear tail felt unnatural.

## Build207 — latest target-device result

Build207 / OnePlayer 0.14.40 evidence:

- branch: `perf/home-carousel-soft-start-linear-tail-build207`
- tested source: `06936503a6c382d1d39d3cdd52f23bfe2058901e`
- durable cleanup head: `7044ca68c7082cd055a7e4ce42dda6f00fe29674`
- run/job: `33000526138` / `98280846494` — success
- artifact ID: `9618484884`
- IPA SHA-256: `bbd7c9c22c2a79a89f41e0d94db16023cf7cd2a720ffeb3c4f31cb9066a15a21`
- foreground total travel: `0.80 × Hero width`;
- visual mapping: `progress * (1 - 0.60 * (1-progress)^6)` for opacity + foreground offset;
- raw gesture progress/release/commit remained unchanged.

Latest target-device evidence on 2026-08-27:

1. **First visible displacement is still too long.**
2. User screenshots of OnePlayer show adjacent foreground Logo/title/rating/overview content visibly overlapping during drag.
3. EX comparison screenshots show a clear separation between adjacent foreground pages.
4. Source inspection explains the overlap deterministically: every `carouselHeroForeground` is a full-width page, but Build207 places outgoing/incoming page centers only `0.80 × width` apart, therefore the page frames structurally overlap by 20% throughout the transition.
5. Existing foreground content width is `width - 56`; if page centers are one full `width` apart, the visible foreground content edges maintain a constant ~56pt gap.
6. User's model — “一个个有屏幕宽度的框子，每个框子显示自身内容，只是带有轮播图边界效果” — matches the source-backed correction.

Conclusion: the next fix is **not another arbitrary travel percentage**. Foreground should use full-width page-slot spacing. This is a visual-layout correction, not evidence to change the UIKit gesture owner.

**Build207 = Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / foreground layout + first-displacement rejected / not stable.**

## Build208 — current page-slot candidate

Identity:

- OnePlayer **0.14.41 / Build208**
- branch: `perf/home-carousel-page-slots-build208`
- base: Build207 durable cleanup head `7044ca68c7082cd055a7e4ce42dda6f00fe29674`
- current source with scoped workflow: `2ad089f0ea8b4b6827257bb3a91a67c2d3748e5f`

Runtime changes remain limited to `Sources/Core/AppIdentity.swift` and `Sources/UI/EmbyHomeCarouselStateV3.swift`:

- foreground page center step: `0.80 × width` → **`1.00 × width`** (`pageStep = width`);
- outgoing center offset = `-direction × visualProgress × pageStep`;
- incoming center offset = `direction × (1 - visualProgress) × pageStep`;
- the distance between outgoing/incoming page centers is therefore exactly one Hero width at every progress value;
- existing page content width remains `width - 56`, producing a constant ~56pt separation between adjacent foreground content instead of structural overlap;
- no new HStack/ScrollView/second page owner is introduced; this is mathematically the same page-slot model with the existing two visible foreground pages and state owner;
- earliest soft-start coefficient changes `0.60 → 0.85` while keeping exponent 6, affecting mainly the first few percent of raw progress;
- compared with Build207, approximate actual page displacement at raw progress 1% / 2% / 4% changes from 0.35% / 0.75% / 1.70% width to about **0.20% / 0.49% / 1.34% width**;
- around raw progress 10% the mapping has essentially caught up, so mid/late drag remains close to linear and tail derivative still reaches 1.0;
- foreground/backdrop opacity continues to use the same visual progress;
- raw `transitionProgress`, 0.28 commit, 0.48×width predicted-distance gate, direction/reversal/settle and first↔last modulo ownership are unchanged.

Scoped diff before workflow contains only:

- `Sources/Core/AppIdentity.swift`
- `Sources/UI/EmbyHomeCarouselStateV3.swift`
- `docs/changelog/CHANGELOG_v0_14_41_build208.md`
- `scripts/check_home_carousel_single_owner.py`

Local static contract check passed. Build208 CI run `33004390654`, job `98294100402`; source/Frozen guard passed and pipeline is continuing.

## Next exact action

1. Complete Build208 CI/IPA and independently verify artifact/identity/MinOS.
2. Target-device A/B against Build207 and EX.
3. First priority: verify adjacent foreground Logo/title/rating/overview no longer overlap and show a clear page-to-page gap during left/right drag.
4. Verify the earliest visible displacement is smaller than Build207.
5. Verify mid/tail remains natural and page-slot spacing stays constant through reversal, cancel and commit.
6. Verify first↔last wrapping, vertical Hero scroll, detail tap and auto-advance.
7. Do not alter UIKit ownership or raw release thresholds unless new device evidence directly requires it.
