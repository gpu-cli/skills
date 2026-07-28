# Logic show

Shows the decision trail for a branch as a reviewable table. Default output is
the rendered table in the terminal; `--pr` also writes it into the PR
description. Safe to run on any branch, including ones that predate tracking.

When a branch is named, every step targets **that** branch — its commits, its
diff, its rows — regardless of which branch is currently checked out. So
`/logic show other-feature` from `main` reports that feature's trail, not
main's. If the name resolves to no ref, the helpers stop with an error rather
than quietly falling back to the current checkout.

All helper scripts live in `.agents/skills/logic/scripts/`.

## Procedure

### 1. Collect

```bash
bash .agents/skills/logic/scripts/collect.sh [branch] > /tmp/logic-rows.json
```

Returns a normalized JSON array of every row for the branch, merged across
worktrees and backends, sorted by time. Note the counts: total rows, and how
many are unenriched stubs (`.stub == true`).

### 2. Detect the tracking state — this decides everything below

- **Tracked, with rows** → go to step 3 with the real trail.
- **Tracked but zero rows** (`resolve-branch.sh` says `on`, collect is empty):
  call this out as a **compliance failure**, not a quiet reconstruction —
  usually the hook didn't fire. Then reconstruct so the user still sees
  something, clearly labeled.
- **Off entirely** (`resolve-branch.sh` says `off`, no rows): state plainly up
  front that tracking was **not enabled** for this branch, so what follows is a
  reconstruction from artifacts, not recorded decisions. Then reconstruct.
- **Partial** (rows exist but the branch predates them): show the real rows and
  reconstruct only the untracked span. Never blend real and inferred rows
  silently.

Check state with:

```bash
bash .agents/skills/logic/scripts/resolve-branch.sh --json
```

### 3. Validate evidence resolution and coverage

```bash
bash .agents/skills/logic/scripts/audit.sh [branch]
```

Reports rows whose evidence doesn't resolve and changed files no row explains.
Surface these as gaps; do not silently drop unresolved rows. This is a
mechanical check: a resolving commit or path anchors a decision but does not,
by itself, prove that the choice was sound.

### 4. Reconstruct (only when needed, per step 2)

```bash
bash .agents/skills/logic/scripts/reconstruct.sh [branch] > /tmp/logic-recon.json
```

This emits raw material only (commits + trailers, the diff, beads task issues,
PR body/comments) — it writes nothing. Turn it into inferred rows yourself:

- Reliability order: commit messages/trailers > diff grouped into units > beads
  task issues > PR text.
- Every inferred row is marked `actor=inferred`, and its `why` is phrased as a
  **hypothesis** ("likely because …"), never stated as fact. Its perceived
  decision confidence is `unknown`; never infer the original actor's certainty.
- Put a **warning banner** above any reconstructed table.
- Reconstruction is a **view, not a backfill** — never write inferred rows into
  beads. If the user wants to keep one, that is an explicit, separate follow-up
  where they confirm it and it's logged with them as the actor.

### 5. Conflicts across parallel worktrees

```bash
bash .agents/skills/logic/scripts/conflicts.sh [branch]
```

Returns mechanical pre-filters: **tier 1** (a file touched by rows from more than
one worktree) and **tier 2** (real textual conflicts from `git merge-tree`
between the worktree branches). Read the paired rows and make the **tier-3**
call yourself: is this a genuine semantic contradiction (e.g. two worktrees
chose opposite approaches for the same view)? Write a one-line tension note for
each real one. A clean result means "none detected", not "none exist" — say so.

### 6. Assess decision quality

Audit the choices, not every line of generated code. Use the diff, tests,
benchmarks, requirements, and other artifacts as evidence. Review only
load-bearing rows: architecture, security, data integrity, performance,
irreversible choices, and decisions already marked `low`, `INCONCLUSIVE`, or
`open`.

For each material choice, ask:

- What option was selected over what plausible alternative?
- What constraint, invariant, or assumption makes it valid?
- What boundary case or counterexample could break it?
- Does the evidence support the reason, or merely anchor where code exists?
- Does the decision need an owner ruling?

Confidence is the actor's perception, not a verdict. Pay special attention to
high-confidence rows with weak or anchor-only evidence, low-confidence
load-bearing choices, unresolved assumptions, contradictory rows, and
confidence that did not change after counterevidence.

Prepare a separate `## Decision quality` section after the trail. Use concise
notes, each naming the row or decision, its recorded confidence, the potentially
problematic area, and any owner ruling needed. Use `supported`,
`assumption-dependent`, `contradicted`, or `needs-owner-ruling` as assessment
labels. If no material concerns are detected, say so; do not manufacture notes.

This section is an assessment view, not stored history. If the owner rules on an
open item, record that ruling as a new append-only row with `logic track`.

### 7. Render

```bash
cat /tmp/logic-rows.json | bash .agents/skills/logic/scripts/render.sh --title "Decision trail — <branch>"
```

One Markdown table per stream (worktree), the current checkout first, with a
confidence column and stubs flagged. Follow it with conflict findings, evidence
gaps, and the separate Decision quality notes. If you reconstructed, keep
inferred rows in a separate, banner-headed section.

### 8. Cross-model review — before any outward push

Spawn a subagent on a **different model family** from the one that did the work
(self-review does not count; if no other family is available, say so and note
the review is same-family). It reads the trail, diff, and Decision quality
section. Have it pressure-test the closest alternative, controlling
assumptions, boundary cases, confidence/evidence mismatches, verification
claims, and risky choices. End with an **Attention** section that leads with the
reviewer's model on its own line, then the flags. `No flags` is valid; the model
name is not optional.

This review is **mandatory** whenever the trail contains inferred rows or you
are about to push to a PR; best-effort otherwise.

### 9. Optional: push to the PR

```bash
cat /tmp/logic-report.md | bash .agents/skills/logic/scripts/pr-push.sh [branch]
```

Assemble `/tmp/logic-report.md` from the rendered trail, evidence and conflict
findings, Decision quality notes, and Attention section. The helper writes the
complete report into the PR description between stable markers, so re-running
replaces the section instead of stacking copies. If the trail includes inferred
rows, keep the reconstruction warning in the pushed text.

### 10. Housekeeping

Offer to tidy rows whose branch was deleted unmerged:

```bash
bash .agents/skills/logic/scripts/gc.sh          # dry run, lists candidates
bash .agents/skills/logic/scripts/gc.sh --apply  # deletes them
```

## Closing offer

If tracking was off or partial, end by offering to turn it on
(`/logic toggle on`) so the rest of the branch gets a real trail.
