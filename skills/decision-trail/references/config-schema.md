# Config schema — `.decision-trail/config.json`

Per-repo tracking config. Committed, so it travels with the branch and its edits
appear in the PR diff (intended — it records that tracking was on).

```json
{
  "version": 1,
  "default": "off",
  "branches": {
    "angus/avatar-customisation": "on",
    "release/*": "off"
  },
  "storage": "beads",
  "storageOverrides": {
    "some-branch": "tsv"
  }
}
```

## Keys

- **version** — schema version (currently `1`).
- **default** — `on` | `off`. The fallback tracking state for branches with no
  matching key.
- **branches** — map of branch key → `on` | `off`. Keys may be exact branch
  names or globs (`release/*`, `feature/*`).
- **storage** — `beads` | `tsv`. Default backend. `beads` silently falls back to
  `tsv` when `bd` is not on PATH.
- **storageOverrides** — map of logical-branch → `beads` | `tsv`, for per-branch
  backend choice.

## Precedence

For the current checkout's branch `B`:

1. **Exact** — `branches[B]` if present.
2. **Glob** — the first `branches` key whose glob matches `B`.
3. **Unmerged ancestor** — any `branches` key set to `on` that is a git
   **ancestor** of `HEAD` and is **not yet merged** into the mainline
   (`origin/main`/`main`/`origin/master`/`master`). This is what makes a derived
   worktree branch (forked from an enabled feature branch) tracked; its rows are
   labeled with that ancestor as the logical branch.

   The unmerged condition matters: once a tracked feature lands, its tip is an
   ancestor of the mainline and therefore of every later branch. Without the
   check, `main` and everything after it would silently keep recording into the
   finished feature's trail.
4. **Default** — `default`.

The **logical branch** is the matched key (exact/glob/ancestor) or `B` itself. It
is what rows are scoped and labeled by, and what `decision-trail show` groups
on. Storage for a branch is `storageOverrides[logicalBranch]` if set, else
`storage`.

## Editing

`decision-trail toggle` writes this file. Direct edits:

```bash
config-edit.sh init                       # create with defaults
config-edit.sh set default on
config-edit.sh set-branch feature/x on
config-edit.sh set-storage feature/x tsv
config-edit.sh get '.branches'
```
