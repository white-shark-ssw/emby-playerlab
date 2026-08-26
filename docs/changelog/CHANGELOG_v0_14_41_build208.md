# OnePlayer 0.14.41 / Build208

- Replaces the 80%-width foreground travel model with full-width foreground page slots: outgoing and incoming foreground page centers remain exactly one Hero width apart during the entire transition.
- Existing foreground content width remains `width - 56`, so adjacent page content keeps a constant 56pt separation instead of structurally overlapping.
- Keeps the Build198 single UIKit begin/move/end/cancel owner and all raw progress, commit, release, reversal and settle contracts unchanged.
- Tightens only the earliest visual attenuation from `0.60` to `0.85` in the existing sixth-power soft-start function; mid/late progress still converges rapidly to linear and tail slope remains 1.0.
- Background/foreground opacity continues to use the same visual progress. Left/right and first↔last wrapping keep the existing direction + modulo authority.
- No Player/MPV/PiP/Transport/Cache/Session/P0 runtime path changes. Deployment Target remains iOS 15.0.
