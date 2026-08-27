# OnePlayer 0.14.44 / Build211

- Carousel foreground page-slot geometry remains full-width.
- Horizontal render translation now starts after UIKit horizontal acquisition instead of replaying the touch-down take-up distance into the first rendered movement.
- Release/commit still uses touch-down total distance and the existing 0.28 / 0.48×width contract.
- Foreground pages stay fully opaque during interactive drag; backdrop crossfade remains independent.
- No Player/MPV/PiP/Transport/Cache/Emby Session path changed.
