# OnePlayer 0.14.8 Build175

- Refines the in-player episode selector from the Build174 real-device feedback.
- Keeps the existing OnePlayer bottom control/button layout unchanged; the episode UI is an overlay only and does not move the player function bar to follow the selector.
- Removes the Build174 selector title/series-name header and the explicit close button. Tapping the player area above the selector dismisses it.
- Removes the large material sheet appearance so the season selector and episode strip sit directly over the existing player control layer.
- Lets the selector use the player's normal landscape safe-area layout, keeping content away from the iPhone notch / Dynamic Island side inset.
- Adds a compact `第N季` menu. Opening it shows available seasons with the current selection marked; choosing another season filters the horizontal episode strip in place without changing playback.
- Opening the selector defaults to the season containing the currently playing episode. Switching playback to another episode re-synchronizes the selected season to the new current episode.
- Episode cards follow the existing detail-page episode-card information hierarchy: 174x98 landscape thumbnail, one-line episode title, and up to two lines of Emby `Overview` text.
- Keeps the current episode white outline and `正在播放` badge; selecting another card uses the existing full source-owned session replacement path.
- Automatic next-episode, PrematureEOFGuard gating, STRM -> 302 -> 115/CDN client-direct transport, Range/206, session cache, MPV Seek, PiP Build173 behavior, and deployment target are unchanged.
- Deployment Target remains iOS 15.0; target real-device validation remains iPhone 15 Pro Max / iOS 17.0.
