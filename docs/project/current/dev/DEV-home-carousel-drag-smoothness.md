# DEV-home-carousel-drag-smoothness

- **Status:** Active — Build286 architecture A/B is CI/IPA verified and real-device exercised through identical Build288 Home runtime on 2026-10-05. User reports persistent swipe frame drops, failure to sustain desired 120 FPS and a large competitor experience gap. Scope isolation is insufficient as the final smoothness fix; re-audit the complete carousel requirements before selecting a bounded architecture replacement. Manual sustained system-FPS-HUD transcription remains retired.
- **Work ID:** `DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords:** 首页轮播 / 轮播图 / 轮播流畅度 / carousel / rapid swipe / 120fps / invalidation scope / progress publication
- **Task:** Preserve Build241 product interaction/presentation while reducing unnecessary high-frequency SwiftUI invalidation in the real Home carousel tree.
- **Base branch / source:** `main` checkpoint `8dac5e687506d52fab9b3634389fa029cb7f0bde` (runtime source-equivalent to preceding `5336240...`; the extra commit only reserved/documented Build286).
- **Product branch:** `perf/home-carousel-progress-scope-build286`
- **Exact product source:** `7e7b2ec944f5c0e74bc291e37683f1529e3d46b4`
- **Draft PR:** #289 — open, unmerged
- **CI control branch:** `ci/build286-home-progress-scope-20260904`
- **Candidate:** OnePlayer `0.15.19 / Build286`
- **Xcode 16.4 CI run / job:** `33786964921 / 100753960778` — success
- **Artifact:** `OnePlayer-0.15.19-build286-home-progress-scope`, ID `9905942602`, digest `sha256:983c3cb1aa650f727266019b9a1ea834fad9c29266a043a775f9109c40f0c9f4`
- **IPA SHA-256:** `5c26b36eb70117abbd27885f5b637827020f7fffcc949d79a45e5b9a19bc28b0`
- **Source ZIP SHA-256:** `ff975b72afcfc660542c112a2eb55e4c0f8669e11933bc4d368df7b3c7c8f68e`
- **Bundle / version / MinOS:** `com.embyplayerlab.app / 0.15.19 (286) / iOS 15.0`
- **Target device:** iPhone 15 Pro Max / iOS 17.0
- **Collision guard:** Build285 is occupied by Poster infrastructure; Build286 had no prior allocation and is now reserved by this Home line.
- **Superseded diagnostic:** Build284 / `0.15.17`, PR #288 closed unmerged before target-device execution; no runtime rejection inferred.

## Controlling product baseline

Build241 remains the behavior to preserve: one UIKit interaction owner, acquisition-relative movement, full-width page slots, current/previous/next clear-Hero residency, page-level foreground `compositingGroup()`, max-refresh through settle, persistent white-flash correction, ordinary progress commit `>=0.28`, direction-aware fling commit `>=500 pt/s`, commit `.easeOut(duration: 0.22)` and cancel `.easeOut(duration: 0.18)`.

Build286 is an observation-boundary performance A/B, not a gesture, timing, visual-style or smoothing redesign.

## Why this architecture A/B is justified

Build279 showed callback density / standard Pan alone is insufficient. Build281 showed device-max DisplayLink latching of latest real input is insufficient. Build282 showed simple `CADisplayLink → CALayer` and simple `@Published → SwiftUI` paths can sustain 120 on the same package/device while the real TREE path remains session-sensitive. Therefore neither generic SwiftUI capability nor input cadence alone explains the real presentation path.

The real Build241/main architecture published `fromID`, `toID`, `progress` and `direction` through one parent `V3HomeCarouselTransitionState`. Both the full persistent backdrop and full Hero scopes observed that parent. Each progress sample therefore emitted the same broad object-level invalidation used for low-frequency transition semantics.

The source does **not** prove every descendant is fully rasterized on each sample; SwiftUI can preserve identity and optimize rendering. It does prove that the high-frequency observation/evaluation boundary was wider than necessary.

## Build286 exact implementation

Build286 keeps one `V3HomeCarouselTransitionState` as the sole transition owner and keeps `transitionProgress` as the sole product-facing progress entry point.

Notification granularity only is changed:

1. parent semantic fields `fromID`, `toID`, `direction` remain `@Published`;
2. the parent owns one nested `V3HomeCarouselProgressState` containing the single stored progress value;
3. `transitionProgress` reads/writes `carouselTransitionState.progress.value`;
4. parent `V3HomeCarouselTransitionScope` still rebuilds for semantic transition changes but no longer receives each progress object's `objectWillChange`;
5. narrow progress-observing wrappers update only Hero artwork opacity, foreground page X offset, target persistent-backdrop opacity, page indicators and the existing tiny cadence probe.

There is no second progress value/owner and no added DisplayLink.

## Exact product scope / guards

Build286 base→product diff contains exactly five paths:

- `Sources/Core/AppIdentity.swift`
- `Sources/UI/EmbyHomeCarouselInteractionV3.swift`
- `Sources/UI/EmbyHomeCarouselProgressPresentationV3.swift` (new)
- `Sources/UI/EmbyHomeCarouselStateV3.swift`
- `Sources/UI/EmbyHomeHeroV3.swift`

`Sources/UI/EmbyHomeCoreV3.swift` remains exact blob `c7900bae5e608ae46c0cd476c1f08999be9baf0b`.

Independent source-ZIP git-blob verification matched product commit blobs:

- AppIdentity `e435b73ad030474af14e9199914af9429114fac2`
- Interaction `bd5666d2c7e4d29bec6987fdb4a96f636d519e3f`
- progress presentation `81da601c9860a29d38a6a26676cf27adb7727dd9`
- carousel state `c7694568ee9bc3b6c9bbc0d529100d5327a48e7a`
- Hero `99cf58a8ac908e064855cee42fcc4ffb636fcb55`
- unchanged HomeCore `c7900bae5e608ae46c0cd476c1f08999be9baf0b`

Static guards also preserve `.compositingGroup()`, `blur(radius: 30)`, three-slot Hero residency, `>=500 pt/s`, `>=0.28`, 0.22/0.18 animations, `CADisableMinimumFrameDurationOnPhone`, and iOS 15.0 target; Player/Transport/Session/Cache/MPV/PiP paths are excluded.

## Packaging verification

Run `33786964921`, job `100753960778` passed materialization, exact-scope guards, Xcode 16.4 Release compile, identity/MinOS validation, IPA packaging and artifact upload.

Independent artifact re-download verified:

- outer artifact ZIP SHA-256 equals GitHub digest `983c3cb1aa650f727266019b9a1ea834fad9c29266a043a775f9109c40f0c9f4`;
- IPA SHA-256 equals recorded `5c26b36eb70117abbd27885f5b637827020f7fffcc949d79a45e5b9a19bc28b0`;
- source ZIP SHA-256 equals recorded `ff975b72afcfc660542c112a2eb55e4c0f8669e11933bc4d368df7b3c7c8f68e`;
- both archives pass integrity tests;
- built Info.plist: `com.embyplayerlab.app`, `OnePlayer`, `0.15.19`, build `286`, `MinimumOSVersion=15.0`, `CADisableMinimumFrameDurationOnPhone=true`;
- runtime Mach-O MinOS audit reports 15.0 and passes the required <=17.0 ceiling.

## Explicitly preserved / excluded

Preserved: single UIKit interaction owner; Build236 acquisition behavior; current/previous/next clear-Hero residency; page-level foreground `compositingGroup()`; full-width page movement; backdrop blur/blend; white-flash correction; max-refresh-through-settle; rapid takeover; `>=500 pt/s`; `>=0.28`; 0.22/0.18 settle; iOS 15.0 priority; Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM→302→115/CDN.

Excluded: new DisplayLink/frame latch; timer/watchdog/retry/fallback; interpolation/prediction/synthetic positions; second progress owner/value; blur removal; residency reduction; gesture rewrite; unrelated Home/poster refactor.

## Validation state

- Build241 product interaction/presentation baseline retained: ✅
- Manual prolonged FPS transcription retired: ✅
- Architecture source review: ✅
- Build286 code written: ✅
- Exact-scope/static guards: ✅
- Xcode 16.4 CI passed: ✅
- IPA produced + independently verified: ✅
- Real-device smoothness result through Build288: tested, insufficient ❌; comprehensive gesture/visual regression pass not inferred.
- Stable/frozen reopened performance task: ❌

## Latest evidence / assessment — 2026-10-05

On 2026-10-05 the user explicitly reports that Build288 retains Build286 carousel logic and still visibly drops frames during swipes, fails to sustain the desired 120 FPS, and feels substantially worse than the competitor. This is qualitative target-device evidence, not a new numerical frame trace. Git-tree comparison of exact Build288 source `ce565996e37dcb750117c9de4607b23b673edce3` against exact Build286 `7e7b2ec944f5c0e74bc291e37683f1529e3d46b4` confirms identical HomeCore, Hero, HeroScrollState and all four carousel runtime/diagnostic blobs. Therefore the Build286 progress-scope A/B has now been real-device exercised through Build288 and is insufficient as a final smoothness fix; no unsupported claim of zero improvement is made. Build288 detail-navigation acceptance remains separate and unchanged.

PR #289 and its branch head both still match exact source `7e7b2ec944f5c0e74bc291e37683f1529e3d46b4`. Other current checkpoints were checked: Poster Build283 and Aether Build235 remain separate owners/branches; the Search checkpoint is Completed. No branch/Build/candidate collision or new allocation. No source code changed in this assessment.

## Confirmed design requirements — 2026-10-05

User agreed to requirements-first refactoring and requested structural exclusion of avoidable long-frame work. The user explicitly selected immediate new-drag takeover from the current visible position during release settle. Source-grounded requirement/phase/owner/validation matrix is `docs/project/HOME_CAROUSEL_REFACTOR_PLAN.md`. Image decode and logger persistence are already off-main; renderer/GPU cost and image-publish invalidation remain distinct unresolved boundaries. No source code or new candidate was created.

## Latest visual/residency proposal — 2026-10-05

User permits lower Home content to use solid color below the Hero seam and asks about five prebuilt stacked pages versus dynamic creation. Recommendation: test bounded full-page residency (actual current cap is6) plus separate opaque lower-background design. Current source already has three clear-Hero residents and all foregrounds; do not describe it as fully dynamically created. Opacity0 is not zero memory/CPU, and prepared decode is not guaranteed GPU residency. Plan contains startup/memory/first-visible tests; fixed/per-page base color remains unspecified. No source/Build change.

## EX参考视频已检查 — 2026-10-05

用户上传14.8s/30fps/510×1108的 `RPReplay_Final1791200921.mp4`；已分段抽帧检查快速连续切换、按住往返和慢拖。观察支持前景横移、背景基本原位渐变、拖动进度可逆和下方布局稳定。具体时间范围、文件身份与推断限制已写入 `HOME_CAROUSEL_REFACTOR_PLAN.md`。它不证明EX实际120FPS、内部常驻/框架/阈值，也不证明其settle中接管机制；立即接管是用户已确认的OnePlayer需求。无代码/Build变更。

## 全页常驻主方案已选 — 2026-10-05

用户认可有界全页预建常驻，以降低切换期间创建成本。实际项数沿用HomeModel最多6项，5页为示例。采用稳定节点+仅当前/目标运动更新，背景原位渐变/前景全宽横移、单底色和即时接管共同作为下一实现目标。具体实施顺序已写入 `HOME_CAROUSEL_REFACTOR_PLAN.md`。推荐按EX外观准备每页底色并随过渡变化，作为可逆默认设计，不要求额外用户裁决。尚未写代码/分配Build，不声明真机收益。

## Next exact action

进入具体实施核对：重新验证PR#289/分支/head与最新main及其他Active任务身份，确定同一任务的串行实现基线；核对稳定UIKit/CALayer呈现和现有资源组件的实际API/生命周期，落实单过渡owner的立即接管与有效完成身份。然后实现有界全部页面常驻、前景横移/背景混合和下方单底色，完成必要验证并连续推进至身份核验后的测试IPA。静态/实现阶段不把收益写成已真机通过。当前用户本轮询问下一步，已确认的设计选择不再重复请求批准。

无须六份旧会话；只有真实未记录且会重复的新实现证据才补查。保留P0/Frozen与MinOS15；不得修改其他任务checkpoint或共享Poster资源链，除非核对证明确实必需并记录冲突边界。
