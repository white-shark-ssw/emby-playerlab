# OnePlayer 0.14.31 / Build198

- Rebuilds the Home carousel manual-drag input as one UIKit gesture lifecycle owner from touch begin through move/end/cancel.
- Vertical motion fails the carousel recognizer immediately so the ancestor Home ScrollView remains authoritative; confirmed horizontal recognition owns the gesture instead of running simultaneously with ScrollView.
- Removes the hybrid native-move / SwiftUI-release split that caused Build189/193 to freeze between pages after finger release.
- Uses only the latest real touch position for each UIEvent; UIKit predicted touches are retained only for the existing release commit decision and never drive intermediate rendering.
- Preserves the established page-slide interaction: Logo, rating, year, type and overview remain attached to the carousel page and travel horizontally with it.
- Preserves existing 0.28 progress / 0.48×width predicted commit thresholds, 0.22/0.18 second complete/cancel settle, auto-advance, persistent blur, detail tap and iOS 15.0 deployment target.
- Stage 1 intentionally does not add atomic transition snapshots, predicted-touch rendering, interpolation, debounce, timers, watchdogs or crossfade fallback.
