# OnePlayer 0.14.34 / Build201

## Home carousel short-travel foreground slide

Build201 keeps the Build198 single UIKit begin/move/end/cancel owner and restores horizontal foreground motion after Build200 real-device feedback showed that a fixed foreground was a semantic regression.

Changes are deliberately scoped to the carousel visual mapping:

- foreground content remains directionally horizontal and continuously follows `transitionProgress`;
- total foreground travel is reduced from one full page width to `0.15 × page width`;
- outgoing/incoming foreground layers use the same linear `1-progress` / `progress` blend used by the backdrop;
- gesture acquisition, direction reversal, commit/cancel thresholds, settle timing and auto-advance ownership are unchanged;
- Player, MPV, PiP, Transport, Cache, Emby Session and STRM/302/115 paths are untouched.

Evidence basis:

- Build198 real-device behavior was otherwise correct, but minimum/subtle drag remained visibly coarser than EX;
- Build200 fixed-spatial foreground reduced motion but real-device testing rejected it because the foreground no longer slid horizontally;
- earlier target-device diagnostics showed first useful carousel movement samples around 4.33/8.00/15.67 pt while EX was visually around 1/1/2 px, supporting a materially shorter visual travel rather than removing translation entirely.

Evidence level at creation: **Code written; CI/IPA pending; real-device pending; not stable.**
