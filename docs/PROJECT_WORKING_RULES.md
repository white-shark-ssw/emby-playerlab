# OnePlayer Project Working Rules

## Conversation handoff

When the active development conversation is becoming too large to safely preserve all project context, proactively tell the user before continuing major work.

The user will export the complete conversation as a Markdown document and add it to the project materials. After that, future work should read the newest exported project document first and continue from its verified GitHub branch/commit state.

Do not wait until context is already lost before giving this reminder.

## Source-of-truth discipline

- Repository source after the architecture flattening is the build source. Do not reintroduce historical patch-on-patch materializers into production builds.
- Frozen product/UI rules belong in `docs/architecture/` and should be enforced by CI invariants when practical.
- When a new change conflicts with a frozen rule, stop and resolve the conflict explicitly instead of silently redefining the rule.
