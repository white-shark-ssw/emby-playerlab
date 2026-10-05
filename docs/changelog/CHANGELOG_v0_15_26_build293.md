# OnePlayer 0.15.26 / Build293 — continuous artwork handoff

Build292 user testing confirms stable120FPS and removal of long frames, but reports flickering on consecutive rapid switches. This candidate preserves that runtime/input/performance/fade/Dock source and corrects native artwork interruption only.

- Capture actual presentation opacity of every resident artwork and actual base color before stopping a release animator.
- Preserve these values across runtime page rebasing; retain still-contributing outgoing images, then blend from the captured endpoints during real finger movement and the next native tail.
- Clear the handoff when the animation settles or the transition resets. No timer, second product progress owner, full-tree SwiftUI update or per-progress geometry layout.

Actual-source image-opacity/base-color/multi-takeover regression plus existing native/Dock suite, exact-source Release/IPA and MinOS15 verification required. Flicker acceptance remains a device gate; user-reported Build292120FPS is not inferred numerically from30fps recording.
