# OnePlayer 0.14.78 / Build245

## Search page follow-up after Build244 device test

- Shrinks the Search gear icon by 40% and tightens the Search landing header, title, search field, history chips and vertical spacing to better match the supplied competitor layout.
- Moves Search keyboard safe-area ignoring onto the actual server-root `GeometryReader`, so keyboard appearance no longer changes the geometry that positions the shared Dock.
- When only one Emby target is active — either because only one server exists or global search has only one selected server — submitting Search now enters that server's full paginated 3-column results page directly.
- Recommendations are no longer capped at 9 or filtered by media type. Initial load requests 12 Emby Suggestions, and approaching the end requests 6 more at a time.
- Recommendation grid uses Search-specific 6pt horizontal padding to match the competitor landing-page poster width without modifying the shared poster-grid owner.

## Compatibility / protected contracts

- Deployment Target remains iOS 15.0; target test device remains iPhone 15 Pro Max / iOS 17.0.
- No Player/MPV/PiP, UnifiedTransport, playback Cache/Session, Emby Resume/progress, STRM→302→115/CDN client-direct transport, server credential storage, or NAS media-byte-routing change.
- Shared poster-grid source remains untouched; Search only supplies its existing `horizontalPadding` parameter.

## Evidence at candidate creation

- Build244 target-device result: partial success, but keyboard still pushed the Dock, landing geometry was visibly too large/low versus competitor, recommendations were capped, and single-target Search still stopped at the grouped-row page.
- Build245 source is a Search-only follow-up on PR #264.
- CI / IPA: pending dedicated Build245 Release packaging.
- Real-device validation: pending.
- Stable/frozen: no.
