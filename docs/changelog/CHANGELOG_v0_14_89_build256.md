# OnePlayer 0.14.89 / Build256

- Remove Search recommendation fetching from app startup. The initial 9 are requested only when the user enters the Search Dock page.
- Move Search recommendation view-model lifetime to the server Dock root: detail push/pop keeps the same model and all already-appended recommendation items; manually switching away from Search destroys that model.
- Re-entering Search after a Dock switch creates a fresh model and performs a fresh initial-9 request.
- Prevent Search `.task` re-entry from replacing an already-populated recommendation list with the initial 9.
- Remove session-global recommendation metadata/task retention from `V3SearchRecommendationPreloader`; shared image disk/decoded caches remain unchanged.
- Preserve Build253/254 recommendation query semantics, +6 `ExcludeItemIds` loading, Build255 non-lazy outer section owner and Build248 Dock/keyboard behavior.
- No Player, MPV, STRM/302/115 Transport, playback Session Cache, Resume/progress, PiP, credentials or Deployment Target changes.

Evidence pending dedicated Xcode 16.4 Release CI/IPA and target-device validation.
