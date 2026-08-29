# OnePlayer 0.14.83 / Build250

Search recommendation follow-up after Build249 target-device log evidence.

- Preserve the Build248-accepted Search Dock position and keyboard behavior.
- Fix recommendation acceptance when Emby Suggestions returns items without a decoded `Type`: keep server-side `IncludeItemTypes` restricted to Movie/Series and treat that exact request whitelist as authoritative only when the returned item omits `Type`; when `Type` is present it must still be Movie or Series.
- Stop the serial library scan as soon as the first eligible library fills the 3×3 recommendation wall.
- Add `nilType` and requested-type diagnostics to prove the response shape on device.
- No Player, Transport, playback Session Cache, PiP, Resume/progress, credentials, shared poster-grid, or Deployment Target changes.

Evidence at changelog creation: code written; CI/IPA and target-device validation pending.
