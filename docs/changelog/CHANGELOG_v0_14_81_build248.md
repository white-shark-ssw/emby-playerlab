# OnePlayer 0.14.81 / Build248

Search target-device follow-up candidate after Build247.

- Correct Search Dock vertical alignment after moving Dock ownership to `EmbyServerRootViewV3`; keep the real Dock outside the keyboard-responsive Search navigation tree while accounting for the physical bottom safe-area inset.
- Bound startup recommendation work to the visible 3×3 Search recommendation wall: at most 9 `Movie` / `Series` items.
- Each Emby Suggestions request asks only for the remaining visible slots instead of requesting 100 items per library, preventing the startup preloader from blocking the Search landing page on oversized recommendation responses.
- Returned-item `Movie` / `Series` whitelist remains authoritative.
- Existing `EmbyImageDiskCache` and `EmbyDecodedImageRenderPool` remain the only Search poster cache authorities.
- No Search recommendation load-more during scrolling.
- No Player/MPV/PiP, UnifiedTransport, playback Session Cache, STRM/302/115 client-direct path, Emby Resume/progress, shared poster-grid owner, or Deployment Target change. MinOS remains iOS 15.0.

Evidence at source creation: code written only; CI/IPA and target-device validation pending.
