# OnePlayer 0.14.75 / Build242

Diagnostic-only Home performance A/B from exact Build241 source.

- Keeps the Build241 500 pt/s fling behavior in source, but disables the entire carousel presentation path for this diagnostic package.
- Preserves Home carousel data presence, immersive layout mode, Hero vertical footprint, Home rows, scroll structure and refresh behavior.
- Disables full-screen persistent blurred backdrop, Hero carousel rendering/interaction, carousel image preload, carousel auto-advance and carousel-owned Hero scroll-state updates.
- Purpose: compare Home vertical scrolling with Build241 and determine whether the carousel stack materially affects whole-Home performance.
- No Player/Transport/Cache/Session/PiP changes.
- Diagnostic only; not a candidate for normal product behavior.
