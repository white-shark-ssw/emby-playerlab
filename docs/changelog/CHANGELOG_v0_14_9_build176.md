# OnePlayer 0.14.9 Build176

- Refines the Build175 episode-selector presentation from the 2026-08-25 real-device screenshot.
- Keeps the existing OnePlayer bottom control/button coordinates unchanged.
- Adds a localized black fade behind the episode panel so lower player function buttons no longer visually bleed through the episode overview text; this does not restore the rejected large gray/material sheet.
- Centers the current episode `正在播放` badge inside the 174x98 thumbnail. The resolving spinner follows the same centered thumbnail alignment.
- Season selection, episode card sizing, source-owned episode switching, automatic next-episode gating, STRM -> 302 -> 115/CDN client-direct transport, Range/206, session cache, MPV Seek, PiP Build173 behavior, and deployment target are unchanged.
- Deployment Target remains iOS 15.0; target real-device validation remains iPhone 15 Pro Max / iOS 17.0.
