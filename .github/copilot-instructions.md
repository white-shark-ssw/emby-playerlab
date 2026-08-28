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
- once a development task is unambiguous and required pre-checks pass, continue autonomously through the available implementation/validation/commit/push/PR/CI/Artifact/IPA path until a user-testable Artifact/IPA is produced and its version, Build, Candidate, source, Artifact/package and MinOS identity is verified; do not stop at ordinary intermediate states waiting for `继续` unless a user decision/information/permission/real-device action, real conflict, insufficient evidence, external blocker, or missing execution capability genuinely prevents further progress;
- create the task checkpoint as soon as the goal and usable real baseline are known; do not delay it until CI/packaging/final conclusions. Refresh only at substantive independently resumable milestones, keeping branch/head/candidate, Completed, Validation state, Pending and Next exact action current; prefer piggybacking on already-needed GitHub writes and avoid a separate write for every micro-step;
- for non-atomic GitHub write chains such as blob → tree → commit → ref, do not checkpoint each operation. Only batch the group's partial state into one checkpoint after it has produced reusable persistent identity such as blob/tree/commit SHA, branch head, candidate or artifact ID and `Next exact action` has materially changed, so a new session can resume directly from the latest GitHub checkpoint;
- never claim CI/IPA success equals real-device success;
- update `docs/project/` after material development or test conclusions.

For source changes, use the repository skill `oneplayer-change-review` when applicable.
