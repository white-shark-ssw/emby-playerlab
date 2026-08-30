# OnePlayer Build / Test Index

This is a milestone index, not a list of every experiment. Evidence levels remain distinct: Code written → CI passed → IPA produced → real-device tested → stable/frozen.

| Milestone | Main purpose | Result / current meaning |
|---|---|---|
| Build84 / 0.13.17 | MDK RecoveryIsolation | Protected app/exit lifecycle better; did not prove abnormal media solved. |
| Build96 | MDK single-generation safety | Avoided unsafe same-process MDK generation rebuild after failure. |
| Build111 / 0.13.44 | MDK Seek experiments | Real-device long-tail Seek remained worse than MPV. |
| Build131 / 0.13.64 | MPV intent Seek | Recovered fast double-tap latency; exact scrub exposed precision/latency trade-off. |
| Build145 / 0.13.78 | MPV fast keyframe Seek | Current fast-Seek architecture established. |
| **Build173 / 0.14.6** | PiP completion/return simplification | PiP freeze point. |
| **Build176 / 0.14.9** | Episode overlay completion | Real-device accepted; source-owned episode-session replacement and trusted-natural-end auto-next stable. |
| **Build178 / 0.14.11** | Canonical Emby episode ordering | Real-device accepted; `/Shows/{SeriesId}/Episodes` order is canonical. |
| **Build179 / 0.14.12** | Carousel candidate | Real-device rejected: small-drag dead zone/reversal issues. |
| **Build180 / 0.14.13** | Carousel reversal continuity | Reversal improved; initial motion still coarse. |
| **Build182 / 0.14.15** | Detail scroll/presentation cache | Real-device accepted/frozen. |
| **Build183 / 0.14.16** | Fixed-foreground carousel experiment | Felt finer but changed required horizontal-slide semantics. |
| **Build184 / 0.14.17** | Detail visual hierarchy | Real-device accepted; merged. |
| **Build185 / 0.14.18** | Carousel page-slide refinement | Real-device rejected: first visible movement ~10/12/16 px vs EX ~1/1/2 px. |
| **Build187 / 0.14.20** | Carousel cadence diagnostics | Target device: first useful samples ~4.33/8.00/15.67/11.00pt; 120 Hz available. |
| **Build189 / 0.14.22** | Native carousel movement | Real-device rejected: split move/release owner could freeze between pages. |
| **Build191 / 0.14.24** | Detail episode selection/navigation | Real-device accepted; merged. |
| **Build193 / 0.14.26** | Passive native move + SwiftUI release | Real-device rejected; split-owner architecture rejected. |
| **Build195 / 0.14.28** | Lazy large player episode row | Real-device accepted; merged. |
| **Build198 / 0.14.31** | Single UIKit carousel lifecycle owner | CI/IPA verified; real-device lifecycle/settle/reversal okay, but minimum drag still too coarse. Single-owner input architecture retained. |
| **Build199 / 0.14.32** | Add/Edit Emby completion | Dedicated CI/IPA passed; target-device accepted; merged. Former accepted overall baseline; retained foundation. |
| **Build200 / 0.14.33** | Fixed-spatial foreground + linear blend | CI/IPA verified; target-device rejected because foreground stopped sliding horizontally. |
| **Build201 / 0.14.34** | 15% short-travel horizontal slide + linear blend | CI/IPA verified; target-device feedback: **“有点那种感觉了”**. Direction partially positive; not final. |
| **Build202 / 0.14.35** | Poster-heavy scrolling smoothness | CI/IPA verified, but target-device recording still shows stop/catch-up hitch; rejected for smoothness. |
| **Build203 / 0.14.36** | 30% carousel travel + accelerating opacity | CI/IPA verified. Target-device: 30% still too short overall while raw-progress spatial mapping makes the initial displacement/jitter perceptible again. Rejected as final parameterization; input owner retained. |
| **Build204 / 0.14.37** | Poster warm-cache cell-entry reduction | **Owned by poster-scroll.** CI/IPA passed; target-device tested on Home and library 3×3 and rejected because visible stop/catch-up hitching remains. A separately-created carousel Build204 package was retired because this identity was already occupied and must not be used for attribution. |
| **Build205 / 0.14.38** | 80% carousel travel + whole-range `progress²` visual mapping | CI/IPA verified; target-device rejected the curve as final: drag start is over-restrained and the whole-range nonlinear tail feels like unnatural easing. |
| **Build206 / 0.14.39** | Poster-scroll hitch diagnostics | **Owned by the independent poster task.** CI/IPA verified and target-device App-log captured: 17 diagnostic gaps (row 7, grid 10; grid max 118.7 ms), all with `load_ahead=none`; motion-aware correlation is still required. Diagnostic-only; not stable. |
| **Build207 / 0.14.40** | 80% soft-start / linear-tail carousel mapping | CI/IPA verified; target-device rejected as final. First visible displacement still too large and screenshots exposed structural foreground overlap: full-width foreground pages were only `0.80 × width` apart while EX preserved visible page separation. |
| **Build208 / 0.14.41** | Full-width carousel foreground page slots | **Real-device video tested; layout retained, final motion mapping rejected.** `pageStep = width` fixed structural overlap, but A/B vs EX showed hold-then-jump acquisition, prolonged easing lag and over-faded foreground. This evidence directly motivated Build215. |
| **Build209 / 0.14.42** | Motion-aware poster-scroll diagnostics | Target-device App log proved three Home motion hitches but grid attribution was invalid because Home/grid shared one global observed-scroll owner. Diagnostic tested; not stable. |
| **Build210 / 0.14.43** | Multi-owner poster-scroll diagnostics | **Current poster diagnostic baseline.** Target-device log validates simultaneous Home/grid ownership (`registered_scrolls=2`) and correct grid routing. Four Home dragging hitches all landed 6.2–11.0 ms after image commit; the single grid record was programmatic/micro-motion (`phase=moving`, `delta_y=0.33`) and not yet a user-drag grid stall. Real-device diagnostic tested; no performance fix claimed; not stable. |
| **Build211 / 0.14.44** | Home-carousel acquisition-relative line | **Owned by the independent carousel task.** Poster briefly prepared this identity but retired it before distribution as soon as the collision was confirmed; never use Build211 for poster attribution. |
| **Build212 / 0.14.45** | Source-aware poster-scroll diagnostics | **Target-device diagnostic tested.** Home: 5 real dragging hitches 43.6–73.8 ms, all 8.3–12.2 ms after memory/callback 1400px publish; callback/contrast only 1–3 ms, so those synchronous calculations are rejected as the primary Home cost. Grid: 11 real dragging hitches 31.0–37.3 ms, all 0–20.1 ms after network/display 378px publish and 118.8–177.8 ms after a cell appearance. Home and grid are now treated as separate runtime paths; no fix tested; not stable. |
| **Build213 / 0.14.46** | Favorites + Library persistent page warm cache | **Target-device accepted.** Favorites and Library 7 tabs restore persisted presentation data immediately after relaunch, then keep live refresh authoritative and write through only accepted fresh state. Pagination frontier is restored; refresh failure retains old snapshots; `sortBy`/selectedTab/scroll/root lifetime remain separate concerns. Dedicated standard MPV CI/IPA passed; first milestone stable and merged through PR #260 at `2303505ad4403182f5315d33c54f402903c809d2`. |
| **Build215 / 0.14.48** | Acquisition-relative Home-carousel render + foreground-alpha decoupling | **Real-device tested; partial success, not accepted.** Initial drag is now about as fine as EX and foreground blur/ghosting is gone, confirming acquisition-relative render baseline + opaque foreground. Overall tactile smoothness still trails EX (user: EX feels like smooth glass, OnePlayer like rough paper). 30fps video no longer shows the old macro hold/jump; residual micro-continuity/cadence cause remains unresolved and backdrop timing is only a hypothesis. |
| **Build216 / 0.14.49** | Detail episode-range inertia interruption | **Target-device accepted; stable and merged.** Range-pill taps synchronously stop active native episode-row deceleration at the current offset before the accepted Build191 range-first selection and existing 0.32 s target scroll. Tested source `dc00cac9f35ee4a3b950e4bb030bb324baf90b18`; run/job `33064051545 / 98489652724`; artifact `9643031850`; IPA SHA-256 `e3054a53398e1df48134fecd8c30671e10ecaa8a93df5483936adcf10e055075`; MinOS 15.0 verified. User accepted on iPhone 15 Pro Max / iOS 17.0 on 2026-08-27; PR #261 merged at `f5ad126b7b47e9713b1949780a6507fb3f0ca50f`. Build182/Build191/Build195/Build178 and P0 playback/transport remain untouched. |
| **Build217 / 0.14.50** | Home-carousel cadence diagnostics | **Target-device diagnostic tested; ~60 Hz baseline established, not stable.** 13 drags showed `maximum_fps=120` but delivered touch / progress / SwiftUI render / display ran near ~50–60 Hz while coalesced samples were much denser. 1421 publishes yielded 1415 render changes, rejecting major SwiftUI publication loss as the primary bottleneck. Run/job `33069670314 / 98508381540`; artifact `9645320748`; IPA SHA-256 `a2cf700b791cc66a60416b0250d501758aec532371dd029272066eaac4722bef`. |
| **Build241 / 0.14.74** | Home-carousel merged interaction/presentation baseline | **Previously accepted and integrated to main, but final/frozen status revoked by new 2026-08-30 target-device EX comparison.** Exact tested source `997a93a5f2c3c6544908ad112df5e714d2538e65`; run/job `33247149430 / 99086484795`; artifact `9713225510`; IPA SHA-256 `338cd80de1671da4fedabdeecd9a001e98074dd119dcf331fda548b420f1f236`; MinOS 15.0. Build241 retains the direction-aware latest-delivered `>=500 pt/s` fling gate, ordinary `>=0.28` progress commit and Build239/237/236/231/226/228 foundations. PR #262 integrated its exact runtime blobs into `main`. New confirmed Build241 recordings show repeated fast swipes can fall through to Home vertical scrolling and the on-screen FPS indicator can drop to roughly 30/44 while EX holds 120, so Build241 is now the merged baseline to improve, not a frozen final. |
| **Build257 / 0.14.90** | Home auto-advance × vertical inertia containment | **Target-device behavior verified, fallback-only; PR #265 closed without merge.** New auto transition is deferred during real Home drag/deceleration and the repeatable overlap large hitch is contained, but user rejects this as the preferred fundamental smoothness architecture. Build241 manual carousel remains the merged baseline but is reopened by the later direct EX comparison. |
| **Build258 / 0.14.91** | Shared 3×3 cadence diagnostics | **Target-device diagnostic tested; no fix claimed.** Exact source `165dffac8690c85283e7a53f4a0b7a20eeb52f8c`; run/job `33303767063 / 99236552731`; artifact `9729824297`; IPA SHA `f87acb32522e16153099dbee8c0b5f2523d9d24ccab75595acf86b700869f5c5`. Library/Search/detail-filter fixed-item routes cluster near display p50/p95 16.67 ms on a 120 Hz device. Search recommendations add a separate +6 append tail but Build256 semantics remain accepted/protected. |
| **Build259 / 0.14.92** | Shared 3×3 high-refresh A/B | **Target-device tested; high-refresh effectiveness proven; residual fine-grained hand-feel gap remains; not stable.** Exact source `39168e560d7e626557de8ebde6a88a5d38b3478b`; run/job `33304743577 / 99239168487`; artifact `9730129850`; IPA SHA `6d257396ba7a77178e62535c5dd04db58621ea25cf4a30e7e9bf415c7628a18a`; MinOS 15.0. `OnePlayer-App-1788087127.log` shows Library/Search display p50/p95 normally 8.34 ms vs Build258 ~16.67 ms; user reports obvious jitter is now difficult to see, but EX still feels more silky/fine and OnePlayer slightly coarse/wave-like. Offset KVO p95 often ~16.8 ms is a diagnostic lead, not proof of visible position discontinuity. PR #267 closed without merge. |
| **Build260 / 0.14.93** | Shared 3×3 native deceleration curve-continuity diagnostics | **Target-device diagnostic completed; superseded by Build261; not stable.** Exact source `b9a5de5255650f04e312e117f47453122de56adc`; run/job `33307963917 / 99247767453`; artifact `9731113592`, digest `sha256:293055cff1d8524a19ac4e21b39bb2b90afc7451fb1311c4760efc53d08739f8`; IPA SHA `1434d2b31c7ced4f344b2e946c5311d2c287774cfe72bbcbd527a24a1ccbffe8`; source ZIP SHA `875ea8a22e4aca0924c58e70faf250a891a8b97ce980a300bc6bcf1ee16998db`; MinOS 15.0. Per-display sampling confirmed a residual continuity/long-frame tail that led to Build261 long-gap attribution rather than guessed `decelerationRate` tuning. |
| **Build261 / 0.14.94** | Home 120 Hz vertical request + Library long-frame attribution | **Target-device tested; Home improved; Library two-layer long-frame cause established; not stable.** Exact source `e552bebd072a915e6cb10d591d704a5a3c342406`; run/job `33310546942 / 99254688579`; artifact `9731868664`, digest `sha256:bf9dab2b5acab5befc5516ce7bb5e920e9e01277caa757f137173c9c8b33c14d`; IPA SHA `d5f719c2cbcd8df4908f9f7ecfd9b5c5db88288cdf16cd45b09a263966511724`; MinOS 15.0. `OnePlayer-App-1788093610.log`: Home p50/p95 8.34 ms in all 12 sessions and user reports improvement, but occasional 50.31/36.24/76.94 ms tails remain. Library 49 sessions / 9,573 display samples: 356 gaps >=12.5 ms, 94 >=25 ms, 57 >=33.3 ms, max 175.79 ms; 193 overlap cell churn and 162 are untracked. Fixed-count sessions still reach 112.97 ms, while a fixed 600→600 fast-scroll session has 67/73 long gaps overlapping cell churn. Draft PR #270. |
| **Build262 / 0.14.95** | Home-carousel rapid-swipe ownership + persistent-residency long-frame A/B | **Exact-source CI/IPA verified; target-device pending; not stable.** Exact product source `86ac642ec33ad927a1bc3688824bfe0909b22bab` changes only AppIdentity, `EmbyHomeCarouselInteractionV3.swift` and `EmbyHomeHeroV3.swift`: small spatial axis hysteresis replaces the old 0.5 pt one-sample decision; a new horizontal swipe can take over commit/cancel settle endpoints whose authoritative progress is already 1/0 during delayed cleanup; and the existing current/previous/next resident window is reused for the blurred persistent backdrop as an explicit FPS/long-frame A/B. Build241 `>=500 pt/s` + `>=0.28`, Build231 foreground compositing, Build226 Hero residency, blur30, one UIKit owner and 0.22/0.18 normal settle remain. CI run/job `33311662277 / 99257718260`; artifact `9732204076`, digest `sha256:3558a391076ec952faf93ccdd8be94c2649ebfbf835d228466fae31b0aa8406b`; IPA SHA-256 `0e2a70edb9c5a22df87d0c2a028845dd54b516240f158c205087a0c889133bd5`; source ZIP SHA-256 `b4d6e917478755285e7575e45d71458a3731371dbf05ca9b85a37013f0cf37fa`; bundle `com.embyplayerlab.app`, MinOS 15.0 independently verified. Draft PR #269; real-device rapid-swipe ownership/FPS A/B required before merge. |
| **Build263 / 0.14.96** | Poster-grid severe-gap attribution | **Target-device diagnostic tested; fixed-item severe tail strongly localizes to high-speed cell/image burst; not stable.** Exact source `bff02ea8e76217b1fe07c298d8b9058b2db1fd08`; run/job `33313884881 / 99263646157`; artifact `9732862198`, digest `sha256:6e96b83b78bd8bd37b6e0e3dd2d3f820a328f3810ffc07faf86ea9526f4363bd`; IPA SHA `b8e15a1ac49582ec0dc519c316222d3944b6622cd8afb1afa22ab4d7bbf9d659`; source ZIP SHA `327444119b0b15f894c8a3d8012f195d79ceb77a7ef4b0af16abc3052893424c`; MinOS 15.0. `OnePlayer-App-1788098393.log`: 26 Library sessions / 5,557 display samples; 40 >=25 ms, 27 >=33.3 ms. Fixed-item sessions: 26/28 severe25 and 16/16 severe33 overlap cell churn; image publish overlaps 23/28 and 15/16; fixed severe untracked is 2/28 and 0/16. One fixed 775→775 fast pass concentrates up to 18 appear + 18 disappear + 27 image publishes per long-gap interval, while another fixed 775 pass has hundreds of cell/image events but zero severe25. Next A/B isolates one poster-cell/image-publication cost rather than pagination or scroll physics. Draft PR #271. |
| **Build265 / 0.14.98** | Home-carousel decoded-image analysis dedupe | **Target-device tested; rapid-swipe path remains functional, but no-screen-recording presentation still peaks around ~90 FPS; not stable.** Exact source `af92164890e7dc1c869bd586577b39177335df5f`; run/job `33318027714 / 99274932594`; artifact `9734083764`; IPA SHA `cf381c823e863562b1f21d40d61926e693b76fac3ba4d5023e7ce2c154ffa100`; MinOS 15.0. The system FPS HUD can climb to 120 only after screen recording is enabled, while carousel `CADisplayLink` callbacks are already around 8.4–9 ms, so callback cadence / recording-state 120 are no longer treated as final presented-FPS acceptance evidence. PR #274 closed without merge. |
| **Build269 / 0.15.2** | Persistent full-screen blur30 isolation A/B | **Target-device tested; blur-primary hypothesis rejected; diagnostic-only.** Exact product source `28d09e1cf7b3932e9033c370df12026889033197`; corrected CI run/job `33324520023 / 99292189686`; artifact `9735866507`; artifact ZIP SHA `0ef920811a06f762d7544e001c4d05628ce9f58e09ae9df81b6fa578f2e22d18`; IPA SHA `89ff7b1be43f7cefccfe9a4e5d32bab64ed45a4d9543c54ba8905200de3c1b8f`; MinOS 15.0. Removing only persistent `.blur(radius: 30)` left the no-recording system FPS HUD maximum around ~90, same as Build265. Do not inherit blur-off behavior or continue blur-specific tuning from this result. |
| **Build270 / 0.15.3** | Carousel foreground residency A/B | **Target-device tested; foreground-residency/compositing-count primary-cause hypothesis rejected; diagnostic-only.** Exact product source `cee2031aa7dc2abb59fb371196e22fbce56e32ee`; relative Build265 only AppIdentity and one foreground enumeration change: up-to-6 mounted foreground pages → existing current/previous/next resident window. Build231 `.compositingGroup()`, blur30, rapid-swipe ownership, 500/0.28 gates and all P0/Frozen paths remain unchanged. Run/job `33327653253 / 99300535892`; artifact `9736735731`; artifact digest `sha256:3a8ab81ccce3b4e6fc10928b829bad053a5060c3130c5ceced9398f85af4ad2b`; IPA SHA `169fb53bd3012c7b864912638f9f627e68282b3f6fb2dd18be58e48edca56b8d`; source ZIP SHA `f586270e852d09623cf5af38d6cd3b8bbaea85d4b8475bc4512e6a816f4ef98a`; MinOS 15.0. User result on 2026-08-31: without screen recording the system FPS HUD maximum remains around ~90, same as Build265/269. Do not inherit the residency change as product behavior. |
| **Build271 / 0.15.4** | Home-carousel frame-pipeline boundary benchmark | **Target-device pipeline tested; generic display-link/CALayer/SwiftUI 120 capability proven; diagnostic-only.** Exact product source `643ff1cbbd24ea06a315c632b08ac1ad162ee43f`; run/job `33329047915 / 99304195063`; artifact `9737161622`; IPA SHA `e2c6540e5705f9837dd75db6a41ef7a1ce02d24c3afb3f7abc2160faaa8a963f`; MinOS 15.0. User-supplied real HUD screenshots with recording off show `CA 60 / DISPLAYLINK 120 / SWIFTUI 120`. Exact source shows the CA `CABasicAnimation` omitted `CAAnimation.preferredFrameRateRange`, while the latter two explicitly requested device-max, so CA=60 is a probe-configuration result rather than evidence of a 60 FPS system ceiling. The actual Home/carousel tree versus interaction lifecycle is the next boundary. |
| **Build274 / 0.15.7** | Full real carousel-tree device-max progress probe | **Target-device tested; full steady-state tree is sufficient to reproduce the ~90 presented-FPS ceiling; diagnostic-only.** Exact source `6d18ca0cdb02bbce3f8fee13f8b5dc082a43ab63`; run/job `33333236724 / 99315483085`; artifact `9738285110`; IPA SHA `2fc79d5d09aa8e0c2f6384b4a50e933cf79f885c4b8d9fd05932fc1a3cc6295a`; MinOS 15.0. User result with recording off: `CAROUSEL ≈90 / TREE FULL ≈90`; supplied TREE screenshot captured 101 FPS at one instant but sustained observation remained around 90. This rejects interaction/settle/resident-rotation/new-target-loading as necessary causes and moves diagnosis to the two actual transition observer scopes. |
| **Build275 / 0.15.8** | Home-carousel full/tree scope + corrected pipeline control | **Target-device diagnostic tested; same-package input boundary isolated; not stable.** Exact source `8c6a882c03e60e9d2f49e9bc95b09f9e3712577b`; run/job `33334208681 / 99318066653`; artifact `9738555839`; IPA SHA `26229afe7b1cec29ab2bf2cca18c0348fd3337a2d6f996bd2a6b6b07c5bebe64`; MinOS 15.0. With recording off the user reports `CAROUSEL≈90` while `TREE FULL/HERO/BACKDROP/CA/DISPLAYLINK/SWIFTUI=120`. This supersedes Build274 TREE≈90 as stable causal evidence and proves the unchanged presentation tree has 120 Hz headroom under fixed device-max progress. Next boundary is real input→progress publication. |
| **Build277 / 0.15.10** | Home-carousel input-pipeline benchmark | **Exact-source CI/IPA verified; target-device pending; diagnostic-only.** Corrected exact source `1446640b0d9cec5cb2f39d36cff0bfeca4efd31d` changes only AppIdentity + frame-pipeline probe; HomeCore/Hero/Interaction/State remain exact Build275 blobs. `TOUCH LAYER` compares custom touchesMoved→CALayer, `PAN LAYER` UIPan→CALayer, `SCROLLVIEW` native horizontal UIScrollView; all receive equal device-max refresh request. Corrected run/job `33336619261 / 99324579844`; artifact `9739256003`, digest `sha256:06f93adeb462844b49e2c202ec694add5401f68afb49595f94cc3ddc68dbe37d`; IPA SHA `e27c86b5084db257174d3afd5cc33e147be6868ef6262245f8a3361ed63f097c`; source ZIP SHA `32516a75d88f1f98c9fa10159f1ac77772e9aa05098072079538c20bc337e396`; MinOS 15.0 independently verified. Earlier source `9402570e...` lacked fair refresh request and is not a device baseline. |
| **Build266 / 0.14.99** | Shared 3×3 unused loading-state publication A/B | **Target-device tested; insufficient as 3×3 fix; PR #273 closed without merge; not stable.** Exact source `957e88dcdc408e537d63b083d0f30e4b1157b1dc`; run/job `33320334963 / 99281058534`; artifact `9734732730`; IPA SHA `8130bed5dc90f51f257343e24e24a82a902582ecf4c41c9bcb858f1fdaa83901`. `OnePlayer-App-1788105516.log`: Home is clearly smoother and can reach 120 FPS; its three sessions have display p50/p95/p99 8.34 ms. Library still has 52 >=25 ms / 33 >=33.3 ms gaps across 9,576 display samples, max 130.12 ms; fixed-item severe gaps remain almost entirely cell/image-overlapped. Unused loader `isLoading` publication is rejected as a sufficient fix. |
| **Build267 / 0.15.0** | Poster-grid diagnostic reference-session self-overhead A/B | **Exact-source CI/IPA verified; target-device pending; not stable.** Exact source `dbe1b7c13dde68e52039cb7ae22fc5177fdd886f`, Draft PR #275, changes Build266 only by making the high-frequency diagnostic `MotionSession` a reference type (plus identity/checker/changelog). This removes growing-array copy-on-write self-overhead risk while retaining every diagnostic field, threshold, KVO/display sample and the existing 80→device-max refresh request; product Grid/image/pagination/Search/scroll physics are unchanged. Run/job `33321883421 / 99285172527`; cleanup `99285673130`; artifact `9735159629`, digest `sha256:bbabd6c84752a8437a9c23c02b6bdecc60915b9d6403d96d203745b8b9589661`; IPA SHA `54c2b8851d54aee126ff12f5c4f1a54f6fa62ca0293517fc137fc25b94ef3d3c`; source ZIP SHA `0ae52e34cc4aafb383ec7a7c4ca8adf1846df51c038b5a8f44fd7bc6ea9dad3d`; MinOS 15.0. |
| **Poster Build272 / 0.15.5** | Fixed-known-row-height + reverse-context A/B | **Target-device tested; fixed-row hypothesis rejected; not stable.** Exact source `75b479476c043ebf3010dba1ebf4136280e98a6c`; run/job `33329786724 / 99306181023`; artifact `9737328849`; IPA SHA `c5e562272375ef816bc584e1e6331986c5eaa5fc1462b485a00745d4a0612b42`; MinOS 15.0. User still reports roughly 110–120 FPS and whole-content up/down twitch. Fixed `775→775`, 5358.60 ms: display 118.50 Hz, offset 110.85 Hz, no item-count/load-ahead change, reverse max 33.00 pt, content-height/inset deltas all 0.00 pt. Explicit standard row height is insufficient; reverse may still include legal edge bounce because distance-to-bounds was not captured. PR #278 closed without merge. Next poster architecture gate is Library-only native UICollectionView 3×3; stop additional SwiftUI grid/stack variants. |
| **Build219 / 0.14.52** | Home-carousel maximum-refresh A/B | **Target-device diagnostic tested; 120 Hz request effectiveness proven, residual image-presentation gaps remain.** Keeps Build215/217 motion semantics and only requests exact device-max frame rate on the drag-local diagnostic display link. Delivered touch ~53→103 Hz, progress ~51→99 Hz, SwiftUI render ~50→98 Hz, display ~57→110 Hz; ordinary display p95 is usually 8.34 ms and the on-screen FPS meter repeatedly reaches 118–120. Still records episodic 34–50 ms gaps, many within ~3–25 ms of Hero/persistent 1400px callbacks. Tested source `0b894bc37fcd0086aeaf9e1a29de0e85f5b0ee94`; cleanup `a5050075ccceaf46196696bfa3b812293800f340`; run/job `33080240879 / 98545151906`; artifact `9649815558`; IPA SHA-256 `a0b7bad3c563f76e3e560f55da6eec67697a8bf609b70b5a672ee1a0ed1ab85e`; MinOS 15.0. Not stable. |
| **Build218 / 0.14.51** | Poster grid UIKit display candidate | **CI/IPA verified; Home target-device still visibly hitches; grid A/B not yet reported; distributed package has a confirmed transparent-Logo regression.** Exact source `ccc3a69f3b77c56a730593f072a2c7dfde599073`; run/job `33066739271 / 98498551491`; artifact `9644109849`; IPA SHA-256 `104eb5266c304102c912eaa2b9e95a4f0ae6183b0bf071fd377b3a52ea8d57bc`; MinOS 15.0. The carousel owner file was unchanged, but its transparent Logo entered the poster-task shared UIKit display path and exposed the surface background. Poster branch head `ac8a8cd0b87c4ee544c8817fec13edeea226826b` now contains only the transparency-semantic correction; corrected source has no CI/IPA yet. Not stable. |
| **Build220 / 0.14.53** | Corrected poster grid UIKit display A/B | **Target-device tested; 3×3 smoothness basically unchanged; not accepted.** Exact source `6198466a749a54603a67c6c32bc0efcf9d7e2082`; run/job `33083504023 / 98556783889`; artifact `9651230376`; IPA SHA-256 `a73a33866745418663d1dcc35634f5b21b0a73436a91f40ed8a4f6dc6bbcf574`; MinOS 15.0. User verdict: “基本一样”. App log retains a 33.3 ms grid dragging hitch (`network/display/Primary/378` commit age 35.8 ms; cell/load-ahead age 171.7 ms) and a 74.1 ms moving hitch. Bypassing surrounding SwiftUI poster-cell observation is rejected as a sufficient fix. Next step is measurement-only around MainActor image publish/Combine→UIImageView adoption and pagination/persistent-cache apply; not stable. |
| **Build221 / 0.14.54** | Home-carousel persistent-drag presentation isolation | **Target-device horizontal A/B tested; initial take-up acceptable, overall feel still worse than EX; pale/white transition regression; rejected as final, not stable.** During active drag only, outgoing persistent stays opacity 1 and target persistent is not mounted; Hero transition and Build219 high-refresh path remain. User reports first movement feels okay but overall hand feel still trails EX. Supplied recording visibly shows washed/brighter intermediate states; source inspection shows Hero continues crossfading over a frozen outgoing persistent plus the existing `systemBackground` gradient, so the mismatch is a plausible A/B-specific visual cause. Tested source `26fc82771b6778af14974fdac293ece0685fc76d`; cleanup `1d6df7f2490a5ef5968cafb229a46cba93c622db`; run/job `33090175887 / 98580579889`; artifact `9654120029`; IPA SHA-256 `d2ee4fb2d40c251399951bc72ba6ad35fbe8ba3bfd72b861274b9b2c38fe0d9c`; MinOS 15.0. Next horizontal A/B should isolate Hero clear-image presentation, not continue vertical Home testing. |
| **Build222 / 0.14.55** | Home vertical offscreen auto-advance isolation | **Target-device tested; perceived Home vertical hitching remains; A/B rejected as sufficient.** New automatic carousel transitions are blocked after Home scrolls away from top, while persistent backdrop/preload/Hero/horizontal interaction remain unchanged. Tested source `694221315c727ea055ea3b5ef7a9ea03a260fe80`; run/job `33101409110 / 98619779746`; artifact `9658757261`; IPA SHA-256 `8cf6d454bf7eec64207875e9c20a1bbc6b125578f11fb777bfdda4fa6b5c5bfe`; MinOS 15.0. Recording is 510×1108@30fps; obvious near-zero→jump points align with new swipe starts, so they are not counted as app hitches. User tactile result controls. Not stable. |
| **Build223 / 0.14.56** | Home vertical persistent-backdrop isolation | **Target-device tested; obvious vertical jitter remains; A/B rejected as sufficient; unintended Dock visual regression; not stable.** Immersive Home removed only the always-on full-screen `persistentCarouselBackdrop`; Hero, preload, normal auto-advance, horizontal interaction and P0/Frozen paths remained unchanged. User still felt obvious Home vertical jitter on iPhone 15 Pro Max / iOS 17.0. Dock source was unchanged, but its `.ultraThinMaterial` lost the full-screen backdrop behind it and became a visible gray/translucent strip; this is not an intentional Dock redesign and must not be retained. Tested source `af54d693d91303ea9bd201b5525e24f3e15ad931`; run/job `33110117601 / 98650408622`; artifact `9662245993`; IPA SHA-256 `a925714dceb138df7808079b5784f3337afe92245bd790c42c290eac82ccd73c`; MinOS 15.0. |
| **Build224 / 0.14.57** | Home vertical Hero artwork presentation isolation | **Target-device vertical-only diagnostic tested; visible Home inertial-scroll jitter remains; not a horizontal carousel verdict.** The build removed only current/target clear `carouselHeroArtwork` mounts while restoring the accepted persistent background/Dock and retaining preload, persistent blur, foreground, normal auto-advance and horizontal ownership. Run/job `33142773132 / 98757057369`; artifact `9674622017`; IPA SHA-256 `5b8c973cb5d34cf843f2649bda72f6a3f48ab5766c023b9c3e587f9eb4d9c845`; MinOS 15.0. On 2026-08-28 the user still saw Home vertical inertial jitter, but explicitly clarified that the active task is carousel optimization. Therefore Build224 closes the vertical-only detour; it neither accepts nor rejects horizontal carousel drag smoothness. Current direct carousel A/B returns to Build221. Not stable. |
| **Build225 / 0.14.58** | Home-carousel target-Hero drag presentation isolation | **Horizontal real-device tested; materially finer feel; diagnostic visual compromise; not stable.** Based on exact Build219 tested 120Hz source. Normal persistent crossfade retained; during active drag current clear Hero stays visible while target clear-Hero 1400px mount is deferred until drag ends. User reports this version feels noticeably finer on iPhone 15 Pro Max / iOS 17.0, establishing active-drag target-Hero first presentation as a material causal contributor. Tested source `350fd5d07ae2e77907bcf497deb819dfea6a28b1`; run/job `33149313932 / 98777365879`; artifact `9677114082`; IPA SHA-256 `221162e47de335b665cad6e0dd48aa82a8e27bb50cadcc24c2c6888d26db000a`; MinOS 15.0. |
| **Build226 / 0.14.59** | Home-carousel three-slot Hero residency | **Horizontal real-device tested; overall fairly close to EX and much better than original; direction validated; residual slow-drag title shimmer; not stable.** Keeps derived current+previous+next clear Heroes resident so either horizontal target is already presented before active drag; normal Hero/persistent crossfades, Build215 acquisition-relative motion, Build219 exact max-refresh and 0.28/0.48 release rules remain. User reports major overall hand-feel improvement but still wants refinement; second slow-drag recording shows visible large movie-title shimmer. Tested source `df1c9afce1dc96495dba16aa52e39254f23c7f65`; run/job `33151618930 / 98784687139`; artifact `9677979449`; IPA SHA-256 `881638aec2b31bef6b3b6b08bbd31c978eb5f4454683225ad4a212ccad99fe34`; MinOS 15.0. |
| **Build227 / 0.14.60** | Home-carousel foreground physical-pixel alignment A/B | **Horizontal real-device tested; title shimmer remains; pixel-rounding hypothesis rejected as sufficient; not stable.** Only final foreground-page X was rounded to the display pixel grid on top of Build226 residency. User still sees movie-title jitter, so this diagnostic must not be retained as the title fix. Tested source `7ac8de30b76192ee3cd9c9382edca74b9ff5e69d`; run/job `33153825917 / 98791806487`; artifact `9678871748`; IPA SHA-256 `b24d8abcd91f4faa74e06d8485bac3611725c561d9c99144c17def4b8ef26766`; MinOS 15.0. |
| **Carousel Build228 / 0.14.61** | Home-carousel release-tail max-refresh lifecycle | **Horizontal real-device tested; release tail accepted-for-now; whole carousel still Active.** Returns to Build226 presentation, removes Build227 pixel rounding and retains the exact device-max refresh request through interactive settle/cancel instead of ending it at finger release. User verdict: “差不多了，尾巴这里先这样吧”; do not continue release-tail easing/duration/velocity tuning without new evidence. Slow-drag title shimmer remains open. Branch `perf/home-carousel-release-refresh-build228`; tested source `bdf63c7562fcd1edc1d224872230e988ac462281`; run/job `33156739621 / 98801196041`; artifact `9679963420`; artifact SHA-256 `0b3a3a2b4d38f5f0bbff4a406e1523e161f7f6600065b9e5ee9e00cd075938bc`; IPA SHA-256 `cda90b62e3cabd3199e1cfbc1b2e1c77b8a84d023a7c7b9c8e2ff66ab9edcf44`; source ZIP SHA-256 `d91b014486e5fb1c5c9798b2b56bf45f0bad4f9e47f433a9f862c5fa586ecf68`; MinOS 15.0. **Parallel poster work also used Build228/0.14.61; use branch/source/artifact for attribution.** |
| **Carousel Build230 / 0.14.63** | Home-carousel persistent three-slot residency A/B | **Target-device slow-drag title-shimmer A/B tested; title shimmer remains; persistent residency rejected as sufficient title fix; whole Build230 overall-feel verdict incomplete; not stable.** Starts from cleaned carousel Build228 and pre-resides current+previous+next persistent blur surfaces with normal crossfade. User reports “慢拖文字还是会有抖动”, so this does not solve the known movie-title shimmer. No conclusion is fabricated for Build230 overall hand feel or post-settle behavior from this report. Tested source `6324bb2063bf1631b8b922abc8e11149bd7a86b0`; run/job `33167765310 / 98837170851`; artifact `9684378135`; IPA SHA-256 `6cea81f8e806ec159d9e811871076c18aa41fceb99b3c621516c490cfc339b4e`; MinOS 15.0. |
| **Carousel Build231 / 0.14.64** | Home-carousel foreground compositing A/B | **Target-device result materially positive but not complete: first test made movie-title text clearly steadier and not blurred; Build232 same rendering path later reproduced title jitter. Retain compositing as beneficial, not a full fix; not stable.** Returns to cleaned Build228 and adds exactly one `compositingGroup()` to each existing foreground page before unchanged opacity/X offset. Initial user verdict “这次文字明显稳下来了，也不糊” proves foreground child-layer compositing materially helps. Later Build232 user testing again saw title jitter, so do not freeze this as complete title stability. Tested source `d30092b8354553063c6d96b62a6f2f4387676601`; run/job `33169864030 / 98844082214`; artifact `9685231197`; IPA SHA-256 `b92eb47971c546cfe7044ebdbd94cc27a108f0febead32ec811d55e400df4571`; MinOS 15.0. |
| **Carousel Build232 / 0.14.65** | Home-carousel start-step timing/translation diagnostics | **Target-device diagnostic tested; immediate-vs-hold first-step split proven; title jitter still reproducible; diagnostic only, not stable.** Behavior unchanged from Build231/226/228. Uploaded log has 34 drags: 20 first visible steps 0.33–2.33pt, 14 first steps 8.00–13.67pt, zero in between, median acquisition→first-render 8.34ms. User reports immediate touch-and-drag has high probability of the coarse large-step pattern while hold-before-drag is almost always fine. Same session again exposes title jitter; 16/34 drags have display p95 ≈16.67ms and 5/34 have render average ≥20ms, supporting residual cadence investigation without exact per-jitter attribution. Tested source `de11d7483075daf7463faaa5519432478463a271`; run/job `33174155718 / 98858347691`; artifact `9686946353`; IPA SHA-256 `0366bffeda255f799621c0b0ffeb2780ef1adaa44c9d7b9f01ce14f0fe84b528`; MinOS 15.0. |
| **Carousel Build233 / 0.14.66** | Home-carousel acquisition-local first-frame A/B | **Target-device tested; acquisition-local path materially helps covered starts but overall fix insufficient; title subjectively less jittery; not stable.** 67 drags: 42 same-event acquisition-local starts have median first step 2.0pt and >=5pt 12/42 (28.6%); 25 fallback starts have median 8.33pt and >=5pt 16/25 (64%); overall >=5pt 28/67 (41.8%), >=2.5pt 32/67 (47.8%). User still perceives about half-or-more starts as large, so do not accept Build233 as final. Same session reports title less jittery; cadence distribution is cleaner than Build232 but not perfect. Tested source `4912234b579a2b8eeba7d5e7f5c6159248953efe`; run/job `33177534304 / 98869934770`; artifact `9688349642`; IPA SHA-256 `717ee926877e9867272f78790e06b3181b4e0f17d7d71d9494ca0540184a019b`; MinOS 15.0. |
| **Carousel Build234 / 0.14.67** | Home-carousel acquisition coalesced-decision diagnostics | **Target-device diagnostic tested; acquisition-event predecessor absence proven; measurement-only behavior retained; not stable.** 31 drags: `accepted` 20, `none` 11, `direction` 0, `zero` 0. Every `none` has `acq_coalesced_count=1`; those fallback starts have median first step 9.0pt, >=5pt 9/11 and >=8pt 7/11, versus accepted median 3.0pt and >=5pt 4/20. Accepted predecessor age is 4.17ms in 19/20. Conclusion: residual coarse fallback is same-event predecessor unavailability, not direction guard rejection. Tested source `528168da7c6b6df26bf1a907439becdb5cc4c980`; run/job `33189068688 / 98909569541`; artifact `9693038983`; artifact SHA-256 `d819f7a7ccd02bbc73f8201861c6b4a77b4627832d50e16de3f1e42f524786e8`; IPA SHA-256 `ddd8b884dd5095a3eb72e47b8a2726ac9bf32e9dc7000aafe9aeef596296a59c`; source ZIP SHA-256 `4c2ca8e92eae8449f6aa9e52228b78418c79924e35a5821c978a4046a71d58fb`; MinOS 15.0. |
| **Carousel Build236 / 0.14.69** | First post-acquisition real-baseline A/B | **Target-device materially positive; coarse-start rate sharply reduced and title jitter very slight; not stable.** 53 drags: overall >=5pt first step 10/53 (18.9%), >=8pt 3/53 (5.7%). Among 20 acquisition-event `none` starts, 16 find a real predecessor on the first post-acquisition event and have median first step 2.0pt with zero >=5pt; 4 remain `post_acq=none` and coarse (median 7.84pt; >=5pt 4/4). Display p95 ~8.34ms in 44/53 drags. Tested source `7811f34104daaea8734e72404bcb2fadb6fa37f7`; run/job `33193485825 / 98924631982`; artifact `9694861946`; IPA SHA-256 `8e248cb5834be4bcc261e3e1b63db3c334b805a4245aab56c74a5fe5951cd4c5`; MinOS 15.0. |
| **Carousel Build234 / 0.14.67** | Home-carousel acquisition coalesced-decision diagnostics | **Target-device diagnostic tested; acquisition-event predecessor absence proven; measurement-only behavior retained; not stable.** 31 drags: `accepted` 20, `none` 11, `direction` 0, `zero` 0. Every `none` has `acq_coalesced_count=1`; those fallback starts have median first step 9.0pt, >=5pt 9/11 and >=8pt 7/11, versus accepted median 3.0pt and >=5pt 4/20. Accepted predecessor age is 4.17ms in 19/20. Conclusion: residual coarse fallback is same-event predecessor unavailability, not direction guard rejection. Tested source `528168da7c6b6df26bf1a907439becdb5cc4c980`; run/job `33189068688 / 98909569541`; artifact `9693038983`; artifact SHA-256 `d819f7a7ccd02bbc73f8201861c6b4a77b4627832d50e16de3f1e42f524786e8`; IPA SHA-256 `ddd8b884dd5095a3eb72e47b8a2726ac9bf32e9dc7000aafe9aeef596296a59c`; source ZIP SHA-256 `4c2ca8e92eae8449f6aa9e52228b78418c79924e35a5821c978a4046a71d58fb`; MinOS 15.0. |
| **Carousel Build236 / 0.14.69** | First post-acquisition real-predecessor A/B for one-sample acquisition events | **CI/IPA verified; target-device pending; not stable.** Build234 proved every residual fallback was acquisition `none` with `acq_coalesced_count=1`. Build236 preserves acquisition-accepted Build233 behavior and only for `none/count=1` checks the first post-acquisition UIEvent for a real coalesced predecessor after acquisition; if direction-compatible it becomes the render baseline once while the current delivered touch is published, then ordinary delivered-touch ownership resumes immediately. No timer/interpolation/step cap/easing/second owner. Build231 compositing, Build226 Hero residency, Build228 settle high-refresh and 0.28/0.48 release rules retained. Tested source `7811f34104daaea8734e72404bcb2fadb6fa37f7`; run/job `33193485825 / 98924631982`; artifact `9694861946`; artifact SHA-256 `3a45d3400ac396fbc47a38ec6974e8983d90e9a949c0ce37bf68f8e9d7051bd0`; IPA SHA-256 `8e248cb5834be4bcc261e3e1b63db3c334b805a4245aab56c74a5fe5951cd4c5`; source ZIP SHA-256 `256fa108bd8823e9f699036d8e85009b763e5b0bd11e5d357c8c352e0360f454`; MinOS 15.0. |
| **Carousel Build237 / 0.14.70** | Short-fling gate + persistent white-flash correction | **CI/IPA verified; target-device pending; not stable.** Keeps the accepted/frozen-for-current-phase Build236/231/226/228 foundation. Only predicted-distance fling gate changes `0.48×width → 0.24×width` while actual-progress threshold remains 0.28; persistent source-over crossfade now keeps outgoing fully opaque and fades incoming over it so light `systemBackground` cannot leak through the midpoint. Tested source `185df6a9e53387b095f35a60fa5d01b44f5af3db`; run/job `33202505078 / 98955194172`; artifact `9698408945`; artifact SHA-256 `6c9eb827653eab83d4eb146f602e742d0b124bd8697cb964d7164c188b72b7cd`; IPA SHA-256 `aadc7d05d72d059eadfd166647127acdab0685cc259458795b562b4f1bbb28d9`; source ZIP SHA-256 `022cfe9fab14aba0f902b413ecf903e5e8c807e6be90a82dfd8c6b094c7d75a7`; MinOS 15.0. |
| **Carousel Build238 / 0.14.71** | Release-intent measurement only | **Target-device diagnostic tested; velocity-intent hypothesis strongly validated; behavior itself unchanged.** 19 intended quick flicks show `abs(last_move_delivered_velocity_x)` ≈1139.8–2239.8 pt/s while 9 short slow drags are ≈0–160 pt/s; coalesced velocity agrees. End velocity overlaps and predicted extra travel is often absent or only ~6–13.3pt for obvious flicks, rejecting those as sole signals. Tested source `780283bc722e39564240d996ca3c522bc61c6066`; run/job `33204499623 / 98961981208`; artifact `9699150399`; artifact SHA-256 `59baa8223ba6d652cde77cf7e6af286545b12ef6a762df110bc20d18f6524cf3`; IPA SHA-256 `3539fd2f8c83c56838242a69350c473bd0088a65c273a5a0c0b4f3676878efd4`; MinOS 15.0. |
| **Carousel Build239 / 0.14.72** | Direction-aware velocity fling + accepted presentation foundation | **Target-device release intent accepted; late settle matched to EX; whole-flick handoff continuity remains a narrow open question.** Keeps 0.28 slow-drag progress commit, removes rejected predicted-total-distance gate, commits direction-aware latest-delivered velocity at >=600 pt/s, and retains Build237 white-flash fix plus Build236/231/226/228 foundation. User first accepted the fling behavior (“没问题了”); matched 30fps tracking then showed materially similar late ease-out decay to EX. Later tactile comparison reports EX still feels more effortless over the whole single flick. Exact source uses release velocity only as a binary gate and then always runs a fixed 0.22s ease-out, so only release-handoff momentum continuity is reopened; do not retune accepted gate/tail without new evidence. Tested source `ed4e59c2a0e2fac3979d84dad756299659b15387`; run/job `33208503351 / 98975620229`; artifact `9700721145`; IPA SHA-256 `b11992aa6b4c87df87600ec38143798aece6df231507a6d13357856318f6196d`; MinOS 15.0. |
| **Carousel Build240 / 0.14.73** | Release-handoff momentum continuity diagnostics only | **CI/IPA verified; target-device diagnostic pending; runtime behavior unchanged from accepted Build239 foundation.** Logs committed-release directional velocity, actual/visual progress and the first post-release animated-progress/CADisplayLink samples so derivative continuity can be measured before any behavior patch. Keeps 0.28 slow-drag commit, >=600 pt/s direction-aware fling gate, Build237/236/231/226/228 contracts and fixed 0.22s/0.18s tail unchanged; no timer/interpolator/spring/second owner. Tested source `0f894953a70e11712a82d28b4e8292979826575c`; run/job `33235107680 / 99054618665`; artifact `9709708870` (`sha256:62c9ee71324f0a4a22e3ce3b3ff8b7fdcb6abdb370980c1a89aba8c9bce69fc7`); IPA SHA-256 `a6afbd3706fc6227f9e09749c32680e6c967ea7b2acffd6f58c444a9ab0d5b15`; source ZIP SHA-256 `e9786d8d068e79f62f39464aa69ae6dae696ef223ab31f0b8184a5202eec513c`; MinOS 15.0. |
| **Carousel Build241 / 0.14.74** | Easier direction-aware fling trigger from exact Build239 behavior baseline | **Target-device behavior was previously accepted, then reopened by stronger 2026-08-30 stress evidence; merged baseline, not stable/frozen.** User explicitly chose Build239 behavior and changed only the fling gate `600 → 500 pt/s`; 0.28 slow-drag commit, 0.22s/0.18s settle and Build237/236/231/226/228 contracts remain. Exact tested source `997a93a5f2c3c6544908ad112df5e714d2538e65`; run/job `33247149430 / 99086484795`; artifact `9713225510` (`sha256:3ea36257c97b4a7947bb46e9aa1e0a5d2dcbd1a96ddf1977d58e0cada180525f`); IPA SHA-256 `338cd80de1671da4fedabdeecd9a001e98074dd119dcf331fda548b420f1f236`; source ZIP SHA-256 `b1e37c1c79f08552ad9de6819838cbca1b5b95cd4cc8a95c5b3ebf08a73ab664`; MinOS 15.0. Latest confirmed Build241 recordings expose unstable rapid-swipe FPS and horizontal→vertical ownership loss, motivating Build262. |
| **Build228 / 0.14.61** | Poster image-adoption + pagination timing diagnostics | **Target-device diagnostic tested; still hitches, sometimes strongly; not a fix.** Exact source `20f0edaf30c3c9161a79f64fd29dbc79c199473e`; run/job `33154400536 / 98793625194`; artifact `9679088491`; MinOS 15.0. Latest log captures a 55.1 ms real grid dragging frame. Latest image publish/Combine→UIKit adoption measured 0.0 ms and pagination apply 0.3 ms, while synchronous Library presentation-snapshot persistence took 39.7 ms and completed ~8 ms before the hitch. This directly implicates persistence in this severe pagination-adjacent sample, but Build212 predates Build213 so persistence is not the universal historical root cause. |
| **Build229 / 0.14.62** | Library presentation snapshot persistence off MainActor | **CI/IPA verified and target-device tested; overall Library 3×3 hitching remains; not stable.** Exact source `f5e3e3eb144578c863b172e3bd3a1aa13e5c2177`; run/job `33156266871 / 98799654927`; artifact `9679803873`; IPA SHA-256 `49efcb8766cc9414a3f35e3d8fe75a04eaf6adf2ba86a40f526a5e53c40acd4c`; MinOS 15.0. Latest target-device evidence captures a 77.2 ms Library-grid moving hitch about 7.3 s after page apply/snapshot completion and ~0.77 s after image publish, so off-main persistence is not sufficient to solve the broader hitch family and those events are not direct triggers for this sample. Pagination-specific improvement remains unproven. Poster branch later materialized `deba1534e55bfc73f4d3cf43f2682c854a04cb39` as invalid/colliding 0.14.66/Build233 diagnostics; that identity was subsequently retired and reallocated to the unique Build243 diagnostic candidate recorded in the next row. |
| **Build243 / 0.14.76** | Poster background-image-work diagnostics | **CI/IPA verified; target-device diagnostic pending; no smoothness fix claimed; not stable.** Exact source `53a704c2ed752adf023ea3c7f08d7f90f7559133`; exact Build229→243 four-path scope + poster checker passed; Xcode 16.4 run/job `33300155220 / 99226651825` success. Artifact `OnePlayer-0.14.76-build243-poster-background-work-diagnostics`, ID `9728697893`, digest `sha256:33ebe84f2864ba4494c4b6c164f77730d2eb383a969e2e0d9c98aac8cc0b9cf1`; IPA SHA-256 `f8a7d792f70c970314080a56ef78a9f5734697e7a27373bf67b44dd3d4871d75`; source ZIP SHA-256 `641a720cae3550b160fce7cf223d0ec397df0c3aac6041b0a17f60c8ee37c2f9`; bundle `com.embyplayerlab.app`, MinOS 15.0 independently verified. Adds measurement only for active poster disk-read / detached-decode / network / cache-write stages in existing hitch timing; runtime image/scroll policy unchanged. |
| **Build257 / 0.14.90** | Home auto-advance vs vertical-inertia gate | **CI/IPA verified; target-device pending; not stable.** New Build243 real-device A/B repeatedly shows a very large Home hitch when carousel auto-advance starts during active vertical inertia, while carousel-off removes the large hitch but leaves mild baseline jitter. Current-main Build257 exact source `a524d7a56c308a2ed52c5a41b55d061050176e8b` reuses the existing real Home `UIScrollView` and only returns from a due auto-advance tick while `isDragging || isDecelerating`; no new timer/duplicate motion state and no Build241 manual interaction/presentation change. Run/job `33301432703 / 99230262134`; artifact `9729097648` (`sha256:a3d02846d772d940ace45310aa56b094c2f90a18d18ad5912e167f1fcb58cd0a`); IPA SHA-256 `2223cb989201d6477069740faef4c0ed42d9e1937df4a0561d15b0de289a1018`; source ZIP SHA-256 `8b50dac32663484e8e7486b3381b2e781a88b15fd03e613275913673a50276d9`; MinOS 15.0. |

| **Carousel Build242 / 0.14.75** | Whole-carousel Home-performance isolation A/B | **Target-device diagnostic tested; Home-scroll difference felt small/not obvious; diagnostic-only and explicitly not a product baseline.** Exact Build241 tested source was the base. Build242 deliberately disabled the normal carousel presentation/interaction stack while preserving the Home vertical footprint to test whether the whole carousel was a major Home-wide vertical bottleneck. User result: “感觉区别不大”, materially weakening that hypothesis. The user later reiterated that Build242 was a test version whose diagnostic modifications broke normal carousel behavior; never inherit Build242 as the final carousel implementation. Tested source `3bf163d2c443520c0f22bba9b49902928fa36ca8`; run/job `33247895006 / 99088437546`; artifact `9713463258` (`sha256:40fbfb22bcb6461dd358cf72b6fd57fea934ca71acfd478978ffb29b0ebb119f`); IPA SHA-256 `9c08ed8965e5e9e99bf4a17768cc8d124209c3b42e9e48d8d78fba720415e5d4`; source ZIP SHA-256 `6baaec3cb1bacb14842316baa0b2e4615477f1769ed46f4f7f64bb7287a46d52`; MinOS 15.0. |

| **Build273 / 0.15.6** | Library-only native UICollectionView 3×3 A/B + legal-bound reverse diagnostics | **Target-device tested; native collection insufficient; interior reverse not captured; not stable.** Exact source `6ff8b1fdefeb7fbe848d05414661a95c88e8ffb8`; PR #279; run/job `33333053285 / 99314989586`; artifact `9738238291`; IPA SHA `743d94de7cfe7da0c02cb0a04c35e0e1451096f3691b53025eb02b174ec3e680`; MinOS 15.0. `OnePlayer-App-1788122398.log`: user still saw several twitch events. Long `60→360` native session 51.12 s at 118.72 Hz; all 30 reverse >=1 pt are outside legal top bound during bounce, max 3.00 pt; fixed `120→120` 118.00 Hz with reverse=0. Next diagnostic is per-frame gap attribution against `insertItems` and same-ID visible hosting-root reconfiguration; no scroll-physics/container change yet. |

## Current accepted baseline

- Product: **OnePlayer 0.14.49 / Build216**
- canonical branch: `main` after PR #261 integration
- final merge PR: `#261`
- final merge commit: `f5ad126b7b47e9713b1949780a6507fb3f0ca50f`
- tested product / dedicated CI source: `dc00cac9f35ee4a3b950e4bb030bb324baf90b18`
- CI run/job: `33064051545 / 98489652724` — success
- artifact: `OnePlayer-0.14.49-build216-detail-range-inertia`; ID `9643031850`
- artifact digest: `sha256:9cbccc582be719b2daa10077293da2951f0cbce8016625128de8ef9d85b27f48`
- IPA SHA-256: `e3054a53398e1df48134fecd8c30671e10ecaa8a93df5483936adcf10e055075`
- source ZIP SHA-256: `98e1b5b52ebe5d8b2e3fbf754d3dfb18d0ea082fd77bcd9e6905b0bcb56e0f6f`
- Deployment Target / built MinOS: iOS 15.0
- target device: iPhone 15 Pro Max / iOS 17.0
- target-device result: **accepted by the user on 2026-08-27**
- evidence: **Code written / CI passed / IPA produced / real-device accepted / stable/frozen for the detail episode-range inertia contract / merged to main**

Build216 inherits the accepted/frozen player, PiP, transport, playback-cache, episode-ordering, Build182 detail-presentation, Build191 detail-selection, Build195 player-episode and Build199 server-management contracts. Its new stable scope is only interruption of active detail episode-row deceleration before a range jump. Home-carousel and poster-scroll remain independent Active lines.

## Home-carousel evidence

### Build198 retained input foundation

- one UIKit interaction surface owns begin/move/end/cancel;
- vertical acquisition yields to Home `UIScrollView`;
- actual touch drives raw render progress; predicted touch is release-only;
- 0.5pt axis acquisition, 0.28 commit, 0.48×width predicted-distance gate and settle timings remain unchanged;
- no second SwiftUI drag/release owner.

Build198 successful CI source `a569155d443433a5f4769dfe506fec6ab9bdd0e6`; run/job `32987054824` / `98235720724`; artifact ID `9613342337`; IPA SHA-256 `9432928b31898c0c3f05e7e0affb6949c23339a37edd8f14c1d47343ff31f3d8`.

Target-device result: lifecycle/settle/reversal okay, minimum/subtle movement still too coarse versus EX. Input architecture retained.

### Build200 rejected visual mapping

- source: `4d3afe36768b7749d9d0bd0081725f3d947b2099`
- run/job: `32991758526` / `98250719262`
- artifact ID: `9614995121`
- IPA SHA-256: `509395ca7fb847548110c22ec0a3f6b005e6b3f4521f911eb9b3f765ca6d1b1a`
- real-device: rejected because foreground became fixed and no longer slid horizontally.

### Build201 partially positive real-device result

- tested source: `e61070146d91bac45400e3f95e28eead756faa81`
- run/job: `32993286519` / `98255950676`
- artifact ID: `9615585817`
- IPA SHA-256: `d889f2c36b3f617b429e4f39ba54d39d7f2826a058a2d4f874bc7a9bb574db58`
- horizontal foreground travel `0.15 × Hero width`, linear opacity blend.
- target-device result: **“有点那种感觉了”**, but total travel was insufficient.

### Build203 real-device result

- identity: **0.14.36 / 203**
- tested source: `69beee45b93dc11c7c5be2ee4b81a5a0157f2653`
- durable cleanup head: `edafd5d784cfacdcf8c451fad93535a55fb880fb`
- run/job: `32995898318` / `98264917294` — success
- artifact ID: `9616576496`
- IPA SHA-256: `cee7241b73c4dc38efb6593c3d6ec9f54981f8e5a609be78a491b869df685226`
- target-device: 30% total travel remained insufficient and the larger raw-linear mapping exposed coarse first displacement/jitter again.
- conclusion: visual spatial mapping, not the single UIKit lifecycle owner, remained the problem.

### Build204 carousel collision — retired

A carousel `0.14.37 / Build204` package was produced briefly, but the poster-scroll task already owned Build204. The carousel Build204 package is retired and must not be used for attribution.

### Build205 real-device result

- identity: **0.14.38 / 205**
- tested source: `e5f2e7b4135eca333d5dda24545f19ee8d0be439`
- durable cleanup head: `70d6cca676911e656591aae6b342c771cc92b9fe`
- run/job: `32998533448` / `98273968966` — success
- artifact ID: `9617634710`
- IPA SHA-256: `fe4a81ebee9d330526c108edf2ab4652632ae5b204719864e0b5dee486086479`
- 80% foreground travel; foreground/backdrop opacity and spatial offset both used clamped `progress²`.
- target-device: start over-restrained and whole-range nonlinear tail felt unnatural; curve rejected as final.

### Build207 real-device result — structural overlap discovered

- identity: **0.14.40 / 207**
- branch: `perf/home-carousel-soft-start-linear-tail-build207`
- tested source: `06936503a6c382d1d39d3cdd52f23bfe2058901e`
- durable cleanup head: `7044ca68c7082cd055a7e4ce42dda6f00fe29674`
- run/job: `33000526138` / `98280846494` — success
- artifact ID: `9618484884`
- IPA SHA-256: `bbd7c9c22c2a79a89f41e0d94db16023cf7cd2a720ffeb3c4f31cb9066a15a21`
- foreground page travel remained `0.80 × Hero width`; visual progress was `progress * (1 - 0.60 * (1-progress)^6)`.
- latest target-device screenshots on 2026-08-27 show two direct failures: earliest visible displacement is still too long, and adjacent foreground Logo/title/rating/overview content overlaps while EX shows a clear gap.
- source explains the overlap deterministically: each `carouselHeroForeground` is a full-width page, but outgoing/incoming page centers were kept only `0.80 × width` apart, forcing 20% page-frame overlap at every transition progress.
- existing page content width is `width - 56`; full-width page centers therefore imply ~56pt content separation.
- evidence: **Code written / CI passed / IPA produced+verified / real-device tested / foreground layout rejected / not stable.**

### Build208 current carousel candidate

- identity: **0.14.41 / 208**
- branch: `perf/home-carousel-page-slots-build208`
- base: Build207 durable cleanup head `7044ca68c7082cd055a7e4ce42dda6f00fe29674`
- tested source: **`2ad089f0ea8b4b6827257bb3a91a67c2d3748e5f`**
- durable cleanup head: **`51c366b6840d77c818eae20e1f3f43c0dbd75c72`**
- tested-source → cleanup-head delta: temporary Build208 workflow deletion only; product/runtime source unchanged.
- runtime delta is limited to `Sources/Core/AppIdentity.swift` + `Sources/UI/EmbyHomeCarouselStateV3.swift`.
- foreground page step is **`pageStep = width`**.
- outgoing offset = `-direction × visualProgress × pageStep`; incoming offset = `direction × (1 - visualProgress) × pageStep`.
- page-center separation is exactly one Hero width for all progress values; existing `contentWidth = width - 56` gives ~56pt constant content separation.
- earliest visual attenuation is clamped `progress * (1 - 0.85 * (1-progress)^6)`; this reduces only the first few-percent displacement versus Build207 while mid/late progress rapidly returns near linear and endpoint/tail remain natural.
- foreground/backdrop opacity uses the same visual progress.
- raw `transitionProgress`, 0.28 commit, 0.48×width predicted gate, reversal/settle ownership and first↔last modulo lookup are unchanged.
- source/Frozen guard: PASS.
- run/job: **`33004390654` / `98294100402` — success**.
- artifact: `OnePlayer-0.14.41-build208-home-carousel-page-slots`.
- artifact ID: **`9620046266`**.
- artifact digest / independently downloaded ZIP SHA-256: **`4ace3db785c131b987bfd9e18dc931e1bdeaf9f7528d85b8807214b45774afbb`**.
- IPA SHA-256: **`24f47ac5cd5685f6eea85b1c3a4fad2841d81f6169a90cd0629bea85a2072308`**.
- source ZIP SHA-256: **`807d03947c0d087ddc54f295e63fdabc37ac0ddfbe0e0f03da4477eb750e95ee`**.
- independent validation: artifact digest exact match; IPA/source hashes match embedded checksums; IPA `unzip -t` passed; bundle `com.embyplayerlab.app`; version/build `0.14.41 (208)`; OnePlayer primary/alternate icons; `MinimumOSVersion=15.0`; source snapshot confirms `pageStep = width`, `0.85` mapping and existing `width - 56` content width.
- evidence: **Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device pending / not stable.**

### Build215 current carousel candidate

- identity **0.14.48 / Build215**; branch `perf/home-carousel-acquisition-relative-build215`.
- tested source **`d22634ece2f29eba2e60de01182bf15d4ba554a7`**; cleanup head **`01a13615fc056fd3b13296d98abfaa7a6aa2b46d`** with workflow deletion only.
- render baseline is horizontal acquisition; post-acquisition render is `currentTranslation - acquisitionTranslation`.
- touch-down distance retains 0.28 commit / 0.48×width predicted release, including one-sample fast release.
- foreground transition pages stay opaque; backdrop crossfade is separate; full-width `pageStep = width` retained.
- exact scope/Frozen guard passed; no Player/MPV/PiP/Transport/Cache/Session changes.
- run/job **`33058337107 / 98470624555` — success**; artifact ID **`9640692378`**, digest **`sha256:31a054244bcfbeb39cc5db663aa7580cb4cc742fe88ca998ce9c9ba7a01e2939`**.
- IPA SHA-256 **`6551a5e9e8a28a66bd4f105118387e8fc9378b72bd47778897f013b411c06c97`**; source ZIP SHA-256 **`00d2a0aba071dbbce3554d31dba64f0caa70c22b6e067dedeee0bb3b22ebd694`**.
- independent validation passed for artifact digest, embedded hashes, IPA archive, identity, MinOS 15.0 and exact source contracts.
- carousel Build214 / 0.14.47 also passed CI/IPA but was retired before distribution due identity collision; never use it for carousel attribution.
- evidence **Code written ✅ / scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device pending / not stable.**

## Poster-scroll evidence

### Build202 — real-device rejected

- task: `DEV-poster-grid-smoothness`
- branch / draft PR: `perf/poster-grid-smoothness` / #259
- identity: **0.14.35 / 202**
- tested source: `a05dd3424bb499e46dc0834e69cf55654fb7733e`
- durable cleanup head: `6e16865d1589a953f58bf65885d9fb01ff6374e0`
- run/job: `32993726508` / `98257448257` — success
- artifact ID: `9615751921`
- IPA SHA-256: `f6e3a30206acf2cfd877df74f41aa13f1575e1614407eff79466884f9ec51279`
- target-device recording confirms stop-frame/catch-up hitch remains.

### Build204 — real-device rejected

- identity: **0.14.37 / 204**; canonical Build204 owner.
- exact CI source: `e6a97b5083691ed10795a402edc0fd30f996cffc`; durable cleanup head `170778c3934a280d9b539fb45f0bfef673687825`.
- run/job `32996847597` / `98268250117` — success; artifact ID `9617026984`; IPA SHA-256 `b4ba266086674f95a09ef92500c78926b4bc9cfd022c637075985cd55c598130`.
- target-device: visible hitching remains on both Home poster-heavy scrolling and library 3×3 pages.
- conclusion: no-op image-subscriber removal and warm-cache first-body seeding are retained reductions but are not sufficient to explain/fix the cross-page hitch.

### Build206 — target-device diagnostic capture obtained

- identity: **0.14.39 / 206**; poster-scroll owns this identity.
- exact diagnostic source: **`351c62694ac25404c2bd4eb36a03314dd58ffed2`**.
- runtime diagnostic scope: shared poster path only; one `CADisplayLink` while poster cells are visible, logging `PosterScrollHitch` only for display gaps ≥30 ms, with nearest cell-appear, image-commit and grid-load-ahead timestamps.
- no change to scroll mechanics, lazy-container semantics, image request sizing/caching policy, NavigationLink behavior, carousel input/state owner, Player/MPV/PiP/Transport/Cache/Session.
- run/job: **`33000992493` / `98282482225` — success**; artifact ID **`9618646972`**.
- IPA SHA-256: **`ee981133777c316305c4890aaa1a99b8906792783cad1496d880bf786611e18c`**.
- target-device App log contains **17** `PosterScrollHitch` records: row 7 / grid 10; grid max 118.7 ms.
- all 17 have `load_ahead=none`; 8/10 grid records happened >1 s after both most recent recorded cell appearance and image commit.
- exact-source limitation: diagnostics are not active-scroll/motion gated, so captured gaps cannot all be classified as proven user-visible scrolling stalls. Motion-aware correlation remains required.
- evidence: **Code written / CI passed / IPA produced+verified / target-device diagnostic capture / root-cause attribution incomplete / not stable.**

### Build209 — current motion-aware diagnostic candidate

- identity: **0.14.42 / 209**; poster-scroll owns this identity.
- Build206 base: `351c62694ac25404c2bd4eb36a03314dd58ffed2`.
- exact CI source: **`e95d73b75938ad92f2c4d7f06a3ba2d441bb92f4`**.
- exact Build206→Build209 delta is six files only: AppIdentity, Home scroll probe, shared grid probe, shared diagnostics, Build209 changelog and poster checker.
- runtime remains diagnostic-only: Home/shared 3-column routes resolve the real ancestor vertical non-paging `UIScrollView`; the existing single poster `CADisplayLink` samples `contentOffset.y`; `PosterScrollHitch` is emitted only for **gap ≥30 ms AND `delta_y != 0`**.
- each hitch adds `scroll_route`, `phase=dragging/decelerating/moving`, `offset_y`, `delta_y`, `velocity_y`, while retaining cell/image/load-ahead timing.
- no second display link, KVO polling, timer, retry/fallback, scroll-physics, image-policy, NavigationLink, carousel-owner or P0 playback/transport/cache/session change.
- Build208 / 0.14.41 is owned by Home-carousel; a poster package briefly built with that identity was retired before distribution and is not valid for poster attribution.
- run/job: **`33006881819` / `98302809290` — success**.
- artifact: `OnePlayer-0.14.42-build209-poster-motion-diagnostics`; artifact ID **`9621031556`**.
- artifact digest / independently downloaded artifact ZIP SHA-256: **`dc9d9aec4b266543fd894f8e6cdc6a5e811f88113c4a5fc7e1da83f1545dae7e`**.
- IPA SHA-256: **`85f6649352718a8cac2b269ee090e19bfbb173881845462ed1493e1d90129572`**.
- source ZIP SHA-256: **`4437f8e1c7af4f28ac4682c6eea05cbfdd86f2f2a806a793ec81f91353cb716b`**.
- independent validation: embedded checksums match; IPA `unzip -t` passed; bundle `com.embyplayerlab.app`; OnePlayer `0.14.42 (209)`; `MinimumOSVersion=15.0`; source snapshot confirms the motion gate, Home/grid probes, exactly one poster `CADisplayLink`, and no retired poster Build208 changelog.
- target-device App-log capture: **pending**.
- evidence: **Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device diagnostic pending / performance fix not claimed / not stable.**

### Build210 — target-device multi-owner diagnostic result

- exact source `9d8fd6a62e6e7d281d4fae5ab8442754a6362f47`; run/job `33009322419 / 98311176681`; artifact ID `9621956333`; IPA SHA-256 `813811fe0301cd8c942511e3e7786c184a80966960bf029ed3366d6edaa23701`.
- latest target-device log `OnePlayer-App-1787807430.log` contains five motion-gated hitches: Home 68.9 / 34.9 / 74.5 / 39.8 ms and grid 70.4 ms.
- all four Home entries are `phase=dragging` and are only 6.2–11.0 ms after the latest shared image commit, while last cell appearance is 6.6–14.3 s old.
- grid attribution now works: `scroll_route=grid registered_scrolls=2 moving_scrolls=1`. Its only entry is `phase=moving`, `delta_y=0.33`, velocity 0, image age 855.4 ms and cell age 1151.0 ms, so it is not yet a proven user-drag grid hitch.
- exact source confirms image decode is detached; image commit timestamp follows MainActor `@Published image` assignment. Home carousel image callback then synchronously runs Core Image contrast analysis and may update root Home state. This is the strongest Home lead, but shared image events lack source identity and the active Home-carousel task owns the likely callback/state files.
- evidence: **real-device diagnostic tested / multi-owner attribution validated / Home image correlation strong but not yet causal / grid user-drag attribution still incomplete / performance root cause unresolved / not stable.**

## Accepted foundation evidence

- Build176: source-owned episode-session replacement + trusted natural-end auto-next; merged PR #253.
- Build178: Emby `/Shows/{SeriesId}/Episodes` canonical order; merged PR #254.
- Build182: detail high-rate scroll isolation + presentation-only persistent cache; real-device accepted/frozen.
- Build184: detail visual hierarchy; merged PR #255.
- Build191: select-only detail episode browsing/navigation; merged PR #257.
- Build195: SeasonId-first player grouping + lazy large episode row; merged PR #258.
- Build199: Add/Edit Emby modern editor, same-server route selection, cached-first startup, retained password + optional iCloud Keychain sync; merged PR #256.
- Build213: Favorites + Library 7-tab persistent presentation warm cache; dedicated MPV CI/IPA passed and target-device accepted; merged PR #260 at `2303505ad4403182f5315d33c54f402903c809d2`.

## Maintenance rule

Update this index when a build materially changes architectural understanding, becomes a real-device reference point, rejects/freezes a direction, or becomes the accepted baseline. Never treat CI success or IPA production as real-device acceptance.

### Build212 — source-aware poster diagnostic candidate

- identity: **0.14.45 / 212**
- exact source: **`4f0a89ab026cd2103f66e5854a1f352d34852e45`**
- Build211 / 0.14.44 is owned by the independent Home-carousel task; poster Build211 was retired before distribution.
- exact Build210→212 delta: `AppIdentity.swift`, `EmbySharedImageAndNavigation.swift`, Build212 changelog, poster checker only.
- retains one shared motion-gated multi-owner poster `CADisplayLink`; no scroll/image/navigation policy change.
- adds image item/type/MaxWidth, `source=memory/disk/network`, `role=display/callback`, callback duration and Core Image contrast-render duration to hitch correlation.
- run/job: **`33045869471 / 98429601490` — success**
- artifact: `OnePlayer-0.14.45-build212-poster-source-aware-diagnostics`; ID **`9635696107`**
- artifact ZIP SHA-256: **`eb53a4b88564165b399edfd9085fcc888718cfa62141725d1f24cc539d598615`**
- IPA SHA-256: **`dcdec181dd16e9b3b666882de8347a76671c743ab8392aa27791d40599eec7a1`**
- source ZIP SHA-256: **`9a618698a71ba45074ae915d859afdf9173f312e989e9a646717ed8c6ba60459`**
- independent validation: GitHub digest exact match; embedded checksums match; IPA/source `unzip -t` passed; bundle `com.embyplayerlab.app`; OnePlayer `0.14.45 (212)`; primary/alternate icons present; `MinimumOSVersion=15.0`; MinOS audit PASS; source snapshot contains the expected diagnostic fields.
- evidence: **Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device diagnostic pending / performance fix not claimed / not stable.**


### Build212 target-device source-aware result

- log: `OnePlayer-App-1787813666.log`
- Home dragging: 5 hitches, 43.6–73.8 ms; `memory/callback/Primary/1400`; image age 8.3–12.2 ms; callback 1.0–3.2 ms; contrast 1.0–3.0 ms; cell age 7.3–21.9 s.
- Grid dragging: 11 hitches, 31.0–37.3 ms; `network/display/Primary/378`; image age 0.0–20.1 ms; cell age 118.8–177.8 ms.
- conclusion: Home callback/contrast computation is not large enough to explain the long frame; Home carousel image publish/presentation remains the lead. Grid drag hitch is independently tied to newly visible display-only poster publication. The one-universal-root-cause assumption is rejected.
- evidence: **real-device diagnostic tested / route split established / no runtime fix tested / not stable.**

### Build213 — Favorites + Library persistent page cache accepted

- identity: **0.14.46 / 213**
- task: `DEV-page-cache-optimization`; branch `perf/page-cache-optimization`; PR #260.
- exact tested product source: **`c8c238816c34ba3d8834ac37bdf7b234cd596458`**.
- product runtime scope: `Sources/Core/AppIdentity.swift`, `Sources/UI/EmbyPagePersistentCache.swift`, `Sources/UI/EmbyServerBrowseV3.swift`; no Player/MPV/PiP/UnifiedTransport/playback Session Cache/Home/shared-poster owner edits.
- persistent scope: Favorites + Library tabs 内容/建议/预告片/合集/类别/我的收藏/文件夹.
- lifecycle: restore valid disk presentation snapshot first → render warm content → existing page/tab entry live refresh → accepted fresh state replaces visible owner state → atomically persist that accepted snapshot.
- failed refresh does not erase a valid visible/disk snapshot.
- necessary Library pagination frontier (`nextStartIndex` / `hasMore` / restored seen IDs) is restored with cached content.
- Library `sortBy` is not persisted by page cache; `selectedTab`, scroll restoration, Favorites root-session retention and Search/Genre/Person persistence remain outside this milestone.
- cache identity is `baseURL + userId + scope (+ library.id)`: safely isolated; a later same-server route change may cause a benign warm-cache miss rather than cross-route data leakage.
- standard MPV run/job: **`33052588518` / `98451457434` — success**.
- artifact: `OnePlayer-0.14.46-build213-page-cache`; ID **`9638292306`**; digest **`sha256:e65a3ce06d53cc499a84f86a9cd32978824f1de4899bf2afe310727a2566731c`**.
- IPA SHA-256: **`a8c2d1753db33f41a5b07ce22c4706eb102cf5d905f1aaeee8f54d689b176fc8`**.
- source ZIP SHA-256: **`3a59bc8fb8dc55a83abd8adf76841db47640df8944f39920969b06bd55927051`**.
- built `MinimumOSVersion=15.0`; target device iPhone 15 Pro Max / iOS 17.0.
- target-device result: **user reported “验收通过” on 2026-08-27**.
- evidence: **Code written ✅ / CI passed ✅ / IPA produced ✅ / real-device accepted ✅ / first milestone stable ✅ / merged to main ✅**.


## Build242 diagnostic-only result — 2026-08-29

- Identity: OnePlayer 0.14.75 / Build242; exact source `3bf163d2c443520c0f22bba9b49902928fa36ca8`; run/job `33247895006 / 99088437546`; artifact `9713463258`; IPA SHA-256 `9c08ed8965e5e9e99bf4a17768cc8d124209c3b42e9e48d8d78fba720415e5d4`; MinOS 15.0.
- Purpose: whole-carousel Home-performance attribution by intentionally disabling persistent backdrop, Hero carousel rendering/interaction, preload, auto-advance and carousel-owned Hero scroll updates.
- Target-device result: user reports Home vertical-scroll difference versus Build241 feels small / not obvious.
- Final classification: **real-device diagnostic tested only; not a product candidate, not stable, not an inheritance baseline.** The user explicitly reports the diagnostic modifications made Build242 unsuitable/broken as normal carousel behavior. Never supersede Build241 with Build242.
- Retained conclusion only: disabling the whole carousel presentation stack did not produce a clear Home vertical-scroll improvement, so the whole carousel stack is not demonstrated to be a major Home-wide performance bottleneck.

## Home-carousel final main integration — 2026-08-29

- Final real-device behavior authority: **Build241 / OnePlayer 0.14.74**.
- Clean integration PR: **#262**, merged commit `75d9f53d0984ee7f32e7e3fa02cd9bf8794b56e3`.
- Integration scope: exactly five Build241 runtime files, no Build242 diagnostic behavior and no wholesale merge of the diverged historical Build241 branch.
- Exact final main blob identities: cadence `c5ec51991d9a629cfb39785efeb597f3c51375ef`; interaction `144be65ba3fa5618d39591c5f67747024dc5ff0c`; state `e18fc8724170f2a7e613ac93beedf54c3b8d47e8`; core `c7900bae5e608ae46c0cd476c1f08999be9baf0b`; Hero `ab2ab5d80a59e174622dca0006c0f3aad4111a54`.
- Independent integration compile run/job: `33248884259 / 99090990039` — success; exact blob/contract checks passed; Release generic-iOS compile passed; built MinOS 15.0.
- Evidence discipline: integration CI does not create a new target-device acceptance identity. Build241 itself supplies the real-device acceptance; the carousel module is now stable/frozen.


### Build247 / 0.14.80 — Search startup recommendation warm candidate

- Build246 target-device evidence: Dock still rises with keyboard; recommendation entry/later posters remain slow; returned-type whitelist must be explicit; recommendation load-more still twitches. Build246 is real-device tested and rejected as final.
- exact CI product source: `5f693d82041bbb59d3fe481aa708b22a5feda42d`.
- Search-only architecture: server-root owns the visible Search Dock; returned recommendation items are hard-filtered to `Movie`/`Series`; app startup restore begins one bounded 60-item recommendation/poster warm; Search consumes the same task; recommendation grid is fixed and performs no active-scroll load-more. Existing persistent image disk cache and decoded pool remain the cache authorities.
- run/job: `33258792907 / 99117036605` — success.
- artifact: `OnePlayer-0.14.80-Build247-Search`; ID `9716657082`; digest `sha256:9628b0c608488edbfc5af477199e847e5a35b119d4ab96edbecd036cbde4bfd1`.
- IPA SHA-256: `952b2daeef4bc01fe62476611c6620cf7ce79d3905d87bd82336e4650d0d69b0`.
- source ZIP SHA-256: `44494de6213883b8bee16b6e99336b33073ed38b17a53062f9be7a2cff22b73d`.
- independent package verification: bundle `com.embyplayerlab.app`; OnePlayer `0.14.80 (247)`; `MinimumOSVersion=15.0`; IPA `unzip -t` passed.
- evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device pending / not stable.**


### Build248 / 0.14.81 — Search Dock alignment + bounded 3×3 recommendation warm

- Build247 target-device result: root-owned Search Dock rendered too low/outside the screen; recommendation wall remained on spinner. Build247 is rejected as final.
- exact CI product source: `dc601099ded1074fafc0c7a4e000b8c6fd4c7338`.
- runtime delta: compensate the root Search overlay by `geometry.safeAreaInsets.bottom`; recommendation preload limit 60→9; each Suggestions request limit is only the remaining visible slots; returned item type remains hard-whitelisted to Movie/Series; no recommendation load-more.
- run/job: `33259763303 / 99119574495` — success.
- artifact: `OnePlayer-0.14.81-Build248-Search`; ID `9716945819`; digest `sha256:b15d327e7f628188e9df6a500ff0e26227a149a60a03b6bd1595c9aa82fffd2a`.
- IPA SHA-256: `8eb734bb26b77f377314223acbf7306da72ac9254a20586bfc443d59fea940c5`.
- source ZIP SHA-256: `94ce1911d3981d8f5ad53bc59a8a7413a1ddf54a54c1a97e49642b1b909f1bec`.
- independently verified package: `com.embyplayerlab.app`, `0.14.81 (248)`, `MinimumOSVersion=15.0`, IPA `unzip -t` passed.
- evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device pending / not stable.**


### Build249 / 0.14.82 — Search recommendation CollectionType traversal candidate

- Build248 target-device: Search Dock position/keyboard behavior accepted; recommendation wall still spins.
- uploaded log `OnePlayer-App-1788018797.log`: Suggestions requests advance sequentially across parent libraries about every 2.4–2.7 s; not a single hung HTTP call.
- exact CI product source: `f49ed220367de1ffbf9e9a5aba097d2ce160dac7`.
- runtime delta: query only `movies`/`tvshows`/`mixed` UserViews; map to Movie/Series request type; keep final actual-type Movie/Series whitelist, 9-item cap, startup warm, existing image caches and no recommendation load-more; add preload diagnostics.
- run/job: `33261820598 / 99124950794` — success.
- artifact: `OnePlayer-0.14.82-Build249-Search`; ID `9717502081`; digest `sha256:3cc924d6733cb4590361fa255d85ef2c31f879f07538e11523a6e246da487510`.
- IPA SHA-256: `0c62d51d488197b55dbfb98ab104c48404dd0caac77d786523f753c75acbb7a0`.
- independently verified package: `com.embyplayerlab.app`, `0.14.82 (249)`, `MinimumOSVersion=15.0`, IPA `unzip -t` passed.
- evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device pending / not stable.**


### Build250 / 0.14.83 — Search Suggestions nil-Type whitelist candidate

- Build249 target-device: inherited Dock remains accepted, recommendation spinner remains rejected.
- device log `OnePlayer-App-1788020447.log`: 21 total views, 19 eligible; first Movie Suggestions returned 9 but accepted 0; first TV Suggestions returned 9 but accepted 0.
- root cause: Suggestions results on this server omit a usable decoded `Type`, while Build249's second client filter required non-nil Movie/Series and discarded server-side filtered results.
- exact successful CI source: `6e7ae960bd3cc353b8d6146aea363f3876e9e8e8`.
- runtime rule: eligible CollectionType + server `IncludeItemTypes` stays Movie/Series-only; actual returned Type remains authoritative when present; when absent, the exact request whitelist is trusted only if every requested type is Movie/Series. Search consumes the prevalidated output directly.
- run/job: `33263279291 / 99128762968` — success.
- artifact: `OnePlayer-0.14.83-Build250-Search`; ID `9717900754`; digest `sha256:f5cad646e230ffe1666e30fd2b6ce472b5d16cace168a850c9f07cf0e43e35e0`.
- IPA SHA-256: `f213b3d6f30ac101d563e3894c3352fdcd9c9bcb46c7a266faa48c8577e73ada`.
- package verified: `com.embyplayerlab.app`, `0.14.83 (250)`, `MinimumOSVersion=15.0`, IPA integrity passed.
- superseded CI-only incident: run `33263000305` failed compilation before packaging after an intermediate stale Search-view replacement; no IPA from that run and it is not product evidence.
- evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device pending / not stable.**


### Build251 / 0.14.84 — Search user-global Suggestions candidate

- Build250 target-device: Dock/keyboard remains accepted; recommendation first paint rejected because Search still spins.
- comparative evidence: official Emby Web Search on the same server immediately shows built-in `更多推荐`.
- exact runtime source: `cc1806d7f606581e138579b44d94e16dc9ff7135`.
- change: replace `UserViews` + per-library `ParentId` Suggestions traversal with one user-global `/Users/{userId}/Suggestions` request using `IncludeItemTypes=Movie,Series`, `Limit=9`; no fallback traversal.
- run/job: `33264608646 / 99132347141` — success.
- artifact: `OnePlayer-0.14.84-Build251-Search`; ID `9718288974`; digest `sha256:da474aaa24a3d8ff65e41ed990b861ba377f6a92938670bfe89a9625d8cc4470`.
- IPA SHA-256: `4923368ddca5bca9e3d9db83234b19547b12673feb22af50fd3e3279b08cc750`.
- package: `com.embyplayerlab.app`, `0.14.84 (251)`, `MinimumOSVersion=15.0`, IPA integrity passed.
- evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device pending / not stable.**


### Build252 / 0.14.85 — Search direct global Suggestions payload

- Build251 target-device: spinner ends quickly but no recommendation wall; log `OnePlayer-App-1788023908.log` shows global Suggestions `returned=9 nilType=0 accepted=0`.
- exact product source: `dbfd323ec4a14e12dc57293c98b1fe6fbe239c5e`.
- change: keep one global `/Users/{userId}/Suggestions?Limit=9&IncludeItemTypes=Movie,Series` request and remove only the second local type rejection; render the exact returned payload.
- run/job: `33265539007 / 99134824511` — success.
- artifact: `OnePlayer-0.14.85-Build252-Search`; ID `9718566319`; digest `sha256:15343da3075db72f32349250d0dc9a1a7b67ecb325bbcd507ea22276084abb9c`.
- IPA SHA-256: `b4dd85fb880692e0b24c481d58079d2bb33db1609669d7e93a3244c53fc8e236`.
- package: `com.embyplayerlab.app`, `0.14.85 (252)`, `MinimumOSVersion=15.0`, IPA integrity passed.
- evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device pending / not stable.**


### Build253 / 0.14.86 — Search Web-aligned random Items recommendation candidate

- Build252 target-device: rejected for recommendation semantics; a surfaced recommendation opens as type `Tag` (`情趣内衣`) while official Emby Web shows actual movie/series content.
- exact product source: `fc9e5bdf1c24e694c3d28e6c7f4a8f1609bfb5a5`.
- change: Search landing recommendation source is now `/Users/{userId}/Items` with `Recursive=true`, `SortBy=Random`, `Limit=9`, `IncludeItemTypes=Movie,Series`; no `/Suggestions` call from Search preloader.
- source evidence: `bpking1/embyExternalUrl` classifies Emby Web `/Users/(.*)/Items` requests with `SortBy=Random` as `searchSuggest`.
- run/job: `33266680237 / 99137850447` — success.
- artifact: `OnePlayer-0.14.86-Build253-Search`; ID `9718894001`; digest `sha256:e687831d57682a1e3e86462c4ba7cd25ea196cc593a6b174af081f862e1e464e`.
- IPA SHA-256: `1c9454f49530ea8e41b6164fdcb88bee56bea9338a444c3485b0a2f28965cbf5`.
- package: `com.embyplayerlab.app`, `0.14.86 (253)`, `MinimumOSVersion=15.0`, IPA integrity passed.
- evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device pending / not stable.**

### Build256 / 0.14.89 — Search final accepted / merged

- exact tested product source: `723d803c70326dee49aabc75f15ce445b7de947e`.
- Xcode 16.4 Release run/job: `33271528610 / 99150738764` — success.
- artifact: `OnePlayer-0.14.89-Build256-Search`, ID `9720282077`, digest `sha256:e9c3f0756cb4dbd7a0fa9f2785594fa3df7e41964f472426a14e6c50a231615e`.
- IPA SHA-256: `01cf29fa117df904307286066c131d68be0e89b8f8f4a26b8b960c29ae6afce5`; bundle `com.embyplayerlab.app`; MinOS 15.0; integrity passed.
- target-device: PASS and user accepted.
- PR #264 merged to `main` at `647c1f66e5836fcd20a23a57600211488eeafb3d`.
- evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device tested ✅ / user accepted ✅ / stable/merged ✅**.
