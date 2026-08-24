# OnePlayer 0.13.95 Build162

- PiP skip classifies AVKit's transient `setPlaying(false)` callback before `skipByInterval` and suppresses that synthetic pause when the skip callback arrives immediately, so MPV audio and the SampleBuffer visual timeline keep moving while the authoritative MPV seek lands.
- Genuine PiP pause remains supported: an unmatched pause callback commits after a 30 ms classification window; already-paused PiP seeks stay paused.
- PiP return arms the orientation hold before Home/background handoff instead of waiting for the restore callback.
- AVKit restore completion is delayed until the player window and PiP source host have reached the final target orientation and stable geometry for consecutive frames; only then is the system asked to expand PiP back into the inline destination.
- The restore path logs final window/host geometry and retains a bounded fallback so an abnormal orientation transition cannot strand system PiP.
- Build161 volume/brightness 1% deduplication remains unchanged.
- MPV native seek remains `absolute+keyframes`; UnifiedTransport, cache and STRM -> 302 -> 115 direct transport are unchanged.
- Deployment Target remains iOS 15.0; iOS 17.0 remains supported.
