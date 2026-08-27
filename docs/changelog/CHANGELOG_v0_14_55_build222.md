# OnePlayer 0.14.55 / Build222

- Diagnostic A/B only, based on the accepted Build216/main product source rather than Build221.
- Automatic Home carousel transitions may start only while the Home vertical scroll position is at its top/rest position (`abs(homeRawScrollMinY) <= 0.5`).
- Once the user has vertically browsed away from the top, the existing 1-second timer may still tick but it cannot start the 6-second automatic carousel transition; returning to the top restores the existing automatic behavior.
- Current persistent backdrop, preload layer, Hero rendering, manual horizontal carousel gestures, navigation and all playback/P0 paths are unchanged.
- Purpose: isolate whether offscreen automatic carousel transition/persistent-target presentation is a causal contributor to Home vertical scrolling hitches before attempting broader Home architecture changes.
