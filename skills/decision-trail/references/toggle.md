# Decision-trail toggle

Turns decision-trail tracking on or off, per branch, and installs the runtime on
first enable.

## Command

```bash
bash .agents/skills/decision-trail/scripts/toggle.sh [on|off] [branch]
```

- No `on|off` → flip the current effective state for the branch.
- No branch → the current checkout's branch.
- **Naming a branch other than the current checkout** writes the config change
  here, where it cannot govern that branch yet. The command says so and tells
  the user what to do: run it from that branch's worktree if one exists, or
  commit the config change onto that branch. Relay that instruction; do not
  report the toggle as already in effect there.
- Enabling runs `install-hooks.sh`: it materializes `.decision-trail/` (config,
  engine,
  git post-commit hook, Claude Code hook scripts), sets `core.hooksPath`, and
  prints the settings snippet for the optional enrichment gate.

Always report back the resulting state, the branch it applies to, and the
storage backend — the command prints exactly this. A silent flip on the wrong
branch is how trails quietly fail to happen, so never suppress that line.

## After enabling

Tell the user to commit `.decision-trail/` so hooks and config travel with the
branch and
into any worktrees:

```bash
git add .decision-trail && git commit -m "chore: enable decision-trail tracking"
```

If they want the Layer-2 enrichment gate (agents get prompted to explain commit
stubs before finishing), have them merge the printed hooks block into
`.claude/settings.json`. It is optional; the git hook captures rows regardless.

## Repos enabled before the rename

This skill was called `logic` until it was renamed to `decision-trail`. A repo
that enabled it earlier carries a committed `.logic/` runtime, a
`core.hooksPath` pointing into it, and — on the beads backend — rows labeled
`logic:<slug>`.

`toggle on` migrates all of that: it moves `.logic/` to `.decision-trail/`,
drops the stale `runtime/logic.sh`, repoints `core.hooksPath`, and relabels the
bd rows. Rows in the TSV fallback move with the directory, and re-running it
does nothing.

```bash
bash .agents/skills/decision-trail/scripts/migrate-legacy.sh --check  # is this repo legacy?
```

The bd relabel is the part that can come up short — an update can fail, or an
old `bd` can cap its own listing. So the migration re-queries afterwards and
reports what is left rather than a tally it cannot back up. If it warns, finish
the job with the relabel-only pass, which is safe to repeat and exits non-zero
until the trail is provably clean:

```bash
bash .agents/skills/decision-trail/scripts/migrate-legacy.sh --relabel
```

Relay that warning rather than summarising it away. A row still labeled
`logic:<slug>` is invisible to `show` — nothing queries that label any more.

Until the migration runs, the helpers read `.logic/` where it is, so a trail
stays visible rather than reporting the branch as untracked. That holds for
sibling worktrees too, so a repo migrating branch by branch keeps collecting
rows from the worktrees that have not moved yet. **The move is not
committed for the user** — tell them to commit it, or the next person on the
branch gets a `core.hooksPath` pointing at a directory that is not there:

```bash
git add -A .logic .decision-trail && git commit -m "chore: rename logic runtime to decision-trail"
```

If both `.logic/` and `.decision-trail/` exist, the migration refuses rather
than guessing which trail wins. Relay that message; do not pick one.

## Config and precedence

Tracking is governed by `.decision-trail/config.json` (see the `config-schema`
reference in the parent `decision-trail` skill). For the current branch,
precedence is: an exact branch key, a
glob key (`release/*`), then an enabled branch that is an **ancestor** of HEAD
(so a derived worktree branch forked from an enabled feature branch is tracked
and its rows are labeled with that feature branch), then the project `default`.

You can also edit config directly:

```bash
bash .agents/skills/decision-trail/scripts/config-edit.sh set default on
bash .agents/skills/decision-trail/scripts/config-edit.sh set-branch release/* off
bash .agents/skills/decision-trail/scripts/config-edit.sh set-storage some-branch tsv
```

## Toggle dirt is intended

`config.json` is committed, so enabling or disabling a branch shows up in that
branch's PR diff. That is a feature, not noise: the diff records that tracking
was on for the work under review.
