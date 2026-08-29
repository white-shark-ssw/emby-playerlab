# OnePlayer 0.14.74 / Build241

## Home carousel

- Baseline is the exact real-device-tested Build239 interaction/presentation source.
- Lowers only the direction-aware latest-delivered fling trigger from 600 pt/s to 500 pt/s so a short intentional flick can switch items with slightly less force.
- Keeps the ordinary slow-drag commit threshold at 0.28.
- Keeps Build239 release/cancel settle timing, Build237 persistent white-flash correction, Build236 acquisition handling, Build231 foreground compositing, Build226 Hero residency, and Build228 max-refresh-through-settle unchanged.
- Does not carry Build240 release-handoff diagnostic behavior into this candidate.
- Player / MPV / PiP / Transport / Cache / Emby Session and other Frozen/P0 paths are unchanged.
- Deployment Target remains iOS 15.0.
