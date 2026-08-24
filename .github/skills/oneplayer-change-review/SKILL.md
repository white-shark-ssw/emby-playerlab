---
name: oneplayer-change-review
description: Evidence-first preflight and self-review for implementing or reviewing OnePlayer source changes. Use for code modifications, bug fixes, compatibility work, player/transport/cache/PiP/navigation changes, or before finalizing a PR.
---

# OnePlayer Change Review

Use this workflow before and after changing source code.

## A. Preflight

1. Resolve the task's exact Build / PR / branch / commit and relevant real-device evidence.
2. Read `AGENTS.md`, `docs/project/START_HERE.md`, and the relevant module status/technical decisions.
3. Inspect the actual source definitions, callers, state owners, and logs/tests involved.
4. Write down the invariant that is failing or the explicit behavior that must change.
5. Decide the smallest code surface that can satisfy the requirement.

If the evidence does not justify a change, stop and report that rather than adding speculative code.

## B. Reject common bad patches

Before implementing, reject a proposed patch if it relies on any of these without concrete evidence:

- guessed API/function/property names;
- unrelated refactoring;
- duplicate state ownership;
- broad "safety" wrappers around a known state owner;
- silent error swallowing;
- generic catch-all fallback;
- repeated retry/reconcile loops with no bounded termination;
- timers/watchdogs added to hide a lifecycle bug;
- compatibility shims for behavior that no longer needs compatibility;
- speculative future-proof abstractions;
- hidden second Seek/correction path;
- time→byte proportional seek guesses;
- NAS media-byte relay;
- new API/dependency that silently raises minimum iOS.

## C. Implementation review

After editing, inspect the diff and verify:

1. Every changed line contributes to the requested behavior or required validation.
2. Stable/Frozen modules were not modified accidentally.
3. Existing state ownership remains single and clear.
4. New defensive branches map to a documented real failure mode and terminate predictably.
5. No unrelated formatting churn was introduced.
6. Short expressions/calls remain naturally compact.
7. Logs are diagnostic rather than noisy, and errors are not hidden.

## D. Compatibility and validation

Check:

- iOS 15.0 Deployment Target;
- iOS 17.0 target-device compatibility;
- arm64/device framework compatibility for dependency changes;
- Swift/API availability;
- Range/302/direct-CDN behavior if networking is touched;
- MPV fast Seek and other P0 invariants if player code is touched.

Run the narrowest meaningful checks first. Run final CI/IPA only when there is a coherent test baseline.

## E. Evidence label

At completion, explicitly classify the result as one or more of:

- Code written
- CI passed
- IPA produced
- Real-device tested
- Stable / frozen

Never promote a result to a higher evidence level without proof.

## F. Documentation

If the change or test result materially changes project knowledge, update the relevant files under `docs/project/` in the same work cycle.
