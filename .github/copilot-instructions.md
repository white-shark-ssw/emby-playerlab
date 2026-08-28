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
- once a development task is unambiguous and required pre-checks pass, continue autonomously through the available implementation/validation/commit/CI/IPA path until a user-testable IPA/Artifact is produced and its Build/source/artifact/package/MinOS identity is verified; do not stop at code completion, checks, commits, CI, packaging preparation, or checkpoints waiting for `继续` unless a real user decision/information need, conflict, external blocker, or missing execution capability prevents further progress;
- never claim CI/IPA success equals real-device success;
- update `docs/project/` after material development or test conclusions.

For source changes, use the repository skill `oneplayer-change-review` when applicable.
