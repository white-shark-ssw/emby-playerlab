# OnePlayer 0.15.28 / Build295 — Library poster-wall pilot

DEV-poster-grid-smoothness P1/P2. Only Library.items uses the new complete UICollectionView scroll host and fixed UIKit cells. Other Library tabs, Favorites, Search and Home remain on their accepted presentation adapters pending this pilot's device evidence.

- Existing Library cache schema/frontier and 60-item sequential paging retained. Metadata restoration, index reconstruction and ordered snapshot object/JSON/atomic write run off the UI actor. Restoration completes before any live load/refresh/sort can publish.
- Existing decoded pool, disk actor and ImageIO decoder remain image authorities. A shared URL request coordinator merges independent visible/prefetch/first-screen subscriptions with four active preparations; cancelled work remains counted until it finishes. First-screen strong references share the same UIImage, are globally capped at24 URLs across two page demands; UIKit prefetch is capped at12 per pilot. These are starting budgets, not EX measurements or a whole-app memory limit.
- Image completion adopts only its bound cell. Reuse/tag/source/size generations reject late callbacks. Append converts only new records; same-revision updates do not traverse all metadata. Footer/loading/error and refresh belong to the same vertical scroll host.
- Persistent hidden NavigationLink preserves Build283's user-positive system activation contract. Selection remains owned by the Library page; native push/pop stays system-owned. Active-page status-bar return-top does not request metadata or reset pagination.
- Real sort supersession invalidates old query results; no retry/timer/watchdog added. Native frame-gap/summary diagnostics and ImageIO signposts support target-device attribution; display-link cadence is not presented FPS.

Protect accepted Build293 carousel, Build294 Dock, Search256 semantics, Player/MPV/PiP/Transport/Session Cache/Emby and iOS15.0. NAS never relays media bytes. No dependency added.

Evidence at implementation: code written; actual-source simulator regressions/Release CI/IPA and target-device acceptance pending. Test cold images, disk-warm relaunch, repeated scrolling/paging, ~item2000 return-top, native detail push/pop/interactive back, refresh/sort, badges and Dock. This pilot does not claim all poster routes or120FPS are fixed.
