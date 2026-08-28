# OnePlayer 0.14.63 / Build230

## Purpose

Diagnostic-only build to correlate the user's intermittent Home vertical "sudden twitch" with real `UIScrollView` motion and the existing Home carousel auto-advance / settle lifecycle.

## Baseline

- Based exactly on Build229 / 0.14.62 source `f5e3e3eb144578c863b172e3bd3a1aa13e5c2177`.
- Build229 Library snapshot off-main behavior remains unchanged.
- This build does not claim a smoothness fix.

## Runtime diagnostic changes

- Adds one Home-only `CADisplayLink` observer attached to the already-owned real vertical `UIScrollView` while that observer is mounted.
- Logs `HomeVerticalHitch` when Home is moving and either:
  - the display-link gap reaches at least 18 ms; or
  - `contentSize.height` / `adjustedContentInset.top` changes enough to indicate a layout shift.
- Each hitch line includes vertical phase, offset delta, pan velocity, content-height delta, inset delta, and age of the latest carousel auto-start / settle event.
- Adds `HomeCarouselTiming` markers at automatic carousel transition start and around the existing `settleCarousel` state commit so the App log can separate animation-start, settle-state and unrelated vertical hitches.

## Explicitly unchanged

- Auto-advance eligibility remains 6 seconds after the last settle.
- Automatic carousel animation remains `.easeInOut(duration: 0.62)`.
- Existing settle callback remains scheduled at `+0.63` seconds.
- Horizontal gesture thresholds, release rules and carousel presentation semantics are unchanged.
- Home rows, Library pagination, persistent-cache schema/content, poster image policy and Build229 off-main Library snapshot persistence are unchanged.
- Player / MPV / PiP / UnifiedTransport / Range/206 / playback Cache / Emby Session / STRM→302→115/CDN client-direct contracts are untouched.
- Deployment Target remains iOS 15.0.

## Evidence level

At source-write stage only: **Code written**. CI, IPA and target-device evidence must be recorded separately after they exist.
