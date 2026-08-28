# OnePlayer 0.14.59 / Build226

- Home carousel horizontal Hero-residency candidate based on Build225 real-device evidence.
- Keep current + previous + next clear Hero artwork resident while the current carousel item is settled so a horizontal drag can crossfade to either neighbor without mounting a new 1400px Hero presentation inside the active drag.
- After settle, residency rotates to the new current/previous/next set; the newly distant neighbor may mount outside the direct finger-tracking phase.
- Restore normal Hero current/target opacity blending during drag; normal persistent backdrop crossfade remains unchanged.
- Keep Build215 acquisition-relative motion, Build219 exact device-max refresh request, 0.28/0.48 release semantics, preload, and all Player/MPV/PiP/Transport/Cache/Session contracts unchanged.
- Diagnostic/performance candidate only until target-device testing; not stable.
