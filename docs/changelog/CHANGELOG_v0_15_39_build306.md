# OnePlayer 0.15.39 / Build306 — Home return poster retention

Build305 target-device testing accepted the Library media-only Folder correction and exposed a separate Home presentation defect: after Home → detail → back or Home → Library → back, already-loaded poster artwork visibly blanks and is adopted again while card text/layout remains resident.

Exact Build305 source inspection shows Home does not unconditionally reload its metadata on return. The shared `EmbyPosterSections` presentation owner instead treated temporary page inactivity like true cell reuse: `EmbyPosterHorizontalRow.deactivate()` called `prepareForReuse()` on every visible poster child, and those cells explicitly cleared their current artwork image. The return path then reconfigured the same cells and re-adopted images, producing the visible blank/reload sweep.

Build306 makes one lifecycle distinction in the existing shared poster owner. Temporary page suspension now cancels visible image subscriptions/prefetch demand and preserves row offset **without clearing the currently displayed UIImage/card binding**. Real row removal, offscreen reuse, query replacement and child-cell reuse keep the existing destructive `deactivate()/prepareForReuse()` behavior, so this does not add a second cache or retain unbounded offscreen artwork.

A regression covers poster, landscape and library row styles: temporary suspension must retain the same visible UIImage across suspend/reactivate, while true deactivation must still release it. App identity advances to `0.15.39`; Deployment Target remains iOS 15.0. No Home metadata loader, native navigation, carousel runtime, Player, Transport, Cache or Emby Session change.

Verified Build306 candidate baseline:
- exact tested product source: `20dac5ce21e7d3261794dc62827b90fa07b048fb`;
- dedicated CI run/job: `37839047724 / 113523454935` — success;
- actual-source PosterWall regression: **54 tests / 0 failures**;
- Release generic-iOS build and identity/MinOS validation: success on Xcode 16.4;
- artifact `OnePlayer-0.15.39-build306-home-return-poster-retention`, ID `11577437579`, digest `sha256:dce68eb07b7f8dc469051e68fdae3eb33b28e6e4cd835739b9404034a92fa8cc`;
- IPA SHA-256 `414dac7cfb8026bd42219251b6f700d53733bb6680540d4b1b58e822368f2b15`;
- source ZIP SHA-256 `443c44566e0e3a33bdcbec8e4a4a9b4ba2a5437d51238f3d304fd28dc7189111`, archive comment equals the exact product source;
- bundle `com.embyplayerlab.app`, version/build `0.15.39 / 306`, display name `OnePlayer`, Info.plist MinOS `15.0`; embedded runtime Mach-O minimum-OS audit passed;
- downloaded artifact ZIP digest, IPA/source ZIP checksums and ZIP integrity independently reverified after CI.

Target-device acceptance on 2026-10-09: the user completed both Home → detail → back and Home → Library → back validation and reported **“验证完了，没问题了”**; the prior black/blank poster reload sweep no longer reproduces in the accepted session. PR #294 merged at `dca5f145612301c071619ee2d57fd80d46bf726a`.

Evidence: **Code written ✅ / CI passed ✅ / IPA produced+independently verified ✅ / real-device tested ✅ / task accepted ✅ / merged ✅ / stable-frozen ✅.**
