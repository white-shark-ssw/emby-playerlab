# OnePlayer 0.13.99 Build166

- Wi-Fi and cellular no longer behave like separate video cache pools. Both network modes now share one persistent sparse Range store and one cached-range map.
- Wi-Fi / cellular settings are network preload limits only. Switching interfaces changes future forward-prefetch allowance but must not evict, shrink, invalidate, or rebuild already cached ranges.
- Rolling-cache retention and total cache eviction use a shared retention window derived from the larger network preload setting instead of the currently active interface.
- Persistent video cache stays enabled when either network preload setting is non-zero; switching to a network configured with zero preload no longer clears the existing shared cache.
- Cache settings UI now labels Wi-Fi / cellular values as preload limits and explicitly documents shared-pool behavior.
- PiP fast seek can optimistically commit a confidently predicted keyframe from the persistent standby pipeline before MPV landing; MPV actual landing remains authoritative and validates/corrects the visual result.
- PiP return keeps the black presentation cover until MPV reports a fresh restored frame, then arms the final presentation-gate release. Orientation hold remains independent and lasts through AVKit stop.
- PiP close dismissal now also listens for UIApplication.didBecomeActive so a stopped PiP session cannot leave a black PlayerScreen when SwiftUI scenePhase misses the transition.
- PiP entry moves MPV gpu-next -> null suspension before the Home transition and waits for playback-clock continuity before requesting Home, reducing the desktop-visible audio interruption window while preserving the Build159 MoltenVK safety rule.
- MPV native seek remains absolute+keyframes. UnifiedTransport client-direct STRM -> 302 -> 115 byte flow, Build161 volume dedupe, and iOS 15.0 Deployment Target remain unchanged.
