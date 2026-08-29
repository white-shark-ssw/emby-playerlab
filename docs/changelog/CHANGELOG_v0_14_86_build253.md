# OnePlayer 0.14.86 / Build253

- Search `推荐观看` no longer uses `/Users/{userId}/Suggestions`, which target-device testing showed could return metadata entities such as `Tag`.
- Search landing recommendations now use the normal Emby user Items endpoint with `SortBy=Random`, `Recursive=true`, `Limit=9`, and `IncludeItemTypes=Movie,Series`, matching observed Emby Web search-suggestion traffic.
- Preserve the Build248-accepted Search Dock/keyboard behavior, startup warm, persistent image cache and decoded-image cache.
- No Player, MPV, STRM/302/115 Transport, playback Session Cache, Resume/progress, credentials, PiP or Deployment Target changes.

Evidence: Xcode 16.4 Release CI passed and IPA produced/verified; target-device validation pending.
