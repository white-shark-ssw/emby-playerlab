# OnePlayer 0.15.38 / Build305 — Library media-only root correction

Build304 target-device evidence refines `DEV-meaningless-detail-routing`: the former empty `Folder` detail now opens its real folder and shows the two child videos, but the user correctly rejects that intermediate Folder card as normal movie-library content.

The new log proves the fresh Library root request is recursive and lacks `IncludeItemTypes`; selecting the problematic card then performs the existing non-recursive folder-child request and returns two media items. Build305 therefore keeps the accepted Folder browser unchanged, but when `libraryHubItemsPage` is recursive and its caller did not supply an item-type scope, the request now defaults to `Movie,Series,Video`. Explicit item-type scopes are unchanged, and non-recursive folder browsing remains unrestricted.

This removes Folder objects from the normal recursive content query without client-side child flattening or a second loader. No Player, Transport, Cache, Emby Session, detail implementation, poster geometry, native navigation ownership or deployment-target change. iOS 15.0 remains the minimum.

Verified Build305 baseline: exact product `3476a3d9a8976ef483bb9d9e2317d0d2e442f8bb`; CI run/job `37832789044 / 113502123244` success; 53 tests / 0 failures; artifact `11574533261`, digest `sha256:9ae178b9492534d0357bfcf3a7ddc8fcada49b1a49380019ef76dbc53b040b53`; IPA SHA-256 `f843cd2ace20f9aa15f447c8d98e4935211a033b65e4493dd649fde30b9e53d4`; source ZIP SHA-256 `a6ef12cff823c2d9b959635e079176cd1d18dc11ab535b3151c255bbf9a4ca11`; bundle `com.embyplayerlab.app`, version/build `0.15.38 / 305`, MinOS 15.0. Artifact/source/IPA checksums and archive integrity were independently verified after download.

2026-10-09 target-device result: the user explicitly confirms the previously reported Folder/media-only Library-content problem is fixed. Build305 is therefore **real-device accepted for this task**. A newly observed Home-return poster-artwork blank/reload behavior is tracked separately because Build303→Build305 source comparison shows this task did not modify the shared Home poster presentation owner.

Evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / Build305 target-device tested ✅ / task behavior accepted ✅.**
