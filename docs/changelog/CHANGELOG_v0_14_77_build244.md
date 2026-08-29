# OnePlayer 0.14.77 / Build244

## Search page competitor-alignment candidate

- Search keyboard no longer participates in server-Dock avoidance; when the Search field is focused the Dock remains at the physical bottom/behind the keyboard instead of being pushed above it.
- Added Search gear menu with global-search toggle, recommendation toggle, and independent selection for every restored Emby server.
- Added persistent, deduplicated search-history chips with native destructive clear confirmation; an empty history section is omitted entirely.
- Added Emby-provided recommendation surface capped at 9 posters in the shared 3-column grid.
- Added multi-server search grouping: one horizontal poster row per selected Emby server, plus `更多` navigation into the shared paginated 3-column grid.
- Preserves `SessionStore` as server/route authority and existing poster/detail navigation contracts.

## Compatibility / protected contracts

- Deployment Target remains iOS 15.0; target test device remains iPhone 15 Pro Max / iOS 17.0.
- No Player/MPV/PiP, UnifiedTransport, playback Cache/Session, Emby Resume/progress, STRM→302→115/CDN client-direct transport, server credential storage, or NAS media-byte-routing change.

## Evidence at candidate creation

- Runtime source: `cf8be3562687ed65a8cf63c62ad3dda3150d3cde`.
- Dedicated Xcode 16.4 + MPV compile run `33251213958`: PASS, including iOS 15.0 build-setting verification.
- IPA: pending dedicated Build244 Release packaging.
- Real-device validation: pending.
- Stable/frozen: no.
