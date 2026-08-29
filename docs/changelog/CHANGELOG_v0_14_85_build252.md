# OnePlayer 0.14.85 / Build252

- Preserve Build251's single user-global Emby `/Users/{userId}/Suggestions` request and accepted Search Dock/keyboard behavior.
- Target-device Build251 log proves the global request returns 9 items quickly, but the client rejects all 9 because their returned `Type` values do not match the extra local Movie/Series post-filter.
- Build252 removes that second client-side rejection and displays the exact global Suggestions payload returned by the already constrained `IncludeItemTypes=Movie,Series` request.
- Add returned-type histogram diagnostics for verification without changing request scope.
- Preserve startup warm, persistent image cache, decoded-image cache, Player/Transport/P0 contracts and iOS 15.0 deployment target.

Evidence at changelog creation: code written; CI/IPA and target-device validation pending.
