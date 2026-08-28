# OnePlayer 0.14.64 / Build231

- Diagnostic-only Home carousel foreground compositing A/B.
- Base: cleaned carousel Build228 foundation (Build226 three-slot Hero residency + Build228 max-refresh-through-settle).
- Adds one SwiftUI `compositingGroup()` boundary to each existing carousel foreground page before opacity/X offset.
- Does not carry Build230 persistent residency or Build227 pixel rounding.
- Gesture ownership, acquisition-relative motion, 0.28/0.48 release gates, Hero/persistent visual semantics, release timing, preload and Frozen/P0 paths remain unchanged.
- Purpose: test whether slow-drag title shimmer is caused by foreground child-layer compositing/presentation rather than geometry or backdrop first-mount pressure.
