# Checking without editing

`/clean-comments check [scope]` reports violations and changes nothing. Use it
in CI, in PR review, or before deciding whether a cleanup is worth running.

The scope argument takes the same words as a cleanup — `check` alone for the
working diff, `check branch [--base <ref>]` for the whole branch, `check all`,
or `check <path>`. Resolve it with `scope.sh` exactly as
[cleanup.md](cleanup.md#1-resolve-the-scope) does, then scan instead of editing.
Read only that section: the rest of `cleanup.md` is an editing workflow, and
this command never edits.

## Where these commands run

Every snippet here runs with your shell **in the repository being cleaned**, and
calls the scripts **where the skill is installed**. Those are two different
directories, so the paths are not interchangeable — set `SKILL` once:

```bash
SKILL=.claude/skills/clean-comments   # wherever `npx skills add` put it
```

Use an absolute path if the skill lives outside the repo. `scope.sh` refuses to
run outside a git repository, which is the error you get when the working
directory is wrong.

This is the form to run for `check branch`. It reports what the branch
introduced and nothing else, which is what a cleanup of that branch would
touch:

```bash
# tr|xargs -0 keeps filenames with spaces as one argument
base=$(bash "$SKILL/scripts/scope.sh" --print-base)
bash "$SKILL/scripts/scope.sh" --branch | tr '\n' '\0' \
  | xargs -0 -r node "$SKILL/scripts/scan.mjs" --diff-only --base "$base"
```

Add `--ci` to make it exit non-zero. Drop `--diff-only --base "$base"` to scan
whole files instead, which also reports comments that were already there:

```bash
bash "$SKILL/scripts/scope.sh" --branch | tr '\n' '\0' | xargs -0 -r node "$SKILL/scripts/scan.mjs"
```

That wider form answers "how bad is this file", not "what did this branch do".
It is the right one for a first look at a repository nobody has cleaned, and
the wrong one for reviewing a PR — it charges the author for comments they
never wrote. Use `--print-base` rather than passing the base ref straight to
`--base`; the two mostly agree and quietly disagree when a file the base
rewrote also has uncommitted changes of yours, which
[cleanup.md](cleanup.md#1a-the-branch-scope) explains.

## Reporting a check

A check produces findings, not a diff, so the cleanup report template does not
apply. Give the counts and the findings grouped by rule, worst first, and say
which scope and base produced them:

```markdown
## clean-comments check — branch (vs. origin/main)

3 findings in 2 files · 1 commented-code · 2 agent-reference

| Location | Rule | Comment |
| --- | --- | --- |
| `src/payment.js:10` | commented-code | `// export function legacyReconcile(a, b) {` |
```

State the counts even when there are none. Do not paste a finding's text as the
comment without opening the file first — the scan groups adjacent comments, so
one row can carry two comments' text under one rule name and the line number of
the first.

`--ci` exits 1 only for `commented-code`, `agent-reference`, `edit-history`,
and `tracker-reference` — the four highest-confidence rules. `long-comment`,
`comment-block`, and `restates-name` always report and never fail, because
judging them needs the code around them.

The scan is a filter, not a verdict, and that does not change because you are
checking rather than editing. It reports patterns it can match cheaply and
misses whole rungs of the ladder — a comment that merely restates the code
beside it is the most common finding there is and the one it is worst at. A
clean check means "no high-confidence pattern matched", never "the comments are
fine". Say it that way in the report.

## Why this never rewrites

A check that edits code during a commit or a push is a bad trade, and the skill
does not offer one:

- It rewrites code the author already reviewed, at the moment they have
  stopped looking.
- A model in the loop makes it slow and non-deterministic, so the same commit
  can produce different files twice.
- A comment that reads as noise sometimes carries the only record of a
  constraint. That call needs a human, or at least a session where one is
  present.

Flag in CI. Fix with `/clean-comments` while the author is still reading.

## Precision over recall

A check nobody trusts gets disabled within a week, so keep it quiet: prefer
missing a bad comment to failing a build over a good one. If a pattern produces a false positive on your codebase,
narrow it rather than adding an ignore list.

## GitHub Actions

```yaml
name: comments
on: pull_request

jobs:
  clean-comments:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: Check comments the PR introduced
        env:
          SKILL: .claude/skills/clean-comments
          BASE: origin/${{ github.base_ref }}
        run: |
          fork=$(bash "$SKILL/scripts/scope.sh" --print-base --base "$BASE")
          bash "$SKILL/scripts/scope.sh" --branch --base "$BASE" \
            | tr '\n' '\0' \
            | xargs -0 -r node "$SKILL/scripts/scan.mjs" --diff-only --base "$fork" --ci
```

Set `SKILL` to wherever `npx skills add gpu-cli/skills --skill clean-comments`
put the skill. Drop `--ci` to report without failing the build, which is the
right first step in a repository that has never been cleaned.

## Local pre-push hook

A pre-push hook is the one place a local check belongs: it runs after the
author is done, and it only reports.

```bash
#!/usr/bin/env bash
# .git/hooks/pre-push  — then: chmod +x .git/hooks/pre-push
SKILL=.claude/skills/clean-comments
BASE=origin/main          # <- your integration branch: develop, trunk, origin/master
fork=$(bash "$SKILL/scripts/scope.sh" --print-base --base "$BASE") || exit 0
bash "$SKILL/scripts/scope.sh" --branch --base "$BASE" \
  | tr '\n' '\0' \
  | xargs -0 -r node "$SKILL/scripts/scan.mjs" --diff-only --base "$fork" || true
```

**Set `BASE` to your integration branch.** Left wrong, `--print-base` cannot
resolve it, the `|| exit 0` swallows the error, and the hook is silently dead —
the same failure it is written to avoid. Naming it explicitly is still right:
a hook that lets the base default resolves its own tip once the branch is
pushed, and then reports nothing for the rest of that branch's life.

**`chmod +x` it.** Git skips a non-executable hook, and modern git says so in a
hint that is easy to miss while older git says nothing at all — either way the
push succeeds and you believe you are covered.

Leave the `|| true`. A comment finding is not a reason to block a push.
