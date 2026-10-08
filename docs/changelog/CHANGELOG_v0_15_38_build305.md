# OnePlayer 0.15.38 / Build305 — Library media-only root correction

Build304 target-device evidence refines `DEV-meaningless-detail-routing`: the former empty `Folder` detail now opens its real folder and shows the two child videos, but the user correctly rejects that intermediate Folder card as normal movie-library content.

The new log proves the fresh Library root request is recursive and lacks `IncludeItemTypes`; selecting the problematic card then performs the existing non-recursive folder-child request and returns two media items. Build305 therefore keeps the accepted Folder browser unchanged, but when `libraryHubItemsPage` is recursive and its caller did not supply an item-type scope, the request now defaults to `Movie,Series,Video`. Explicit item-type scopes are unchanged, and non-recursive folder browsing remains unrestricted.

This removes Folder objects from the normal recursive content query without client-side child flattening or a second loader. No Player, Transport, Cache, Emby Session, detail implementation, poster geometry, native navigation ownership or deployment-target change. iOS 15.0 remains the minimum.

Evidence at creation: **Build304 target-device rejected for the final UX; Build305 code written; CI/IPA/Build305 target-device validation pending.**
