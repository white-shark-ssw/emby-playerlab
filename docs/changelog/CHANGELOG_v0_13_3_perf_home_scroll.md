# v0.13.3 Home Scroll Frame Pacing

- Prevent Home from writing Hero scroll state while carousel Hero is absent.
- Clamp Hero scroll tracking after the Hero has fully left the viewport so deep Home scrolling no longer invalidates the entire Home SwiftUI tree on every contentOffset change.
- No changes to player, transport, cache, seek, Detail Hero, Dock, carousel visual behavior, or deployment target.
