# OnePlayer 0.14.43 / Build210

## Multi-owner poster scroll diagnostics

- Build209 target-device App log captured three verified Home motion hitches, including 78.8 ms and 67.2 ms gaps, but no `scroll_route=grid` hitch even though the same session reached a grid load-ahead threshold.
- Exact Build209 source used one global `observedScrollView` / owner slot, so Home and pushed grid probes could overwrite each other as either view reattached during layout.
- Build210 keeps the same single shared `CADisplayLink` and 30 ms motion gate, but registers each Home/grid probe independently with a weak `UIScrollView` reference and last offset.
- Each display tick samples all registered vertical scroll owners, then attributes a hitch to the actually moving owner, preferring dragging/decelerating motion and the larger absolute offset delta when more than one owner moves.
- Hitch logs add `registered_scrolls` and `moving_scrolls` so the owner arbitration itself is observable.
- No scroll physics, image policy, NavigationLink, lazy-container, carousel gesture/state, Player, Transport, Cache, Session or playback path changes.
- Deployment target remains iOS 15.0.
