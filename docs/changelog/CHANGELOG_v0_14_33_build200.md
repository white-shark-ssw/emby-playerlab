# OnePlayer 0.14.33 / Build200

## Home carousel EX-blend candidate

- Inherits Build198's single UIKit carousel gesture lifecycle owner unchanged: begin / move / end / cancel remain owned by the same native interaction surface.
- Build198 target-device result: release/settle, reversal continuity and the other tested carousel behavior were good, but minimum/subtle drag motion still felt visibly coarser than the EX reference.
- Build200 changes only the Hero foreground transition mapping: Logo, rating, year/type and overview stay spatially fixed and linearly crossfade from the outgoing item to the incoming item using the existing `transitionProgress`.
- The backdrop already used the same progress-driven crossfade and is not structurally changed.
- Gesture axis acquisition, 0.28 commit threshold, 0.48-width predicted release gate, complete/cancel settle timing, tap routing, vertical Home scroll arbitration and auto-advance remain unchanged from Build198.
- Player / MPV / PiP / Transport / Cache / Emby Session and STRM → 302 → 115/CDN client-direct playback paths are untouched.
- Deployment Target remains iOS 15.0; target-device validation remains iPhone 15 Pro Max / iOS 17.0.
