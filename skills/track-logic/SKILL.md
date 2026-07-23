---
name: track-logic
description: "Use to record a decision in the branch's decision trail — why a fork was chosen, an approach rejected, a scope call made — by you or on the user's behalf. Owns the row protocol the whole logic suite shares. Invoke as /track-logic \"<what> because <why>\", and follow its capture rules whenever tracking is on for the branch."
argument-hint: "[<decision> because <why>]"
user-invocable: true
license: Apache-2.0
---

# track-logic

Records one decision in the branch's decision trail. This skill owns the **row
protocol** — the shape of a decision record and the rules for writing one. The
`toggle-track-logic` and `show-logic` skills and the capture hooks all defer to
this definition; do not restate it elsewhere.

A decision trail lets a reviewer reconstruct what was decided, why, and on what
evidence, without rerunning the work or reading the whole transcript. It is
built for branches worked by several agents and the user at once, so every row
is attributed and scoped to a branch.

## The row

One decision per row. Fields:

- **ts** — ISO8601 timestamp. Set automatically.
- **actor** — who decided: `user`, a person's name, or an agent id. Set
  automatically from the environment; pass `--actor` to override.
- **phase** — the workstream or component (e.g. `flame`, `auth`, `render`).
- **decision** — what was chosen or done, one line.
- **why** — the reason in plain words. If a principle drove it, say it plainly
  (`explored options first, this was a one-way door`), not as a jargon tag.
- **evidence** — a pointer that proves it: a commit SHA, `file:line`, a PR
  number, or an artifact/trace/screenshot path. Never a paragraph.
- **result** — the outcome or state: `tests green`, `reverted`, `60fps`,
  `INCONCLUSIVE`, `open`.

Rows are append-only. A wrong call gets a new row that supersedes it; never
rewrite history. Storage (beads decision beads by default, TSV fallback) is an
engine detail — see the `logic-core` skill.

## Logging a decision

Run the log helper. It stamps the timestamp, resolves the logical branch, routes
to the right backend, and guards spreadsheet formula-injection bytes:

```bash
bash .agents/skills/logic-core/scripts/log.sh \
  --decision "kept the Metal flame shader" \
  --why "SwiftUI Canvas dropped to 40fps under load; Metal held 60" \
  --phase flame --evidence "commit 7c21e0a" --result "60fps"
```

The `/track-logic` command is the shorthand for the user's own decisions. Parse
the argument, then log it as the user:

```bash
# /track-logic "kept Metal because Canvas dropped frames"
bash .agents/skills/logic-core/scripts/log.sh --actor user "kept Metal because Canvas dropped frames"
```

The positional form splits on the first ` because ` into decision and why. Echo
the written row back to the user so they see exactly what was recorded.

## What to log, and when

Log decision points and checkpoints, not every action: a fork chosen, a unit
finished with its verification result, a pivot or revert with its trigger, a
blocker surfaced, a gate fixed. Skip the trivial and self-evident. Write each
row the way you'd tell a teammate what you did — plain words, concrete actions,
no AI-speak. A reviewer should read each row at a glance.

Commit stubs are captured for you: when tracking is on, a git hook records one
unenriched row per commit (its subject, no why). Your job is to give the ones
that represent a real decision a one-line why — either as you make them, or when
the enrichment gate prompts you before you finish:

```bash
bash .agents/skills/logic-core/scripts/log.sh --enrich <sha-or-bead-id> \
  --why "chose the streaming path so the HUD updates incrementally"
```

Leave purely mechanical commits (formatting, renames) as stubs; gc removes them.

## Capturing the user's decisions

Some decisions are the user's, not yours: they picked an approach, rejected a
suggestion, or made a scope call. When that reasoning isn't already stated and
tracking is on:

- **Interactive session:** ask the user for one line explaining the call (use
  the host's question affordance), then log it with `--actor user`.
- **Unattended / background run:** do not block waiting for a human. Log the row
  with `--actor user` and leave the why empty (it becomes a pending row);
  `show-logic` surfaces pending rows for later annotation.

Never invent a user rationale. An honest pending row beats a plausible fiction.

## Do not log when tracking is off

If tracking is off for the branch, the helper refuses and says so. That is
correct — don't force rows onto untracked branches. Turn tracking on first with
`/toggle-track-logic on` if the branch should be tracked.
