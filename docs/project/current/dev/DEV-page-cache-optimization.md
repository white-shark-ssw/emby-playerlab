# DEV-page-cache-optimization

## Status

**Active closeout — Build213 / OnePlayer 0.14.46 page-cache milestone is target-device accepted, but final PR #260 integration is intentionally blocked by a new `main` Build-identity conflict from the parallel poster task. Do not renumber or discard the accepted page-cache Build213 identity. Do not merge until the poster task retires/reallocates its conflicting Build213 one-shot workflow/candidate and `main` is rechecked.**

- **Work ID**: `DEV-page-cache-optimization`
- **Routing aliases / keywords**: 页面缓存优化 / 持久化页面缓存 / 磁盘页面缓存 / 收藏页面缓存 / 库页面标签缓存 / library page cache / favorites cache
- **Working branch**: `perf/page-cache-optimization`
- **Draft PR**: #260
- **Accepted candidate**: OnePlayer **0.14.46 / Build213**
- **Exact tested product source**: `c8c238816c34ba3d8834ac37bdf7b234cd596458`
- **Standard MPV CI run/job**: `33052588518 / 98451457434` — success
- **Artifact**: `OnePlayer-0.14.46-build213-page-cache`; ID `9638292306`
- **IPA SHA-256**: `a8c2d1753db33f41a5b07ce22c4706eb102cf5d905f1aaeee8f54d689b176fc8`
- **Source ZIP SHA-256**: `3a59bc8fb8dc55a83abd8adf76841db47640df8944f39920969b06bd55927051`
- **Built MinOS**: iOS 15.0
- **Target device**: iPhone 15 Pro Max / iOS 17.0
- **Real-device result**: user reported **“验收通过” on 2026-08-27**

## Accepted first-milestone contract

- Favorites + Library top tabs 内容 / 建议 / 预告片 / 合集 / 类别 / 我的收藏 / 文件夹 restore the last accepted presentation snapshot from disk before live refresh completes.
- Live Emby refresh on page/tab entry remains authoritative and is not suppressed by a snapshot.
- Only state already accepted by the existing page owner replaces the disk snapshot; refresh failure does not erase a valid old visible/disk snapshot.
- Necessary Library paging frontier is restored with cached content.
- Disk persistence is presentation-only, stored under `Library/Caches/OnePlayer/PagePresentation` with JSON schema 1 and atomic writes.
- Library `sortBy` remains a Preference concern and is not persisted by page cache.
- `selectedTab`, scroll restoration, Favorites root session retention, Search/Genre/Person persistence are outside this milestone.
- Cache identity remains safely route-scoped by `baseURL + userId + scope (+ library.id)`; same-server URL changes may cause a benign cache miss but cannot cross user/server data.
- No Player/MPV/PiP, UnifiedTransport, playback Session Cache, STRM/302/115/CDN, Home-carousel or shared poster-image owner changes.

## Evidence level

- Code written ✅
- CI passed ✅
- IPA produced ✅
- Real-device accepted ✅
- Feature milestone stable on tested Build213 ✅
- Merged to `main` ❌ — blocked by parallel Build identity conflict

## Closeout conflict discovered after acceptance

After Build213 was distributed and accepted, `main` advanced to `20253d24eed3431a55c1a1f51fa5d1d10b9cd1a2` with `.github/workflows/temp-apply-build213-poster-display-uikit.yml` from the independent poster task.

That workflow explicitly attempts to create another `0.14.46 / Build213`, including `Sources/Core/AppIdentity.swift` 0.14.46 and `docs/changelog/CHANGELOG_v0_14_46_build213.md`, then push the candidate to `perf/poster-grid-smoothness`.

The one-shot run `33055157542` failed before any job was created, and `perf/poster-grid-smoothness` remains at its existing Build212 source `4f0a89ab026cd2103f66e5854a1f352d34852e45`; therefore no second product Build213 was actually produced. However, the conflicting one-shot workflow remains on `main` and would still violate unique Build ownership if allowed to proceed later.

Per parallel-development rules, this page-cache task must not edit the poster task's checkpoint or silently repurpose its work. The already distributed and accepted page-cache Build213 keeps canonical ownership of Build213. The poster task must retire/reallocate its attempted Build213 identity in its own task context.

## Durable docs already updated on this branch

- `docs/project/MODULE_STATUS.md`: page cache marked Stable at Build213 / target-device accepted, merge pending.
- `docs/project/PROJECT_STATE.md`: Build213 recorded as accepted runtime baseline with merge pending.
- `docs/project/BUILD_TEST_INDEX.md`: Build213 full CI/artifact/hash/real-device evidence recorded.
- `docs/project/TECHNICAL_DECISIONS.md`: D017 records the accepted presentation-warm-snapshot architecture.
- `docs/changelog/CHANGELOG_v0_14_46_build213.md`: accepted validation evidence recorded.
- Temporary page-cache Build213 workflow was removed after successful IPA production.

## Next exact action

1. Wait for the independent poster task to retire/reallocate the conflicting `Build213 / 0.14.46` one-shot workflow/candidate; do not modify its checkpoint from this task.
2. Re-read current `main`, all Active checkpoints and `BUILD_TEST_INDEX.md`; confirm Build213 uniquely belongs to page-cache and no new product/source overlap exists.
3. Resync PR #260 against then-current `main`. If synchronization changes only unrelated docs/workflow cleanup, review diff; if product/dependency source changes materially, rerun affected CI before merge.
4. Update PR #260 from Draft to ready only after the identity guard passes.
5. Merge PR #260, record the actual merge SHA in `PROJECT_STATE.md` / `BUILD_TEST_INDEX.md` / `MODULE_STATUS.md`, then delete this checkpoint as the final completion step.
