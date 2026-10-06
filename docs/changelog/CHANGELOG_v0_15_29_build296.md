# OnePlayer 0.15.29 / Build296 — bounded Library motion diagnostics

DEV-poster-grid-smoothness, G01 Library.items only. Build295 user feedback: refactor relatively successful, high FPS maintained, with abrupt initial-load inertial stop and further long-frame improvement still under investigation. Qualitative feedback is not full P2 acceptance or presented-FPS measurement.

- Capture native drag/deceleration endpoints, collection geometry/legal boundary, record count/revision, append begin/completion, loading/footer updates and existing endRefreshing calls without changing them.
- Keep a fixed64 numeric frame history and include the first stationary frame after motion; dump only at motion-end or existing >=25ms gap events. Trace is capped4096 events per controller. No per-frame strings, timer, offset correction or inertia override.
- Original Library model records request/response/publication/persistence/finish with uptime/generation/frontier; capped2048 events per model. No source URL/user ID in new diagnostics.
- Log sourceVersion/package Build at controller creation. Copy actual AppIdentity into production-source regression harness rather than a version stub.

Original60 paging, load-ahead, footer layout, refresh behavior and image budgets are unchanged. Preserve Build293 carousel, Build294 Dock, Search256/P0 and iOS15.0. No additional scroll host migration. Tests/Release/IPA identity must be checked before handoff; true physical-device inertia and long-frame attribution still require the new matched log/video.
