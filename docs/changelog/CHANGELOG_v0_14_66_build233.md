# OnePlayer 0.14.66 / Build233

- Home carousel acquisition-first-frame A/B based on Build232 real-device/log evidence.
- Retains Build231 foreground `compositingGroup()`, Build226 three-slot Hero residency, Build228 max-refresh-through-settle, original persistent current+target behavior, and existing 0.28 / 0.48 release rules.
- When horizontal ownership is acquired, uses only the immediately preceding real coalesced touch sample from the same `UIEvent` as a one-time render baseline when it continues in the already-selected horizontal direction, then publishes the current delivered touch immediately.
- After acquisition, delivered touches remain the sole interactive render driver; predicted touch remains release-only. No timer, interpolation, step cap, easing, debounce, throttle, retry, watchdog or second state owner is added.
- If no suitable preceding coalesced sample exists, the Build232 acquisition-relative behavior is preserved.
- Build232 cadence fields remain available to verify the first visible step on target device.
- Player / MPV / PiP / Transport / Cache / Emby Session / STRM→302→115/CDN and all Frozen/P0 paths remain unchanged.
