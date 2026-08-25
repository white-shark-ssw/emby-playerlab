# OnePlayer 0.14.21 / Build188

## Detail episode selection / full picker navigation candidate

- Detail-page horizontal episode cards now select the episode only; they no longer immediately start playback.
- The existing blue episode outline remains the selected-episode indicator, and the existing main Play / Resume button remains the playback action for the selected episode.
- A compact 12 pt selected-episode summary is shown directly below the “即将播放” range/header row and above the episode cards; the row keeps a fixed height so selection does not shift the episode container vertically.
- Explicit card selection also aligns the highlighted 10-episode range pill with the selected episode.
- Full episode picker playback no longer dismisses the picker or waits on the previous fixed 100 ms delay. The visible picker presents the existing shared `model.selectedSource` fullscreen player, so closing playback returns to the same picker navigation entry and should preserve its existing ScrollView position without a second scroll-offset owner.
- Favorite Episode → Series detail `initialEpisodeID` selection, Build176 source-owned player session replacement, Build178 canonical Emby episode ordering, Build182 detail performance/presentation-cache ownership, MPV/Transport/Cache/PiP and iOS 15.0 deployment target remain unchanged.

## Candidate identity note

- The same functional source first produced a successful 0.14.20 / Build187 CI/IPA, but that detail package was retired before distribution after the parallel home-carousel task independently occupied Build187 as its active diagnostic identity.
- Build188 changes only the candidate identity/changelog relative to that successful detail Build187 source; the episode-selection/navigation implementation is unchanged.

## Evidence

- Code written: yes.
- Narrow source/static contracts: passed.
- Build187 detail Release CI/IPA: technically succeeded but retired due identity collision and not distributed.
- Build188 CI / IPA / real-device: pending at changelog creation time; do not interpret this file as runtime acceptance.
