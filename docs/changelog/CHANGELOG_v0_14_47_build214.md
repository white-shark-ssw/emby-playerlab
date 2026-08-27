# OnePlayer 0.14.47 / Build214

- Retains the full-width Home-carousel foreground page-slot geometry from Build208.
- Horizontal render translation now starts at the UIKit horizontal-acquisition point instead of replaying the touch-down take-up distance into the first rendered movement.
- Post-acquisition foreground motion is direct 1:1 relative translation, including reversal through the acquisition point; no visual easing is applied to foreground spatial motion.
- Release/commit authority remains the touch-down total distance with the existing 0.28 progress / 0.48×width predicted-distance contract, including a one-sample fast-fling path before any rendered drag sample.
- Foreground pages remain fully opaque while a transition is active; backdrop crossfade keeps the existing independent blend mapping.
- No Player/MPV/PiP/Transport/Cache/Emby Session path changed; deployment target remains iOS 15.0.
