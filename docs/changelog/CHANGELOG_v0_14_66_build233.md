# OnePlayer 0.14.66 / Build233

## Poster background-work diagnostics

- Records active poster-image disk reads, detached image decodes, network requests and image-cache writes at the moment an existing `PosterScrollHitch` is emitted.
- Records the latest completed background image stage, its age and duration in the existing `PosterScrollTiming` line.
- Does not change image request size, image decode policy, cache policy, scroll behavior, pagination, Library persistence semantics, Home carousel owners, Player/MPV/PiP, Transport, playback Cache/Session or P0 contracts.
- Deployment Target remains iOS 15.0.
- Diagnostic-only candidate; no smoothness fix is claimed.
