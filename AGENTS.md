# OnePlayer AI Coding Rules

This file is the repository-wide standing instruction for AI coding agents. It applies to all source changes unless a nearer, more specific instruction file explicitly overrides it.

## 0. Every final reply must trigger ChatGPT-Notify

Every new OnePlayer session must read `docs/automation/CHATGPT_NOTIFY_RULES.md` before doing project work.

**Every user-facing final reply must trigger exactly one completion notification before the final reply is emitted.** Do not filter by task importance, elapsed time, code changes, answer length, question type, CI/IPA activity, or whether the reply is only a greeting / simple fact / short clarification.

Only non-final process messages are excluded: commentary, tool-progress updates, and incomplete “working/checking” messages do not trigger separate notifications.

The notification sequence is mandatory:

1. finish all work, validation, and required project-document updates;
2. prepare the final answer;
3. follow `docs/automation/CHATGPT_NOTIFY_RULES.md` to create the `BARK_NOTIFY_V1` top-level comment in `white-shark-ssw/ChatGPT-Notify` PR `#1`;
4. immediately redact that same comment using the returned comment id;
5. only then emit the final reply.

Notification failure must not be fabricated as success. Follow the detailed failure/privacy rules in `docs/automation/CHATGPT_NOTIFY_RULES.md`.

Repository-rule changes do not retroactively inject themselves into already-open conversations. An existing conversation that predates this rule must re-read `AGENTS.md` and `docs/automation/CHATGPT_NOTIFY_RULES.md` once before this guarantee can apply to subsequent replies in that conversation.

## 1. Read and route before changing code

Before editing:

1. Read `docs/project/START_HERE.md`.
2. Read `docs/project/CURRENT_WORK.md` and route the session type first.
3. Explicit routing aliases: `当前为规则会话` means Rules; `当前为开发会话` or `当前为功能会话` means Development/Feature. Clear equivalent wording has the same effect.
4. A bare, concrete feature name such as `详情页优化` may identify both a Development/Feature session and an existing feature task, but only when it uniquely and strongly matches one Active development checkpoint through its Work ID, Task name, or explicit `Routing aliases / keywords`.
5. If the user's current message does not clearly identify Rules vs Development/Feature, stop and ask the user to choose. Do not guess, activate a task, switch a branch, or start work until the user chooses.
6. Session/task `Active` state is not sufficient routing evidence. Do not infer intent from prior-chat topic, recency, urgency, or model preference.
7. Rules work uses `docs/project/CURRENT_WORK_RULES.md`.
8. Development work first reads `docs/project/CURRENT_WORK_DEV.md`, then selects one concrete task under `docs/project/current/dev/<Work-ID>.md`.
9. For an existing development task, selection priority is: exact Work ID → clear Task name → explicit `Routing aliases / keywords` → one uniquely explainable strong keyword match. If zero or multiple Active tasks match, or the match is only fuzzy semantic similarity, list candidates and ask the user to choose. Never create a new task merely because no existing task matched.
10. Even one Active task is not enough to assume continuation when the user's message does not uniquely identify it.
11. Before a concrete development task is selected, do not create or modify a development checkpoint and do not create, switch to, or reuse a feature branch.
12. After a development task is selected, perform a resume identity guard before editing code: verify the checkpoint's branch / PR / head identity and any allocated Build/version/IPA candidate against current GitHub facts and other Active checkpoints. If there is a mismatch or duplicate branch/Build identity, stop and report it instead of guessing which record is correct.
13. If the selected task is Active and the identity guard passes, resume from its recorded baseline and `Next exact action` instead of restarting from scratch. Do not modify another task's checkpoint.
14. Read the current task's relevant entries in `docs/project/PROJECT_STATE.md`, `MODULE_STATUS.md`, and `TECHNICAL_DECISIONS.md`.
15. Resolve the actual functional test baseline: Build / PR / branch / commit. Do not assume `main` is the latest runtime baseline.
16. Inspect the real source definitions, call sites, state owners, and existing tests/logging before proposing a change.
17. If the source contradicts the initial hypothesis, change the hypothesis instead of forcing the planned patch.

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

## 8. Parallel development discipline

Multiple feature-development sessions are allowed only with task isolation.

Each Active feature task must have:

- a unique Work ID;
- its own `docs/project/current/dev/<Work-ID>.md` checkpoint;
- stable `Routing aliases / keywords` for safe human-friendly task selection;
- its own development branch;
- its own PR once it reaches review/test stage;
- a unique Build/version candidate identity when a test build is allocated.

Two Active feature tasks must never share the same development branch.

Before creating a new parallel feature task, inspect every other Active development checkpoint for overlap in files/modules, state owners, Frozen contracts, or dependencies.

If two tasks may modify the same source file, the same state owner, a shared Frozen/P0 core path, or one depends on another unmerged task, do not silently proceed in parallel. Tell the user there is a conflict risk. Prefer serial work; if dependency work is intentional, record it explicitly as stacked/dependent work.

Git mergeability is not proof that parallel architectural state ownership is safe.

Before assigning a test Build/version candidate, inspect `docs/project/BUILD_TEST_INDEX.md`, other Active development checkpoints, and existing CI/IPA candidates. Do not reuse a Build number or IPA candidate name already allocated to another Active task. Once an Active task records a candidate, treat that identity as reserved until the task explicitly releases/completes it and project state is updated.

Before final CI/IPA/merge, check whether the target branch advanced due to another parallel task. If synchronization materially changes the code or dependencies, rerun affected validation. Old CI does not prove the synchronized code passes.

## 9. Validation discipline

Before claiming success:

1. Review the diff for unintended scope expansion.
2. Check availability/minimum-iOS implications for any new API or dependency.
3. Run the narrowest meaningful validation first.
4. Do not spend GitHub Actions builds on every tiny intermediate edit when static/source validation is sufficient.
5. Run the necessary final CI/IPA workflow when the task reaches a testable baseline.

### Continuous execution to a testable artifact

Once a development task is unambiguous and all necessary routing, resume-identity, branch/Build collision, source/state-owner, Frozen/P0, evidence, and other pre-change checks have passed, **continue autonomously within the current environment's real execution capabilities until a user-testable Artifact/IPA exists and the applicable version, Build, Candidate, source, and Artifact identities have been verified.**

Do not stop merely because code is written, a check passed, a commit/push was completed, a PR exists or advanced, CI was started or passed, a checkpoint was refreshed, or packaging is being prepared, and then wait for the user to say `继续`. These are ordinary intermediate states. A checkpoint preserves recoverability; it is not a normal handoff gate.

A development task may stop before Artifact/IPA handoff only when at least one of these is real and material:

- a decision, information, authorization, credential, permission, test input, or real-device operation must genuinely come from the user;
- the current evidence contains a real conflict or ambiguity that cannot be resolved safely from repository facts;
- evidence is insufficient to justify the next code change, select between materially different directions, or claim a testable candidate without guessing;
- an external blocker such as unavailable CI/infrastructure, a failed required service, or an unresolvable dependency prevents further progress;
- the current environment genuinely lacks a capability required for the next step.

When evidence is insufficient, do not manufacture a patch merely to preserve forward motion. Record what is known, what is missing, and the exact evidence or user/runtime action needed next.

Otherwise, continue through the applicable implementation, validation, commit/push, PR, CI, Artifact/IPA generation, artifact retrieval/inspection, and identity checks without asking for an intermediate `continue`. Before handing the build to the user, verify the applicable product version, Build number, Candidate identity, branch/PR/head or tested source commit, Artifact identity/digest, IPA/package identity, and MinOS. The normal handoff point is then **Runtime/real-device testing**.

This rule does not authorize bypassing evidence, minimal-change, Frozen/P0, compatibility, or parallel-task guards. A generated and identity-verified Artifact/IPA is still only `IPA produced`; it must never be described as `Real-device tested` or `Stable / frozen` until the required user/runtime evidence exists.

Always distinguish:

- Code written
- CI passed
- IPA produced
- Real-device tested
- Stable / frozen

Never describe CI success as proof that a runtime bug is solved.

## 10. Documentation and handoff are part of the change

For every important implementation, CI/IPA baseline, real-device result, architectural decision, rejection, freeze, or compatibility change, update the relevant files in `docs/project/` in the same work cycle.

For any multi-step task, create the correct checkpoint early enough to survive an unexpected conversation/context or execution limit. Do not wait until CI, packaging, a final conclusion, the user predicting a limit, or an explicit handoff request.

- Rules work uses only `docs/project/CURRENT_WORK_RULES.md`.
- Each development task uses only its own `docs/project/current/dev/<Work-ID>.md`.
- Rules and multiple development tasks may all be Active at the same time.
- Never overwrite, reset, merge, or repurpose another task's checkpoint because the current task finishes.
- Never create/activate a checkpoint until session type and concrete task identity are unambiguous.

As soon as the task goal and a usable real baseline/working direction are known, create the first checkpoint. Continuous autonomous execution does **not** permit delaying checkpoint creation until CI, Artifact/IPA production, or the final conclusion.

Refresh the selected checkpoint only at substantive milestones that have independent continuation value. At minimum, keep the checkpoint sufficiently current to recover the task's branch/head/candidate identity, `Completed`, `Validation state`, `Pending`, and `Next exact action`. Useful refresh points include a confirmed baseline/branch/head/candidate, the first effective patch or rule decision, a material direction/evidence change, CI/Artifact state that changes the next action, or a new user real-device result.

Prefer to piggyback checkpoint updates on GitHub writes that are already necessary for the task when the checkpoint state has materially changed. Do not create a separate GitHub write for every tiny edit, command, check, or micro-step. Pace checkpoints so that an unexpected context/execution cutoff should lose at most one small meaningful milestone rather than the whole implementation-to-CI/packaging span.

When a development task finishes, move durable conclusions into the long-term project documents and remove only that task's current checkpoint. When a rules task finishes, move durable rules into permanent rule files and reset only `CURRENT_WORK_RULES.md` to Idle.

Do not wait for the user to request documentation maintenance or session handoff.
