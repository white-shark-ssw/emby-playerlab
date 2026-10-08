# OnePlayer 0.15.37 / Build304 — Library Folder routing

Build304 is the candidate for `DEV-meaningless-detail-routing`. Build303 target-device evidence showed a Library root item whose Emby type is `Folder` being presented with the generic media-detail shell; that visit made no `PlaybackInfo` request and published zero detail images.

The candidate changes only the Library root native poster selection destination: `Folder` / `CollectionFolder` reuse the existing `V3LibraryFolderBrowserView`, while non-folder media keep the existing `EmbyPosterDetailDestination`. The existing folder child owner/API remains unchanged. The Library regression guard permits only this exact route substitution; `EmbySharedImageAndNavigation.swift`, `EmbyMediaDetailView`, Player, Transport, Cache and Emby Session remain untouched. Deployment target remains iOS 15.0.

Evidence at creation: **Code written; PR #293 open; CI/IPA/target-device validation pending.** Do not describe this candidate as device-fixed, accepted, stable or frozen until those evidence levels exist.
