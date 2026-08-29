# OnePlayer 0.14.89 / Build256

- Remove Search recommendation fetching from app startup. The initial 9 are requested only when the user enters the Search Dock page.
- Move Search recommendation view-model lifetime to the server Dock root: detail push/pop keeps the same model and all already-appended recommendation items; manually switching away from Search destroys that model.
- Re-entering Search after a Dock switch creates a fresh model and performs a fresh initial-9 request.
- Prevent Search `.task` re-entry from replacing an already-populated recommendation list with the initial 9.
- Remove session-global recommendation metadata/task retention from `V3SearchRecommendationPreloader`; shared image disk/decoded caches remain unchanged.
- Preserve Build253/254 recommendation query semantics, +6 `ExcludeItemIds` loading, Build255 non-lazy outer section owner and Build248 Dock/keyboard behavior.
- No Player, MPV, STRM/302/115 Transport, playback Session Cache, Resume/progress, PiP, credentials or Deployment Target changes.

Dedicated Xcode 16.4 Release CI/IPA passed for exact product source `723d803c70326dee49aabc75f15ce445b7de947e` (run `33271528610`, artifact `9720282077`, IPA SHA-256 `01cf29fa117df904307286066c131d68be0e89b8f8f4a26b8b960c29ae6afce5`, MinOS 15.0). Target-device validation remains pending.

- Target-device acceptance: PASS on iPhone 15 Pro Max / iOS 17.0. Build256 is the final accepted Search behavior and is ready for merge.
