# OnePlayer Documentation Policy

## Purpose

This directory is the authoritative handoff layer for ongoing OnePlayer development. Long exported chat histories are historical evidence, not the normal source of truth for day-to-day development.

## Required documents

- `PROJECT_STATE.md` — what the project is **now**.
- `TECHNICAL_DECISIONS.md` — decisions that must not be rediscovered or casually reversed.
- `BUILD_TEST_INDEX.md` — important build/CI/IPA/real-device milestones.
- `MODULE_STATUS.md` — module-level status, frozen areas, known issues and next work.

## Update rule

For every material development iteration, update the relevant project documents in the same development cycle.

A material iteration includes any of the following:

- a new test IPA that changes runtime behaviour;
- a real-device result that confirms or rejects a hypothesis;
- a change to player, transport, cache, Emby session/progress, PiP, navigation or compatibility architecture;
- a dependency or minimum-iOS change;
- a decision to freeze, abandon or replace an approach.

Do **not** wait for a separate documentation request.

## Evidence levels

Never collapse these into one state:

1. **Code written** — implementation exists.
2. **CI passed** — source/build validation passed.
3. **IPA produced** — installable artifact exists.
4. **Real-device tested** — user tested it on target hardware.
5. **Stable / frozen** — result is accepted as the current contract.

CI success or an IPA artifact is never enough to claim a runtime issue is solved.

## Compatibility contract

- Target device: iPhone 15 Pro Max.
- Required real-device OS: iOS 17.0.
- Deployment Target should remain iOS 15.0 unless a concrete dependency/API limitation requires raising it.
- Deployment Target must never be raised above iOS 17.0.
- Do not raise the minimum OS merely for UI convenience.

## History handling

The original exported chat documents v1-v19 are historical archives. Keep them for traceability, but normal handoff should begin with the four authoritative files in `docs/project/`.

When a historical detail is disputed, use this priority:

1. newer real-device result;
2. current source code / branch;
3. CI/IPA evidence;
4. older chat-plan text.

A plan written in an old export is not proof that the change was implemented.
