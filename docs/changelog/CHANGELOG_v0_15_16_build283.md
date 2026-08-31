# OnePlayer 0.15.16 / Build283 — Poster native detail push animation regression fix

- Base: target-device-positive Build280 exact source `531d7f53c55e1e3cff44069e9bce3193ac94749a`.
- Build280 target-device pagination A/B is retained unchanged: full Library presentation persistence remains on the serial utility queue with `main_thread=0`; the former Build278 persistence-correlated 50–100 ms pagination severe-tail family was not reproduced.
- User force-quit/relaunch check reports cached-first Library behavior remains normal.
- Regression fixed: the Library `.items` native UICollectionView path no longer creates its hidden `NavigationLink` only after selection when the binding is already active. The link now remains mounted and the same selection binding changes false→true, restoring system-owned push transition semantics.
- No direct `UINavigationController.pushViewController`, custom transition, second navigation owner, pagination, persistence, image, scroll-physics, Search, Home, Player/MPV/PiP, UnifiedTransport, playback Cache/Session, STRM/302/115/CDN or Deployment Target change.
- Evidence level at source commit: code written only; CI/IPA and target-device animation confirmation remain separate gates.
