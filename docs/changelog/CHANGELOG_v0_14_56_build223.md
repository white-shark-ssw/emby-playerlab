# OnePlayer 0.14.56 / Build223

- Diagnostic A/B only, based on current `main` / accepted Build216 product code rather than Build221 or rejected Build222 behavior.
- The always-mounted full-screen `persistentCarouselBackdrop` is not mounted in immersive Home for this candidate.
- Carousel Hero artwork, carousel preload layer, automatic carousel timing, manual horizontal interaction, navigation and all playback/P0 paths remain unchanged.
- The persistent-backdrop implementation itself remains in source; only the Home root mount is removed so the experiment isolates its full-screen presentation/compositing cost.
- Purpose: test whether the persistent blurred full-screen backdrop is a causal contributor to the remaining Home vertical scrolling hitching before changing preload, Hero, gesture ownership or shared image infrastructure.
