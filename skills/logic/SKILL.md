---
name: logic
description: "Use when the user wants to start or stop recording a branch decision trail, record a decision and its rationale, or show and audit the rationale behind a branch or PR. Invoke as /logic toggle, /logic track, or /logic show. Captures decisions across concurrent worktrees, validates evidence, and can add a reviewable trail to a PR."
---

# Logic

Keep one reviewable, append-only decision trail for a branch worked by people
and agents. The trail records what was decided, why, perceived confidence,
evidence, and outcome. It uses `bd` when available and falls back to TSV.

Use one command namespace:

```text
/logic <command> [arguments]
```

| Command | Use for | Read |
| --- | --- | --- |
| `toggle [on|off] [branch]` | Start or stop tracking for a branch | [references/toggle.md](references/toggle.md) |
| `track "<decision> because <why>" [--confidence high|medium|low]` | Record or enrich a decision | [references/track.md](references/track.md) |
| `show [branch] [--pr]` | Render, validate, and optionally publish a trail to its PR | [references/show.md](references/show.md) |

Route the first argument to its reference. With no argument, show this command
table and ask which operation is wanted. Treat an unrecognized argument as a
request to show the current branch's trail.

## Shared runtime

All helpers live in `.agents/skills/logic/`. Read
[references/config-schema.md](references/config-schema.md) only when changing
tracking configuration, and [references/row-format.md](references/row-format.md)
only when changing row semantics. Run the relevant helper rather than manually
editing `.logic/` state.

`toggle on` materializes a committed `.logic/` runtime and configures Git's
relative `core.hooksPath`. Tell the user to commit `.logic/` after enabling it.
The optional Claude Code Stop hook enriches meaningful commit stubs; the Git
post-commit hook captures the stubs regardless.

## Validation

Run `bash tests/selftest.sh` after changing the bundled runtime.
