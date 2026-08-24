# OnePlayer AI Coding Rules

This file is the repository-wide standing instruction for AI coding agents. It applies to all source changes unless a nearer, more specific instruction file explicitly overrides it.

## 1. Read before changing code

Before editing:

1. Read `docs/project/START_HERE.md`.
2. Read `docs/project/CURRENT_WORK.md`. If it is `Active`, resume from its recorded baseline and `Next exact action` instead of restarting the task from scratch.
3. Read the current task's relevant entries in `docs/project/PROJECT_STATE.md`, `MODULE_STATUS.md`, and `TECHNICAL_DECISIONS.md`.
4. Resolve the actual functional test baseline: Build / PR / branch / commit. Do not assume `main` is the latest runtime baseline.
5. Inspect the real source definitions, call sites, state owners, and existing tests/logging before proposing a change.
6. If the source contradicts the initial hypothesis, change the hypothesis instead of forcing the planned patch.

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

For any multi-step development **or rule/documentation-governance task**, make `docs/project/CURRENT_WORK.md` `Active` early enough that the task can survive an unexpected conversation/context limit. Do not wait until the user predicts the limit or asks for a handoff.

Create the first checkpoint as soon as the task goal and a usable baseline/working direction are known. Refresh it again at meaningful milestones such as baseline/branch confirmation, first effective patch or rule decision, CI/IPA change, user real-device result, or a material change of direction. The newest checkpoint should always be sufficient for a new session to continue without needing the previous chat.

Do not update it for every tiny edit. When the task finishes, move durable conclusions into the long-term project documents and reset `CURRENT_WORK.md` to `Idle`.

Do not wait for the user to request documentation maintenance or session handoff.
