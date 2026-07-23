---
name: logic-core
description: "Shared engine for the decision-trail suite (track-logic, toggle-track-logic, show-logic). Not invoked directly — it provides the storage, config, branch resolution, capture hooks, and read/audit/reconstruct helpers the three commands call. Read this to understand or maintain the runtime."
user-invocable: false
license: Apache-2.0
---

# logic-core

The engine behind the decision-trail suite. The three user commands are thin
fronts over the scripts here:

- **track-logic** → `scripts/log.sh` (log / enrich a row)
- **toggle-track-logic** → `scripts/toggle.sh`, `scripts/install-hooks.sh`
- **show-logic** → `scripts/collect.sh`, `render.sh`, `audit.sh`,
  `reconstruct.sh`, `conflicts.sh`, `gc.sh`, `pr-push.sh`

All scripts source `scripts/lib.sh` and assume only `git` (plus `jq` and `bd`
when present). Nothing here has side effects on source; each does one job.

## Where state lives

Runtime state lives in a committed `.logic/` directory at the consumer repo
root — never in the skill directory, because installs land in gitignored
`.agents/skills/` and are absent from git worktrees. `install-hooks.sh`
materializes `.logic/` so the git hook and config travel with the branch:

```
.logic/
  config.json          # tracking config (committed; edits show in the PR diff)
  runtime/logic.sh     # engine copy the hooks source (worktree-safe)
  githooks/post-commit  # Layer-1 mechanical stub capture
  hooks/session-start.sh, stop-gate.sh   # Layer-2 Claude Code hooks
  audit/<branch>/<actor>.tsv             # TSV fallback (gitignored by default)
```

`core.hooksPath` is set to `.logic/githooks` (relative, so each worktree
resolves its own committed copy).

## Storage model

One `decision`-type bead per row, **created then closed** (closing keeps rows
out of `bd ready`; every read uses `bd query ... --all` to include them):

- title = decision, description = why
- labels = `logic:<branch-slug>` (+ `logic-stub` while unenriched)
- metadata = `{actor, phase, evidence, result, branch, worktree, sha, kind, ts}`

Cross-worktree visibility is automatic: beads runs on a per-repo shared Dolt
server, and `bd` walks up from any worktree under `.claude/worktrees/` to the
same `.beads`. `show-logic` therefore collects with one query; it also sweeps
worktree TSV files for the fallback backend. When `bd` is absent or
`storage=tsv`, rows go to per-writer TSV files (one log per writer — no merge
conflicts). TSV is append-only, so enrichment lands as a superseding
`kind=enrich` row and readers collapse each `(sha, decision)` group.

### Backend compatibility, and never failing silently

More than one `bd` can be installed, and a **login shell — which is what git
hooks get — may resolve a different binary than your interactive shell**. Older
builds have no `bd query`, no `--metadata`, and no `decision` type, so writes
would fail with no trace. `logic_bd_capability` probes the real API once per
binary+version (cached in `.logic/.bd-capability`) and reports `ok`,
`incompatible`, or `missing`. Anything but `ok` downgrades storage to TSV.

A downgrade always leaves a trace: interactive helpers warn on stderr, hooks
append a deduped line to `.logic/WARNINGS`, and the SessionStart hook surfaces
that file once per session then clears it. If a beads write fails anyway, the
row is still written — to TSV, in the same call. Losing a decision row quietly
is the one outcome the design refuses.

## Capture compliance (three layers)

1. **Mechanical (git post-commit).** Every commit on a tracked branch creates a
   stub row with no `why`. Deterministic shell, no model involved, so the trail
   can never be empty. Covers the user's own commits and every worktree.
2. **Enrichment gate (Claude Code Stop hook).** Once per turn, if stubs lack a
   why, blocks completion to ask for one-line whys on the ones that mattered.
   Guarded by `stop_hook_active` so it never loops.
3. **Read-time audit (show-logic).** Flags rows with unresolved evidence and
   diff regions no row explains.

The SessionStart hook only orients; it does not enforce.

## Deviations from the original design, and why

- **No ephemeral wisps / TTL expiry.** Compaction is disabled in the target
  beads setup, so wisps would accumulate and still need explicit cleanup. Rows
  are regular closed decision beads with a `logic-stub` lifecycle label; cleanup
  is explicit via `gc.sh` (removes rows whose branch was deleted unmerged, i.e.
  whose commit is reachable from no branch; keeps merged mainline history and
  no-SHA manual rows). Repos with compaction on can layer wisps later.

## Testing

`bash tests/selftest.sh` exercises the mechanical core in a throwaway repo on the
TSV backend (no beads): toggle, hook install, stub capture, manual logging,
collect/render/audit, and ancestry resolution. Exits non-zero on any failure.

## References

- `references/row-format.md` — the row contract in full.
- `references/config-schema.md` — config keys and precedence.
