# OnePlayer 0.14.84 / Build251

- Search `推荐观看` now uses one user-global Emby `/Users/{userId}/Suggestions` request instead of traversing every library with `ParentId`.
- Request remains restricted to `IncludeItemTypes=Movie,Series` and `Limit=9`.
- Preserve Build248-accepted Search Dock/keyboard behavior, startup warm, persistent image cache and decoded-image cache.
- No Player, Transport, playback Session Cache, PiP, Resume/progress, credentials, shared poster-grid or Deployment Target changes.

Evidence: Xcode 16.4 Release CI passed and IPA produced/verified; target-device validation pending.
