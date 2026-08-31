# DEV-poster-grid-smoothness

## Status

**Active — Build280 / OnePlayer 0.15.13 target-device evidence positively confirms the off-main Library persistence A/B for the previously proven pagination-adjacent severe-frame family. The clean 60→775 pagination run no longer reproduces Build278's 50–100 ms persistence-correlated display-gap series even though snapshot work itself grows to 267.76 ms, and every persistence record reports `main_thread=0`. User report matches the log: no large twitch noticed in this test. This proves the Build278 pagination-persistence cause is fixed by the Build280 threading change, but does not prove universal 3×3 smoothness. Cached-first force-quit/relaunch restore is not directly evidenced by the supplied log, and later non-pagination long frames remain outside this causal fix. PR #282 therefore remains Draft/unmerged; stable remains false.**

- **Work ID**: `DEV-poster-grid-smoothness`
- **Routing aliases / keywords**: 首页流畅度 / 3×3页面流畅度 / 3列海报流畅度 / 库页流畅度 / 海报网格优化 / poster grid smoothness
- **Working branch**: `perf/poster-grid-offmain-persistence-build280`
- **Draft PR**: #282 — Build280 off-main persistence A/B; keep Draft until cached-first regression gate is explicitly checked
- **Current branch / PR head**: `531d7f53c55e1e3cff44069e9bce3193ac94749a`
- **Current candidate**: OnePlayer **0.15.13 / Build280**
- **Target device**: iPhone 15 Pro Max / iOS 17.0
- **Deployment Target / built MinOS**: iOS 15.0
- **Accepted overall baseline**: OnePlayer **0.14.49 / Build216**, PR #261, merge `f5ad126b7b47e9713b1949780a6507fb3f0ca50f`
- **Build280 evidence**: Code written ✅ / exact five-path scope+checker ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device pagination A/B positive ✅ / cached-first relaunch regression check pending / universal 3×3 stable ❌

## Current exact artifact identity

- exact source: `531d7f53c55e1e3cff44069e9bce3193ac94749a`
- branch: `perf/poster-grid-offmain-persistence-build280`
- Draft PR: #282
- Xcode 16.4 run/job: `33390236717 / 99481947293` — success
- cleanup job: `99482802350` — success
- artifact: `OnePlayer-0.15.13-build280-poster-offmain-persistence`
- artifact ID: `9757238604`
- artifact digest: `sha256:9b2d096e3c5d5909d17d3e9c875390cc2de81a3c50ef5158b7afcf3e56620111`
- IPA SHA-256: `e0b71190621671767b73cd95da63e733640ce2e2acfba9945f6178f6d12ac769`
- exact-source ZIP SHA-256: `7f23b8bd788a79b2ee71558835826c453440fdabaca47f082ce12a0604e114c5`
- package: `com.embyplayerlab.app`, OnePlayer `0.15.13 (280)`, MinOS 15.0, `CADisableMinimumFrameDurationOnPhone=true`

## Controlling causal baseline — Build278

Build278 / OnePlayer **0.15.11 (278)** exact source `6ff8113d9c45dfae6d745afa98b4a04a3956cf33` directly proved the pagination-persistence problem. Ten accepted +60 Library states from 120→660 items showed synchronous full-snapshot totals **38.31→94.66 ms**, followed only 1–8 ms later by **49.96→108.33 ms** display gaps; correlation was approximately **0.991**. At 480 items the snapshot completed before collection insertion while the same interval became a 79.17 ms display gap, proving persistence could consume the missed frame independently of insert duration. Fixed/no-append high-count sessions stayed near 119–120 Hz.

This established one narrow causal contract only: full accepted Library presentation snapshot construction/serialization/write must not occupy the scrolling MainActor frame path. It never proved persistence was the universal historical poster-hitch root.

## Build280 target-device result — 2026-08-31

Supplied log: `OnePlayer-App-1788190813.log`.

User report: **this test did not reveal the previous large twitch**.

### Clean Library pagination evidence

The first clean Library sequence grows from **60 → 775 items** through repeated accepted pagination while retaining the native collection/display diagnostics.

Every recorded `PagePersistentCache` store/snapshot reports **`main_thread=0`**. Snapshot total duration still scales substantially as content grows — representative accepted totals include **58.16, 68.75, 83.24, 104.65, 118.85, 120.09, 140.11, 168.12, 175.02, 220.20, 232.73 and 267.76 ms** — so the expensive work itself has not disappeared; it has moved off the scrolling main thread as intended.

Despite those larger background snapshot totals, the clean pagination motion sessions no longer reproduce Build278's severe tail. Relevant session maxima are:

- 60→480: display **119.21 Hz**, p50/p95/p99 **8.33 / 8.49 / 10.30 ms**, max **23.28 ms**, zero >=25 ms gaps;
- 480→540: display **119.30 Hz**, max **24.24 ms**, zero >=25 ms gaps;
- 600→660: display **119.25 Hz**, max **22.48 ms**, zero >=25 ms gaps;
- 660→720: display **118.21 Hz**, max **20.65 ms**, zero >=25 ms gaps;
- 720→775: display **114.50 Hz**, max **17.63 ms**, zero >=25 ms gaps.

Accepted-state write-through is visibly still active: every accepted page continues to emit the ordered Library snapshot/store records through the final 775-item state. This is direct runtime evidence that Build280 did not obtain the smoothness result by skipping persistence.

### Insert-duration interpretation

Three `insert-end` records are about **310–322 ms**, but exact Build280 source shows this timer spans `UICollectionView.performBatchUpdates` until its asynchronous completion callback. It is therefore update/animation completion lifetime, not proof of a continuous 300 ms main-thread block. The simultaneous display summaries remain below 25 ms, which independently confirms those values are not the old severe-frame mechanism.

### Later long-frame records are not the Build278 persistence family

The log later contains a 46.3 s diagnostic session with max **98.23 ms** and 18 >=25 ms gaps. That interval is contaminated by unrelated route activity: Search Random/`ExcludeItemIds` recommendation requests begin at approximately `15:39:16`, and detail pushes/PlaybackInfo/Similar requests occur at approximately `15:39:23` and `15:39:33`. The severe gaps in that interval have zero insert overlap and are not immediately paired with Library snapshot completion. They must not be used to resurrect the Build278 persistence correlation.

A later Library session at 360 items also records **70.13 / 67.18 ms** gaps roughly eight seconds after the preceding persistence completion; one coincides with a same-ID visible reconfigure. These show the broader non-pagination long-frame family is not proven eliminated. They do not contradict the narrow Build280 pagination-persistence result.

### Current conclusion

**Accepted for the narrow cause:** moving full Library presentation persistence off MainActor fixes the Build278 pagination-adjacent severe-frame family on the target device.

**Not accepted as universal:** Build280 does not prove every historical 3×3 hitch is gone, and the later fixed-item/non-pagination tail remains a separate concern.

**Cache regression evidence still incomplete:** this log contains ordered successful writes, but no dedicated `PagePersistentCache` load/restore diagnostic proving force-quit/relaunch cached-first restoration. Build213's cache implementation was intentionally unchanged, but the final regression gate should still be exercised on device before PR #282 is merged and the task is called stable.

## Protected contracts / do not touch

- Search Build256 data source, recommendation pagination, Dock lifetime and accepted semantics.
- Home carousel task and its independent branch/candidate identity.
- Player / MPV / PiP.
- UnifiedTransport / Range/206 / playback Session Cache / Emby progress and Resume.
- STRM → HTTP 302 → 115/CDN client-direct media path; NAS never relays media bytes.
- Deployment Target remains iOS 15.0.
- Do not reintroduce `targetTime / duration × fileSize`.
- Do not add timer/debounce/throttle/watchdog/retry/fallback/interpolation as a smoothness mask.
- Do not change pagination size/source, scroll physics, image quality/cache policy or collection architecture without new evidence tied to the remaining non-pagination tail.

## Do not repeat

- Fixed-row / row-stack / container swaps as an evidence-free twitch fix.
- Treating boundary bounce reverse samples as interior position correction.
- Treating `performBatchUpdates` completion lifetime as synchronous blocked-frame duration.
- Treating Build229's remaining broad hitch as evidence that off-main persistence cannot fix the separately proven pagination-specific family.
- Treating Search/detail activity captured by a still-running collection diagnostic session as Library pagination evidence.
- Claiming CI/IPA or this narrow target-device result means universal poster smoothness is stable.

## Completed

- Build278 established synchronous full-Library persistence as a direct pagination severe-tail cause.
- Build280 implemented the minimum off-main fix using one serial utility queue with ordered await; no coalescing or second state owner.
- Exact five-path scope/checker passed.
- Xcode 16.4 Release CI passed and IPA/source identities were independently verified.
- Build280 target-device Library pagination A/B is positive; user did not observe the previous large twitch and logs remove the Build278 persistence-correlated >=25 ms family.
- Accepted-state persistence writes continue and all measured persistence work reports `main_thread=0`.

## Pending

1. **One final target-device regression check:** force-quit the app after Library has a populated accepted state, relaunch, enter the same Library tab and confirm the Build213 cached-first presentation still appears before/while live refresh runs normally.
2. If cached-first is normal, update durable project state, promote the Build280 persistence-threading sub-contract, then decide whether PR #282 should be merged as the accepted pagination fix.
3. Do **not** bundle a new fix for the remaining non-pagination 70/67 ms tail into PR #282. If the user still perceives a separate visible twitch after the cache regression check, start the next evidence cycle from that remaining fixed-item family as a separate single-variable investigation.

## Next exact action

**Target device only:** perform the Build213 cached-first force-quit/relaunch regression check on Build280. No code change is justified before that result. If cached-first is normal, the Build280 pagination-persistence A/B has cleared its remaining merge gate; if it regresses, return the runtime behavior/log before changing cache semantics.
