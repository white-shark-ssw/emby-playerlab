# OnePlayer 0.15.39 / Build306 — Home return poster retention

Build305 target-device testing accepted the Library media-only Folder correction and exposed a separate Home presentation defect: after Home → detail → back or Home → Library → back, already-loaded poster artwork visibly blanks and is adopted again while card text/layout remains resident.

Exact Build305 source inspection shows Home does not unconditionally reload its metadata on return. The shared `EmbyPosterSections` presentation owner instead treated temporary page inactivity like true cell reuse: `EmbyPosterHorizontalRow.deactivate()` called `prepareForReuse()` on every visible poster child, and those cells explicitly cleared their current artwork image. The return path then reconfigured the same cells and re-adopted images, producing the visible blank/reload sweep.

Build306 makes one lifecycle distinction in the existing shared poster owner. Temporary page suspension now cancels visible image subscriptions/prefetch demand and preserves row offset **without clearing the currently displayed UIImage/card binding**. Real row removal, offscreen reuse, query replacement and child-cell reuse keep the existing destructive `deactivate()/prepareForReuse()` behavior, so this does not add a second cache or retain unbounded offscreen artwork.

A regression covers poster, landscape and library row styles: temporary suspension must retain the same visible UIImage across suspend/reactivate, while true deactivation must still release it. App identity advances to `0.15.39`; Deployment Target remains iOS 15.0. No Home metadata loader, native navigation, carousel runtime, Player, Transport, Cache or Emby Session change.

Evidence at this checkpoint: **Code written ✅ / exact diff inspected ✅ / Build306 CI pending / IPA pending / target-device validation pending / stable-frozen ❌.**
