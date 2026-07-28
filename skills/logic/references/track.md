# Logic track

Records one decision in the branch's decision trail. This skill owns the **row
protocol** — the shape of a decision record and the rules for writing one. The
`logic toggle` and `logic show` skills and the capture hooks all defer to
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
- **confidence** — the actor's perceived confidence: `high`, `medium`, `low`, or
  `unknown`. It is not an objective correctness score and never replaces review.
- **evidence** — a pointer that proves it: a commit SHA, `file:line`, a PR
  number, or an artifact/trace/screenshot path. Never a paragraph.
- **result** — the outcome or state: `tests green`, `reverted`, `60fps`,
  `INCONCLUSIVE`, `open`.

Rows are append-only. A wrong call gets a new row that supersedes it; never
rewrite history. Storage (beads decision beads by default, TSV fallback) is an
engine detail — see the parent `logic` skill.

## Logging a decision

Run the log helper. It stamps the timestamp, resolves the logical branch, routes
to the right backend, and guards spreadsheet formula-injection bytes:

```bash
bash .agents/skills/logic/scripts/log.sh \
  --decision "kept the Metal flame shader" \
  --why "SwiftUI Canvas dropped to 40fps under load; Metal held 60" \
  --phase flame --confidence high \
  --evidence "benchmarks/flame-load.json" --result "60fps"
```

The `/logic track` command is the shorthand for the user's own decisions. Parse
the argument, then log it as the user:

```bash
# /logic track "kept Metal because Canvas dropped frames" --confidence high
bash .agents/skills/logic/scripts/log.sh --actor user --confidence high \
  "kept Metal because Canvas dropped frames"
```

The positional form splits on the first ` because ` into decision and why. Echo
the written row back to the user so they see exactly what was recorded.

## Confidence

Use a coarse assessment to avoid false precision:

- **high** — direct evidence tests the reason for the choice and no material
  assumption remains unresolved.
- **medium** — the choice has reasonable evidence but retains an untested
  assumption, boundary, or plausible alternative.
- **low** — the choice is tentative, weakly evidenced, or awaiting a ruling.
- **unknown** — confidence was not assessed, the row is a mechanical stub or
  legacy record, or a user did not state their confidence.

For your own consequential decisions, always pass `--confidence`. For a user's
decision, record their stated confidence; if they did not state it, use
`unknown` rather than inferring their mental state. A commit or path can anchor
where a choice landed without supporting why it was sound. When `why` makes a
performance, safety, or generality claim, prefer evidence that tests that claim.

## What to log, and when

Log decision points and checkpoints, not every action: a fork chosen, a unit
finished with its verification result, a pivot or revert with its trigger, a
blocker surfaced, a gate fixed. Skip the trivial and self-evident. Write each
row the way you'd tell a teammate what you did — plain words, concrete actions,
no AI-speak. A reviewer should read each row at a glance.

For a consequential fork, phrase the row as `chose X over Y`; name the
controlling constraint or assumption in `why`; and leave `result=open` or
`INCONCLUSIVE` when it has not been validated. Record later challenges,
counterexamples, pivots, and owner rulings as new rows instead of rewriting the
original call.

Commit stubs are captured for you: when tracking is on, a git hook records one
unenriched row per commit (its subject, no why). Your job is to give the ones
that represent a real decision a one-line why — either as you make them, or when
the enrichment gate prompts you before you finish:

```bash
bash .agents/skills/logic/scripts/log.sh --enrich <sha-or-bead-id> \
  --why "chose the streaming path so the HUD updates incrementally" \
  --confidence medium
```

This works on both backends: beads updates the record in place, and the TSV
fallback appends a superseding row for the same commit (the TSV log is
append-only). Leave purely mechanical commits (formatting, renames) as stubs;
gc removes them.

## Capturing the user's decisions

Some decisions are the user's, not yours: they picked an approach, rejected a
suggestion, or made a scope call. When that reasoning isn't already stated and
tracking is on:

- **Interactive session:** ask the user for one line explaining the call (use
  the host's question affordance), then log it with `--actor user`. Capture
  confidence only if the user states it.
- **Unattended / background run:** do not block waiting for a human. Log the row
  with `--actor user --confidence unknown` and leave the why empty (it becomes a
  pending row);
  `logic show` surfaces pending rows for later annotation.

Never invent a user's rationale or confidence. An honest pending row beats a
plausible fiction.

## Do not log when tracking is off

If tracking is off for the branch, the helper refuses and says so. That is
correct — don't force rows onto untracked branches. Turn tracking on first with
`/logic toggle on` if the branch should be tracked.
