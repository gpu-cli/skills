# Logic toggle

Turns decision-trail tracking on or off, per branch, and installs the runtime on
first enable.

## Command

```bash
bash .agents/skills/logic/scripts/toggle.sh [on|off] [branch]
```

- No `on|off` → flip the current effective state for the branch.
- No branch → the current checkout's branch.
- **Naming a branch other than the current checkout** writes the config change
  here, where it cannot govern that branch yet. The command says so and tells
  the user what to do: run it from that branch's worktree if one exists, or
  commit the config change onto that branch. Relay that instruction; do not
  report the toggle as already in effect there.
- Enabling runs `install-hooks.sh`: it materializes `.logic/` (config, engine,
  git post-commit hook, Claude Code hook scripts), sets `core.hooksPath`, and
  prints the settings snippet for the optional enrichment gate.

Always report back the resulting state, the branch it applies to, and the
storage backend — the command prints exactly this. A silent flip on the wrong
branch is how trails quietly fail to happen, so never suppress that line.

## After enabling

Tell the user to commit `.logic/` so hooks and config travel with the branch and
into any worktrees:

```bash
git add .logic && git commit -m "chore: enable decision-trail tracking"
```

If they want the Layer-2 enrichment gate (agents get prompted to explain commit
stubs before finishing), have them merge the printed hooks block into
`.claude/settings.json`. It is optional; the git hook captures rows regardless.

## Config and precedence

Tracking is governed by `.logic/config.json` (see the `config-schema` reference
in the parent `logic` skill). For the current branch, precedence is: an exact branch key, a
glob key (`release/*`), then an enabled branch that is an **ancestor** of HEAD
(so a derived worktree branch forked from an enabled feature branch is tracked
and its rows are labeled with that feature branch), then the project `default`.

You can also edit config directly:

```bash
bash .agents/skills/logic/scripts/config-edit.sh set default on
bash .agents/skills/logic/scripts/config-edit.sh set-branch release/* off
bash .agents/skills/logic/scripts/config-edit.sh set-storage some-branch tsv
```

## Toggle dirt is intended

`config.json` is committed, so enabling or disabling a branch shows up in that
branch's PR diff. That is a feature, not noise: the diff records that tracking
was on for the work under review.
