# OnePlayer ChatGPT Project Instructions v3

GitHub repository: `white-shark-ssw/emby-playerlab`.

For every new OnePlayer development session:

1. Read repository root `AGENTS.md`.
2. Read `docs/project/START_HERE.md`.
3. Follow the current state in `docs/project/`; do not ask the user to re-upload or re-explain v1-v19.
4. Read historical `docs/history/chat-exports/v01.md ... v19.md` only when current authoritative docs cannot resolve a historical issue.

Authority order when sources conflict:

1. user's latest real-device result;
2. current real source / exact test branch;
3. CI / IPA evidence;
4. current `docs/project/`;
5. old chat exports/plans.

Before editing code, inspect the real definitions/call sites/state ownership. Never guess API, variable, function, or framework behavior. Make the smallest evidence-backed change. Do not add speculative retries, fallbacks, timers, watchdogs, duplicate state, compatibility shims, abstractions, or unrelated refactors "just in case". If evidence does not justify a code change, say so instead of manufacturing one.

Read `MODULE_STATUS.md` before touching Frozen areas. Preserve P0 playback and transport contracts, including immediate double-tap Seek, STRM/302, 115/CDN direct client playback, Range/206, session cache, Emby progress/Resume, abnormal-media tolerance, diagnostics, and MPV main playback. NAS must never relay media bytes. Never restore time→byte proportional seek guessing.

Target device is iPhone 15 Pro Max / iOS 17.0. Deployment Target should remain iOS 15.0 unless a verified dependency/core-API limitation requires raising it; explain why and attempted alternatives first. Never raise it above iOS 17.0. Prefer lower-version APIs, UIKit/AVFoundation equivalents, `if #available`, and non-core conditional degradation. Player core lifecycle must not depend on SwiftUI.

Do not assume `main` is the latest functional baseline. When logs are provided, analyze the exact Build/branch source. Keep naturally short code on one line.

Always distinguish: Code written / CI passed / IPA produced / Real-device tested / Stable or frozen. Never call CI success a solved runtime bug.

After every material implementation, CI/IPA baseline, real-device result, architectural decision, rejection, freeze, dependency change, or compatibility change, proactively update the relevant GitHub `docs/project/` files in the same work cycle. Do not wait for the user to request documentation maintenance.
