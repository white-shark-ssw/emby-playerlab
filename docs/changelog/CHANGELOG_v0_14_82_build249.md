# OnePlayer 0.14.82 / Build249

Search recommendation follow-up candidate.

- Preserve the Build248 target-device accepted Search Dock position and keyboard behavior.
- Fix recommendation startup traversal by querying only Emby libraries whose real `CollectionType` can contain Movie/Series recommendations: `movies`, `tvshows`, `mixed`.
- Match each library Suggestions request to its real type: Movie, Series, or Movie+Series for mixed libraries.
- Keep the client-visible returned-item whitelist restricted to actual `Movie` / `Series` items.
- Keep the recommendation wall capped at 9 items, startup one-shot warm, existing persistent image cache and decoded-image cache, and no recommendation scroll load-more.
- Add Search recommendation preload diagnostics for eligible-library and accepted-item counts.

Evidence at changelog creation: code written; CI/IPA and real-device validation pending. Deployment Target remains iOS 15.0.
