# DEV-poster-grid-smoothness

## Status

**2026-10-06 implementation authorized:** User selected this Work ID and requested P0–P2 continuous execution to an identity-verified Library.items pilot IPA. Resume guard passed: historical PR#282/head39014a03 agree; Aether uses a distinct branch/Build235, Search is Completed. New working branch `perf/poster-wall-library-build295` starts at current main `03d1bad260666c3f38ae3913d6828f393690673e`, inheriting accepted Build294/293. Reserved OnePlayer **0.15.28 / Build295 / poster-wall-library** (no matching branch/candidate; current index maximum294). Historical branch/PR283 remains untouched; no wholesale stack merge. Scope P1 ordered Library persistence/background restoration + P2 native Library.items cell/preparation/host; G02–G15/Home await pilot device evidence. PR not created yet. Next exact action: inspect production cell/image/paging contracts; implement P1/P2, test actual source, open dedicated PR, exact-source CI/package/identity audit. Code/CI/IPA/device pending.


**Active — 2026-10-06 current phase: design, full entry inventory and executable handoff plan completed; new reconstruction implementation not started.** Read [POSTER_IMPLEMENTATION_PLAN.md](../../POSTER_IMPLEMENTATION_PLAN.md), [POSTER_PRESENTATION_DESIGN.md](../../POSTER_PRESENTATION_DESIGN.md) and [POSTER_ENTRY_INDEX.md](../../POSTER_ENTRY_INDEX.md). This turn authorizes plan/document updates only. Historical Build283 identity is retained below; no new branch/Build/CI/IPA or runtime acceptance has been created. Latest accepted overall product is Build294; the newly reported performance behavior has no supplied installed Build/log.

**Historical candidate evidence — Build283 / OnePlayer 0.15.16 is target-device positive for both intended regression surfaces. The user confirms Library `.items` cover entry to detail has the normal system entrance animation again, accepting the always-mounted hidden `NavigationLink` repair. The accompanying `OnePlayer-App-1788197938.log` also confirms Build280's off-main pagination fix survives unchanged: one continuous 60→660 native Library session runs at 118.34 Hz with p50/p95/p99 8.33/8.70/17.85 ms, max 25.02 ms, exactly one >=25 ms frame and zero >=33.3 ms frames while all persistence remains `main_thread=0` and snapshot total grows to 208.87 ms. The user reports no visible twitch. No additional code change is justified from this log. The broader historical fixed-item/non-pagination poster tail is not globally frozen by this single pagination session, and native interactive swipe-back has not been explicitly rechecked in the latest device report.**

- **Work ID:** `DEV-poster-grid-smoothness`
- **Routing aliases / keywords:** 首页流畅度 / 3×3页面流畅度 / 3列海报流畅度 / 库页流畅度 / 海报网格优化 / 海报墙重构 / 海报墙抽象 / poster grid smoothness
- **Identity note:** The following branch/PR/source/candidate describe the historical unmerged experiment. Latest-main reconstruction will have its own explicitly recorded identity in this same Work ID after implementation is authorized; it has not been allocated in this planning turn.
- **Working branch:** `perf/poster-grid-offmain-persistence-build280`
- **Draft PR:** #282
- **Current exact product source:** `39014a03e2681aed3647bdd6d7d7b1c82b8cc4f6`
- **Direct parent:** Build280 `531d7f53c55e1e3cff44069e9bce3193ac94749a`
- **Current candidate:** OnePlayer **0.15.16 / Build283**
- **Target device:** iPhone 15 Pro Max / iOS 17.0
- **Deployment Target / built MinOS:** iOS 15.0
- **Build identity guard:** Historical Build282 / 0.15.15 belongs to Home and Build283 / 0.15.16 to Poster. Home carousel is now completed/frozen at Build293 and Dock at Build294. Re-query all allocations before assigning a new candidate; do not reuse historical identities.

### 2026-10-06 — New cross-page poster-scroll report / baseline distinction

User reports that poster-heavy pages, including Home and Library, do not sustain the desired120FPS and can visibly pause or appear to move backward for one frame during otherwise continuous upward/downward scrolling. This is new qualitative device evidence; the installed Build, an accompanying log/video and exact event timestamps were not supplied. Do not attribute it to Build283 or infer a measured interior contentOffset reversal.

Read-only audit of current main **4acd00c935b7414b05eb791596cf4ee1d460d812** (accepted overall Build294) confirms Home uses vertical SwiftUI ScrollView/LazyVStack with nested horizontal ScrollView/LazyHStack rows, and Library paged poster tabs still use shared LazyVGrid. Library snapshot construction/JSON/atomic-write remains synchronous in that main source. The native Library items collection and ordered off-main persistence belong to **Build283 /39014a03e2681aed3647bdd6d7d7b1c82b8cc4f6**, still-open Draft **PR#282**, not the accepted Build294 product. PR#282 head and checkpoint identity were rechecked and agree. Do not claim those old fixes already run in Build294 or that this report invalidates their narrowly accepted pagination result.

The Build283 native experiment still hosts V3PosterCard through UIHostingController<AnyView>; same-ID representable updates reconfigure all visible hosts. These are verified structural facts, not proof of the present hitch's cause. Shared main image decoding already runs off-main and decoded/disk caches already exist; do not propose moving an already-background decoder as a new fix.

Discussion direction, not an approved implementation decision: first identify the failing installed baseline and correlate frame/presentation gaps with real offset, legal bounds, cell work, image adoption, pagination and persistence. Evaluate a shared reusable native poster cell/image-adoption layer and grid/sectioned-row adapters through a small Library A/B before expanding to Home. Preserve existing cache authorities, navigation/pagination semantics, accepted Build293 carousel, Build294 Dock and iOS15/P0. Container replacement alone has already been insufficient historically. No code, branch, Build allocation, merge, CI or IPA change was made for this discussion.

### 2026-10-06 — Overall design prepared

User confirmed the carousel-style preparation/residency principle and requested an overall poster design. The detailed proposal is [POSTER_PRESENTATION_DESIGN.md](../../POSTER_PRESENTATION_DESIGN.md): native reusable fixed-layout cells, one shared request/preparation coordinator using existing caches, UIKit prefetch, bounded readiness window, target-item updates, ordered off-main Library persistence and separate Library/Home adapters. Home's accepted carousel and Dock remain owned by their existing components.

This authorizes design/planning in this turn, not implementation/branch migration/merge/Build allocation. Main planning baseline4ec7b816f1d2efd7069de3e300d12f4e4042889b retains accepted Build294 product behavior. PR#282 remains Draft/open at39014a03e2681aed3647bdd6d7d7b1c82b8cc4f6 and was rechecked. Other Active task Aether is outside this scope; Search checkpoint is Completed and its accepted semantics are protected.

Visible image placeholders are distinct from metadata paging. The proposal preserves current sequential60-item Library paging; a5000-item full sparse extent with arbitrary jumps would require separate range-loading semantics and is not silently included. Preparation-window/concurrency values are measurement choices, not verified EX constants. Image decoding already runs off-main in main; the new work is earlier/shared preparation and lighter native adoption, not pretending a new background decoder is needed.

Evidence: **design written /source+task identity audited /no product code /no new CI or IPA /new performance behavior not device-tested**.

### 2026-10-06 — Clarified placeholder and warm-cache return experience

User reports EX visibly uses a placeholder only for first network downloads; disk-cached normal revisits, relaunch and deep (~item2000) status-bar return to top feel already loaded. IMG_8037.png confirms the intended placeholder: fixed poster rectangle plus actual movie name (existing badges may remain), not whole-card blank skeleton. EX's virtual-list implementation is unknown and no all-image residency or measured FPS inference is made.

Updated [POSTER_PRESENTATION_DESIGN.md](../../POSTER_PRESENTATION_DESIGN.md), section6A: retain loaded metadata independently of image/cell eviction; represent current page's first-screen prepared resources as bounded demand within the same image coordinator, so distant return-to-top is covered even after local prefetch has moved far away. Prepared first-screen images should stay ready during normal browsing; no duplicate disk/decoded cache, bitmap copies, metadata reset or return-top refresh. Warm process relaunch prepares the first screen from disk early rather than synchronously reading on scroll. Home follows the same contract while accepted carousel/Dock stay owned by existing components.

Warm-cache normal revisits and deep return-top must not show a perceptible reload/placeholder breakpoint; image reread/decode remains real asynchronous work and must be scheduled ahead, not claimed zero-cost because it is cached. This is an acceptance requirement/design update, not an implemented/tested guarantee. No new product source, branch, Build, CI or IPA.

### 2026-10-06 — Shared-wall scope explicitly expanded

User asks whether the poster wall can be abstracted across Library, Favorites-more, tag/filter results, person/role results, typed search and recommendation/more routes. Source audit confirms many already use EmbyPosterGrid, but outer ScrollView, card/loaders and page-state wrappers remain separate. [POSTER_PRESENTATION_DESIGN.md](../../POSTER_PRESENTATION_DESIGN.md) section2A now defines complete shared presentation ownership plus page data/navigation adapters, real call-site coverage, query/source identity and lifecycle constraints.

Confirmed adapters include V3LibraryBrowserView, V3LibraryGenreGridView, V3FavoriteCategoryGridView, EmbyDetailFilterResultsView, EmbyPersonMediaView, V3GlobalSearchServerGridView and V3EmbyGlobalSearchView.recommendationsSection. Legacy V3EmbySearchView and the user's “推荐页面的更多观看” wording require actual live-route confirmation before implementation; no invented target API. Preserve60/18/9+6 paging, Person vs media/folder navigation, native return, shared budget and accepted Search semantics. Generic3-column routes should migrate after the Library core pilot and before the special Home adapter. Planning only; no implementation/Build/CI/IPA change.

## Accepted pagination-persistence result

Build278 proved synchronous full-Library persistence caused the pagination-adjacent severe-frame family: snapshot totals 38.31→94.66 ms paired with 49.96→108.33 ms display gaps, correlation ≈0.991.

Build280 moved full Library snapshot object construction, JSON serialization and atomic write onto one serial `.utility` queue while the MainActor model awaits ordered completion. `OnePlayer-App-1788190813.log` showed every persistence record at `main_thread=0`; clean 60→775 pagination no longer reproduced the Build278 50–100 ms persistence-correlated family even while snapshot work grew to 267.76 ms. The user likewise reported no large twitch.

The user then force-quit/relaunched Build280 and reported cached-first Library behavior normal. `OnePlayer-App-1788191685.log` records the fresh process and continued ordered `main_thread=0` writes. It has no dedicated cache-load timing marker, so cached-first acceptance is the user's target-device observation.

Build283 now provides a second target-device regression pass after the navigation repair. `OnePlayer-App-1788197938.log` captures one continuous native Library session from **60→660 items over 19.62 s**:

- display **118.34 Hz**;
- p50 / p95 / p99 **8.33 / 8.70 / 17.85 ms**;
- max **25.02 ms**;
- **31** frames >=12.5 ms;
- exactly **1** frame >=25 ms;
- **0** frames >=33.3 ms;
- reconfigure: 20 events, 1.91 ms total, max 0.19 ms.

The sole 25.02 ms gap occurs with `insert_active=1`, about 17 ms after the 240-item insert began. It is not a persistence-completion pair: the corresponding off-main store/snapshot completes roughly 64/67 ms later. All 12 recorded Library store/snapshot pairs report `main_thread=0`; snapshot total still scales up to **208.87 ms** at the 660-item state without bringing back the old 50–100 ms display-tail family.

**Accepted sub-contract:** Build280's ordered off-main Library presentation persistence fixes the proven Build278 pagination-persistence tail and remains intact in Build283.

**Not globally claimed:** this one pagination session does not prove every historical fixed-item/non-pagination poster-tail family is permanently absent.

## Navigation regression and Build283 repair

The missing detail entrance animation was independent of persistence threading and originated when Library `.items` moved to the native UICollectionView path in Build273.

Build280 had `nativePosterNavigationLink` only inside `if let item = nativePosterSelection`, while its `isActive` binding read `nativePosterSelection != nil`. The native collection tap first set selection; SwiftUI then mounted the link with the binding already true. Build283 keeps the same hidden link mounted so the existing binding transitions false→true after `onSelect` sets the same `nativePosterSelection` owner.

No direct `UINavigationController.pushViewController`, custom transition or second navigation state owner was added. Native iOS push/pop remains system-owned.

**Target-device result:** the user confirms entering detail is normal again. This accepts the reported push-entrance regression repair. Native interactive swipe-back was part of the prior regression checklist but has not been explicitly reported in the latest device result, so it remains an explicit PR closeout check rather than something inferred as passed.

## Build283 source / CI / IPA identity

Build283 retains the native UICollectionView, Build280 persistence, pagination, image policy and existing detail destination. Exact Build280→283 compare is exactly four paths:

1. `Sources/Core/AppIdentity.swift`
2. `Sources/UI/EmbyServerBrowseV3.swift`
3. `docs/changelog/CHANGELOG_v0_15_16_build283.md`
4. `scripts/check_poster_grid_offmain_persistence.py`

A transient `scripts/__pycache__/*.pyc` generated during materialization validation was caught by exact compare and removed before finalizing the product commit. Final Build283 is one clean commit directly atop Build280 and contains no workflow/materializer/pycache file.

CI / package evidence:

- exact product source: `39014a03e2681aed3647bdd6d7d7b1c82b8cc4f6`
- Xcode 16.4 exact-source run/job: `33412757299 / 99556026814` — success
- artifact: `OnePlayer-0.15.16-build283-poster-navigation`, ID `9765884301`
- artifact digest / downloaded ZIP SHA-256: `555ba6cc5c2859fbc8ad8a20fd1784eaf520ff5e4c4d235b9f10c4273b8f24a0`
- IPA SHA-256: `472b543f679f5db3932195c2abad8d882e78610172ecbe703fc75947c44e5655`
- exact-source ZIP SHA-256: `c364da8ba7c7552feabb2b4375354f42472d7f88249fc77b29485ef9b3dbc40f`
- independently verified: `com.embyplayerlab.app`; OnePlayer `0.15.16 (283)`; `MinimumOSVersion=15.0`; runtime MinOS audit OK; `CADisableMinimumFrameDurationOnPhone=true`.

**Build283 evidence:** Code written ✅ / exact four-path scope+checker ✅ / CI passed ✅ / IPA produced+independently verified ✅ / detail-push real-device positive ✅ / pagination-persistence regression real-device positive ✅ / interactive-pop explicit recheck pending / universal poster stable claim ❌.

## Protected contracts

- Build280 off-main ordered Library persistence and Build213 cached-first/write-through semantics.
- Native iOS push/pop and interactive pop remain system-owned.
- Search Build256 accepted semantics.
- Accepted Build293 Home carousel (completed/frozen) and Build294 Dock; preserve their existing state/layout owners.
- Player / MPV / PiP / UnifiedTransport / Range/206 / playback Session Cache / Emby Resume/progress.
- STRM → HTTP 302 → 115/CDN client-direct path; NAS never relays media bytes.
- Deployment Target remains iOS 15.0.
- Never restore `targetTime / duration × fileSize`.
- No timer/debounce/throttle/watchdog/retry/fallback/interpolation or unrelated refactor.

### 2026-10-06 — Current poster entry inventory completed (source audit)

See [POSTER_ENTRY_INDEX.md](../../POSTER_ENTRY_INDEX.md), audited against main408ccc865262673ab708c01b13f20328aeff8066. The current V3 poster routes contain9 reachable EmbyPosterGrid call sites plus1 legacy V3EmbySearchView call site not referenced by the current root. Inventory adds the Library category-cover wall, recursive mixed folder/media walls, all four Favorite more variants, multiple filter/person entry paths, history/single-server direct search and multi-server more, and the recommendation grid itself. Horizontal Home/Library suggestions/Favorite/Search rows are registered separately. Detail similar/cast rows and episode/still viewers have explicit existing scope boundaries; no speculative Character API, collection-children wall or separate recommendation-more destination is asserted.

This is source reachability and design coverage only: all common-grid migrations and per-entry device checks are pending. No product source, Build, CI, IPA, frozen detail/carousel/Dock behavior or historical PR identity changed.

### 2026-10-06 — Executable implementation/handoff plan completed

User explicitly asks to review remaining gaps and prepare the existing task for a new implementation session. [POSTER_IMPLEMENTATION_PLAN.md](../../POSTER_IMPLEMENTATION_PLAN.md) now defines baseline/branch migration, real source owners, background metadata restoration ordering, image consumer/generation contracts, one vertical host including embedded Search recommendations, active-page status-bar scroll-to-top, native interaction/accessibility, global first-screen memory accounting, P0–P6 deliverables and stage gates, actual-source tests, per-entry device matrix, exact-source packaging and rollback.

Identity audit at maindf4c7bf3cd4b8de51f392e9af930d12c42c26219: PR#282 still Draft/open/unmerged with branch head39014a03e2681aed3647bdd6d7d7b1c82b8cc4f6. Other current task Aether is Active; Search checkpoint is Completed. All new code phases and new performance device checks remain pending. No new product branch, version/Build allocation, merge, CI or IPA.

## Completed / Validation state / Pending

- **Completed:** Overall design; source-audited G01–G15/H01–H05 entry inventory; implementation plan and copyable new-session instruction; historical/current baseline distinction; identity guard read.
- **Validation state:** Repository/doc links and source ownership audited; historical Build283 evidence retained only in its stated scope. New native cells/preparation/host integration: not written. New CI/IPA: none. New warm-restart/deep-return/120FPS device acceptance: none.
- **Pending:** Plan P0–P6. Library pilot is the first testable deliverable; other routes/Home remain planned. New branch/base/head/PR/candidate and measured window/concurrency settings are not allocated. Old interactive-pop explicit check remains pending.

## Next exact action

Planning handoff is complete; no product code or packaging was requested in this turn. The next operational action requires the new session's explicit implementation instruction and is given below.

In a new session explicitly instructed to implement: select this exact Work ID; read the linked plan first; recheck current main, historical PR#282 and other task/candidate identities. Execute P0 and explicitly record latest-main branch migration while preserving the old experimental identity. Then execute P1/P2 continuously through meaningful actual-source verification, exact-source Release CI and identity-verified Library.items pilot IPA. Use the plan's startup instruction; missing installed Build for the old report limits attribution, not source-grounded implementation under new authorization. After the user supplies the pilot's necessary real-device results, proceed through remaining Library and all G routes, then H01–H04/Home, and final matrix. Do not label design/native container/CI as solved120FPS, merge the historical stack wholesale, or reopen accepted carousel/Dock/Search/P0.

