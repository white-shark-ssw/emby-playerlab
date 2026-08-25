# OnePlayer Copilot Instructions

Follow the repository-wide rules in `AGENTS.md`.

Before coding, read `docs/project/START_HERE.md` and resolve the actual current Build / PR / branch. Do not assume `main` is the latest functional test baseline.

Key rules:

- inspect real source and call sites before editing; never invent APIs or state ownership;
- make the smallest justified change; no drive-by refactors;
- do not add speculative retries, fallbacks, timers, watchdogs, duplicate state, compatibility shims, or abstractions without a concrete failure/requirement;
- if no justified code change is found, say so rather than manufacturing one;
- respect Frozen modules in `docs/project/MODULE_STATUS.md`;
- preserve iOS 15.0 Deployment Target unless a verified dependency/API requirement forces a change; never exceed iOS 17.0;
- never make the NAS relay media bytes;
- never restore time→byte proportional seek guessing;
- never claim CI/IPA success equals real-device success;
- update `docs/project/` after material development or test conclusions.

For source changes, use the repository skill `oneplayer-change-review` when applicable.
