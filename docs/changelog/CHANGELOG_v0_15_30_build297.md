# OnePlayer 0.15.30 / Build297 — Library return retention and section timeline

- Library.items ordinary reappearance retains successfully live-loaded metadata/frontier; disk restoration still receives its first live refresh. Real refresh/sort and failed-initial retry remain model-owned.
- Live success is keyed to the original shared sort query; failed new sorts and sort changes in another paged tab still receive their first successful Library.items load.
- Preserve native navigation and scroll offset by preventing the evidenced first-page replacement, rather than adding an offset restorer.
- Add a bounded per-detail-model timeline for warm restore, item/episode/season/media/image-info/similar waits, image publication, warm store and stills-section appearance. Section appearance is not proof of a presented frame; no request reordering or guessed image-concurrency fix.
- Add fixed-size Library configure/image-adopt/layout/apply work counters and native appearance geometry. Existing numeric motion/frame diagnostics retained; no per-frame strings or new timer.
- Skip the shared image scheduler's pending scan/sort when all existing operation slots are occupied; operation budget/priority/cancellation/cache semantics unchanged.
- Actual-source16 units and3 native gesture/Library navigation tests planned, with an old load-policy negative control. Tests/Release/IPA not yet passed at source creation.
- The return fixture reads the native transition coordinator's interactive cancellation result without installing a navigation delegate or driving the transition.
- Target iPhone15ProMax/iOS17; built MinOS remains15.0. P2/device acceptance pending; accepted294 overall/293carousel/294Dock/Search256/P0 protected.
