# OnePlayer AI Coding Rules

This file is the repository-wide standing instruction for AI coding agents. It applies to all source changes unless a nearer, more specific instruction file explicitly overrides it.

## 1. Read before changing code

Before editing:

1. Read `docs/project/START_HERE.md`.
2. Read `docs/project/CURRENT_WORK.md` and route the session to the correct work lane.
3. For feature development, bugs, logs, real-device investigation, architecture implementation, CI or IPA work, read `docs/project/CURRENT_WORK_DEV.md`. For project-rule, documentation-governance, AI-instruction or Skill work, read `docs/project/CURRENT_WORK_RULES.md`.
4. If the selected lane is `Active`, resume from its recorded baseline and `Next exact action` instead of restarting the task from scratch. Do not modify or reset the other lane.
5. Read the current task's relevant entries in `docs/project/PROJECT_STATE.md`, `MODULE_STATUS.md`, and `TECHNICAL_DECISIONS.md`.
6. Resolve the actual functional test baseline: Build / PR / branch / commit. Do not assume `main` is the latest runtime baseline.
7. Inspect the real source definitions, call sites, state owners, and existing tests/logging before proposing a change.
8. If the source contradicts the initial hypothesis, change the hypothesis instead of forcing the planned patch.

If the user explicitly says the current session is for maintaining or modifying project rules, route to `CURRENT_WORK_RULES.md` even when `CURRENT_WORK_DEV.md` is also `Active`.

Do not invent API names, variables, functions, framework behavior, or source structure.

## 2. Evidence-first, minimal-change rule

Only change code when there is a concrete reason supported by source, logs, a reproducible failure, an explicit requirement, or a verified compatibility constraint.

Prefer the smallest change that fixes the identified problem while preserving established behavior.

Do not:

- refactor unrelated code while fixing one issue;
- add abstraction "for future use" without a current need;
- add fallback paths, retries, timers, watchdogs, recovery loops, or duplicate state "just in case";
- catch or suppress errors merely to make logs quiet;
- preserve obsolete behavior through compatibility shims unless compatibility is actually required;
- add a second owner for state already owned by another component;
- rewrite stable code only because another style looks cleaner;
- change public behavior without identifying which contract is intentionally changing.

If no justified code change is found, report that conclusion instead of manufacturing a patch.

## 3. Avoid over-defensive code

Defensive behavior must correspond to a specific failure mode.

For each new retry, fallback, timeout, guard, recovery branch, or state cache, be able to answer:

- What concrete failure does this handle?
- Which component owns the state?
- What proves the normal path is insufficient?
- How does the fallback terminate?
- Could it hide the real bug or create a second authority?

Prefer fixing the violated invariant at its owner rather than layering reconciliation around the symptom.

## 4. Frozen OnePlayer contracts

Check `docs/project/MODULE_STATUS.md` before touching a frozen module.

Unless the current task genuinely requires it, do not change:

- MPV fast Seek: one native `absolute+keyframes` seek;
- no hidden `absolute+exact` corrective seek;
- UnifiedTransport / Cache core semantics;
- real player byte demand as transport authority;
- iOS native Push/Pop and interactive-pop ownership;
- PiP Build173 architecture and its known accepted return-tail limitation.

Never reintroduce `targetTime / duration × fileSize` as a time-to-byte seek heuristic.

Never make the NAS relay actual media bytes. Normal media flow remains Emby/STRM → HTTP 302 → 115/CDN → iPhone.

## 5. Compatibility

Target device: iPhone 15 Pro Max / iOS 17.0.

Deployment Target should remain iOS 15.0 unless a required dependency or core API has a verified incompatibility. Explain the reason and attempted lower-version alternatives before raising it. Never raise the minimum above iOS 17.0.

Prefer mature lower-version APIs, UIKit / AVFoundation equivalents, `if #available`, and conditional degradation for non-core features.

Player, transport, cache, and Emby session lifecycles must not depend on SwiftUI view lifetime.

## 6. P0 playback invariants

Unrelated development must not regress:

- immediate left/right double-tap rewind/forward;
- rapid repeated double-tap response without debounce accumulation;
- configurable jump duration;
- STRM / HTTP 302;
- 115/CDN direct client playback;
- Range / 206;
- session cache;
- Emby progress / Resume sync;
- abnormal short-media / premature EOF tolerance;
- playback diagnostics;
- MPV main playback path.

## 7. Source and style discipline

- Preserve existing real API names and state ownership.
- Keep naturally short Swift statements/calls on one line; do not fragment them needlessly.
- Avoid broad formatting-only diffs.
- Do not silently change unrelated behavior while solving the requested task.
- Comments should explain non-obvious reasons or contracts, not restate obvious code.

## 8. Validation discipline

Before claiming success:

1. Review the diff for unintended scope expansion.
2. Check availability/minimum-iOS implications for any new API or dependency.
3. Run the narrowest meaningful validation first.
4. Do not spend GitHub Actions builds on every tiny intermediate edit when static/source validation is sufficient.
5. Run the necessary final CI/IPA workflow when the task reaches a testable baseline.

Always distinguish:

- Code written
- CI passed
- IPA produced
- Real-device tested
- Stable / frozen

Never describe CI success as proof that a runtime bug is solved.

## 9. Documentation and handoff are part of the change

For every important implementation, CI/IPA baseline, real-device result, architectural decision, rejection, freeze, or compatibility change, update the relevant files in `docs/project/` in the same work cycle.

For any multi-step task, activate the correct checkpoint lane early enough that the task can survive an unexpected conversation/context limit. Do not wait until the user predicts the limit or asks for a handoff.

- Development work uses only `docs/project/CURRENT_WORK_DEV.md`.
- Rule/documentation-governance work uses only `docs/project/CURRENT_WORK_RULES.md`.
- The two lanes may both be `Active` at the same time.
- Never overwrite, reset, or merge the other lane just because the current task finishes.

Create the first checkpoint as soon as the task goal and a usable baseline/working direction are known. Refresh the selected lane again at meaningful milestones such as baseline/branch confirmation, first effective patch or rule decision, CI/IPA change, user real-device result, or a material change of direction. The newest checkpoint should always be sufficient for a new session to continue without needing the previous chat.

Do not update checkpoints for every tiny edit. When a task finishes, move durable conclusions into the appropriate long-term project documents or permanent rule files and reset only the selected lane to `Idle`.

Do not wait for the user to request documentation maintenance or session handoff.
