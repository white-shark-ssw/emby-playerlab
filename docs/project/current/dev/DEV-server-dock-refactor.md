# DEV-server-dock-refactor

- **Status:** Active
- **Work ID:** DEV-server-dock-refactor
- **Task:** 底部 Dock 独立组件与统一布局宿主重构
- **Routing aliases / keywords:** Dock重构 / 底部Dock / 底部导航栏重构 / dock refactor
- **User intent / acceptance criteria:** User explicitly requested a new independent task and implementation on2026-10-06. Separate Dock presentation and viewport layout authority from page-specific content. Stable identical bottom position on Home (carousel on/off), Favorites, Search and Settings; keyboard must not lift Dock; preserve native push/pop and detail fully-immersive preference; reserve content clearance centrally; retain tab switching/Search lifetime/Home tap actions.
- **Baseline:** Accepted OnePlayer0.15.26/Build293 tested fa8ff44ff4a5384fd4603a64b33354f941764a8c; current main119ab10eee869488b97415746a0243f51953eba0. Recursive tree compared: all product/source blobs identical; only closeout docs differ.
- **Working branch:** refactor/server-dock-build294
- **PR:** not created yet
- **Initial branch head:**119ab10eee869488b97415746a0243f51953eba0
- **Build candidate:** Reserve OnePlayer0.15.27/Build294; OnePlayer-0.15.27-build294-server-dock. Build index/current Active tasks/CI candidates checked:293 latest Home,283 Poster; no294 allocation observed.
- **Evidence:** First implementation and local source/scope guard passed; native/Xcode/IPA/device pending.
- **Files / modules in scope:** EmbyServerRootViewV3, new ServerDock component/host, HomeCore/Rows, ServerBrowse, SearchExperience, OnePlayerSettingsViews, ImmersiveUIComponents Dock environment/presentation; AppIdentity/changelog/targeted validation.
- **State owner / shared dependencies:** Root retains selected tab/Search model/Home tap actions; shared Dock host owns stable viewport geometry and page-requested presentation. UIKit retains navigation.
- **Frozen / do-not-touch:** Build293 carousel native/runtime/input; P0 player/MPV/PiP/Transport/Cache/Emby session; iOS15.0; shared image caches and Poster collection/persistence.
- **Parallel conflicts checked against:** Aether task separate player/settings scope; do not edit PlayerSettings. Poster task shares ServerBrowse file; current checkpoint explicitly has no justified next code change. User informed of file overlap. Restrict changes there to Dock signatures/hosting/clearance; preserve native poster/persistence/navigation code and do not modify its checkpoint. Search checkpoint is Completed and accepted lifetime is retained.
- **Completed:** Repository/baseline/parallel guards; branch/task/candidate registered; independent typed Dock configuration/bar and fixed-viewport host implemented; page AnyView signatures removed; Search-only root overlay removed; shared bottom clearance; detail policy retained. Root action extraction and frozen source checks passed.
- **Validation state:** Linux cannot run UIKit/Xcode locally. Use source/scope checks then macOS exact-source UIKit regressions + Release build/package/MinOS audit.
- **Pending:** Finalize host design around native NavigationView roots and detail preference; implement; tests; draftPR; CI; artifact identity verification; documentation.
- **Next exact action:** Publish reviewed product patch, create draft PR, run exact-source native Dock/carousel regressions and Release IPA workflow; inspect package identities then update current checkpoint.
- **Rejected / do-not-repeat:** No page-local Dock padding patches, content-dependent Dock anchor, second tab/navigation owner, speculative timers/retries/fallbacks, unrelated carousel/performance refactors.
- **Open questions / risks:** Hosting above navigation would leave Dock visible on destinations that previously hide it; avoid global visibility guesses. Actual geometry and keyboard must be verified in native tests and on iPhone15ProMax/iOS17.0.

