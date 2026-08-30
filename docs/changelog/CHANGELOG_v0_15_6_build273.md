# OnePlayer 0.15.6 / Build273

## Poster 3×3 native collection A/B

- Directly based on target-device-tested Build268 exact source `f3f6e1f4e8e538b7ccd9cb676806db59cd7a0b0b`; does not inherit rejected Build269 RowStack or Build272 FixedRow behavior.
- Replaces only Library `.items` 3×3 scroll/layout owner with an iOS 15-compatible native `UICollectionViewFlowLayout`.
- Keeps the existing three-column geometry: 14 pt horizontal padding, 12 pt column spacing, 18 pt row spacing, 2:3 poster aspect ratio and fixed 38 pt title/year block.
- Reuses the existing `V3PosterCard(width:nil)` inside reusable `UIHostingController` cells, preserving shared image cache/decode/loading behavior and the Build266 no-unused-loading-publication path.
- Reuses the current `V3LibraryBrowserViewModel` item source, 60-item pagination, sort/refresh authority and `loadNextPage` behavior. Append-only page growth uses native `insertItems` instead of a full collection reload.
- Reuses the existing `EmbyPosterDetailDestination` through parent SwiftUI navigation rather than introducing a second UIKit navigation owner.
- Keeps `.trailers`, `.collections`, `.favorites`, genres/folders/suggestions and all Search routes on their existing SwiftUI presentation paths.
- Adds lean native motion diagnostics with 80→device-max display-link request during drag/deceleration and records any reverse event's offset, legal top/bottom bounds, distance to both bounds and whether it is outside legal bounds. This distinguishes normal edge bounce from a true mid-scroll reverse.
- Does not change `decelerationRate`, image quality, Search Build256 semantics, Home carousel runtime, Player/MPV/PiP, UnifiedTransport, playback Cache/Session, STRM/302/115/CDN behavior or Deployment Target.

## Evidence gate

Code written only until exact-source CI/IPA passes. Target-device acceptance requires comparing Library `.items` motion smoothness and whole-content twitch behavior against Build268/272, then returning the App log for native bound-aware reverse evidence.
