# Cleaning comments

The workflow behind `/clean-comments [path]`, `/clean-comments branch`, and
`/clean-comments all`.

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

## 1. Resolve the scope

```bash
bash "$SKILL/scripts/scope.sh"              # changed files: staged, unstaged, untracked
bash "$SKILL/scripts/scope.sh" --branch     # everything this branch changed vs. its base
bash "$SKILL/scripts/scope.sh" src/api      # a path, file or directory
bash "$SKILL/scripts/scope.sh" --all        # every source file in the repository
```

The script prints one path per line. It excludes vendored trees, build output,
minified bundles, lockfiles, and files carrying a generated-code banner.

Default to the changed-files scope. Widen only when the user asked for it.

Two of these scopes judge lines rather than files. In the changed-files scope,
judge only comments the working diff touched; in the branch scope, only
comments the branch touched. A comment that was already there and is untouched
is out of scope, however bad it looks — report the worst of those in Flagged
rather than editing them. The `--all` and path scopes have no such filter:
every comment in the file is in scope.

If the scope resolves to nothing, say so and stop.

Before you start, run `git status` and note any code the user already has
uncommitted. Verify compares against `HEAD`, so their work in progress reads as
a code change no matter who made it. Cleanest is to ask them to commit or stash
it first; if they would rather not, write the list down now — in step 5 it is
the only thing that tells their edits apart from your slip.

## 1a. The branch scope

`/clean-comments branch` covers everything the branch changed against its base:
commits plus any uncommitted work on top. Use it to clean a PR in one pass
instead of file by file.

```bash
bash "$SKILL/scripts/scope.sh" --branch                    # files, base resolved for you
bash "$SKILL/scripts/scope.sh" --branch --base origin/main # or name the base yourself
```

With no `--base`, the base is the branch's upstream, then `origin/HEAD`, then
`origin/main` or `origin/master`, then a local `main` or `master`. Two refs are
skipped along the way because both resolve to `HEAD` and would shrink the scope
to your uncommitted files without saying so: the branch's own remote
counterpart, which a pushed branch tracks, and the current branch itself. If
nothing resolves — you are on `main` with no remote — the script says so and you
must pass `--base`.

Scan a branch from the **fork point**, not from the base ref:

```bash
base=$(bash "$SKILL/scripts/scope.sh" --print-base)   # add --base <ref> to match above
bash "$SKILL/scripts/scope.sh" --branch | tr '\n' '\0' \
  | xargs -0 -r node "$SKILL/scripts/scan.mjs" --diff-only --base "$base"
```

`--print-base` prints `git merge-base <base> HEAD`. Use it rather than passing
the base ref straight to `--diff-only`, which reads the base's own later
commits backwards and reports a comment `main` deleted, and your branch merely
kept, as yours.

The two usually agree, because `scope.sh --branch` lists committed work with a
three-dot diff and a file only the base touched never reaches the scan. They
diverge once such a file re-enters scope through your own uncommitted or
untracked changes — ordinary on a long-running branch.

A branch cleanup is still one comment-only change for the user to commit —
never mix it with other edits. Nothing else about the workflow changes: you are
editing the working tree, so verification in step 5 stays against `HEAD`.

## 2. Find candidates

```bash
node "$SKILL/scripts/scan.mjs" <file>...            # TSV findings on stdout
node "$SKILL/scripts/scan.mjs" --json <file>...
node "$SKILL/scripts/scan.mjs" --diff-only <file>...  # only lines the working diff touched
node "$SKILL/scripts/scan.mjs" --diff-only --base "$base" <file>...  # branch scope; $base from 1a
```

Each finding is `file<TAB>line<TAB>rule<TAB>text`. The rules it detects
mechanically are `commented-code`, `agent-reference`, `edit-history`,
`tracker-reference`, `long-comment`, `comment-block`, and `restates-name`.

The scan is a filter, not a verdict. It finds high-signal patterns cheaply so
you read less; it cannot judge whether a comment explains something real. Two
consequences:

- Every finding still needs the triage ladder applied by reading the code.
- A comment the scan missed is still in scope. Read the diff or the file, not
  just the scan output.
- **One finding can be more than one comment.** Consecutive comment lines are
  reported as a single row, under one rule name and the first line's number.
  Two adjacent comments can need two different rungs — delete the narration,
  keep the `TODO` — and a row that looks handled is how the second one gets
  deleted with the first. Open the file at that line and see how many comments
  are really there.

## 3. Read before editing

For each candidate, read enough surrounding code to answer one question: does
this comment tell the reader something the code does not? You cannot answer it
from the comment alone. Do not skip this for comments that look obviously
disposable — a line that reads like narration sometimes carries the only record
of a constraint.

## 4. Apply the ladder

Walk each comment down the triage ladder in `SKILL.md` and stop at the first
rung that matches. [rules.md](rules.md) has the full test for each rung, and
[ste.md](ste.md) has the style for anything you keep or rewrite.

Check the comment is in scope before you apply a rung. In the changed-files and
branch scopes an in-scope *file* still contains out-of-scope *comments*, and a
bad one sitting two lines from a comment you are legitimately deleting is the
easiest mistake in this skill to make. It goes in Flagged. Step 1 has the rule.

Edit comment text only. Never change executable code, even to fix something
obvious that you notice on the way — note it in Flagged instead.

Delete a whole comment by deleting its lines, including the now-blank line if
one is left behind. Never leave an empty `//` or a bare `#` where a comment
was.

## 5. Verify

```bash
node "$SKILL/scripts/verify.mjs"               # working tree vs. HEAD
node "$SKILL/scripts/verify.mjs" --base <ref>  # vs. another ref
```

It strips comments from both versions of every changed file and compares what
is left. Identical means only comment text moved.

Verify against `HEAD` in every scope, the branch scope included. Your edits are
uncommitted, so `HEAD` is what they have to be comment-only against; verifying
a branch cleanup against the merge-base would fold the branch's own real code
changes into the comparison and fail every time.

A failure usually means an edit changed code. Read the reported line before you
act on it:

- It is a line you touched: you changed code. Redo that file's comment edits and
  verify again.
- It is code the user already had uncommitted (the list from step 1): the
  cleanup is fine and the failure is the comparison seeing their work. Say so in
  the report, and verify the rest.

**Never discard a file to "reset" it.** `git checkout -- <file>` and friends
throw away the user's uncommitted work along with your edit, and that work is
not in version control to get back. Undo your own comment edits by hand.

Never report a cleanup whose verification failed for the first reason. Files the
check could not compare are listed as unchecked — say so in the report rather
than folding them into the pass.

The comment stripper is quote-aware but heuristic; it is a backstop against a
slipped edit, not a proof. A clean run does not excuse careless editing, and an
unexpected failure in a language with unusual comment syntax is worth reading
before you dismiss it.

## 6. Report

Show the user what changed before they commit. Group by outcome, not by file,
so the ratio is legible at a glance.

```markdown
## clean-comments — <scope>

Deleted 14 · Rewrote 6 · Kept 31 · Flagged 2

### Deleted
| Location | Comment | Rung |
| --- | --- | --- |
| `src/api/user.ts:42` | `// Loop through the users` | 4 restates the code |

### Rewritten
| Location | Before | After |
| --- | --- | --- |
| `src/cache.py:88` | `# We use a lock here to make sure...` | `# Lock: concurrent writers corrupt the cache.` |

### Flagged
| Location | Finding |
| --- | --- |
| `src/parse.go:19` | Comment contradicts the code: says "returns nil", returns an error. |
| `src/report.rs:204` | Needs four lines of comment to follow; consider splitting the function. |
```

Keep Flagged short and specific. It is the part a human must act on, and it is
where rules 2, 3, and 4 land: comments that excuse unclear code, comments you
could not make clear, and comments that confuse or contradict.

State the counts even when nothing changed. "Reviewed 31 comments in 8 files,
changed none" is a useful result and a common one in a well-kept repository.

## Scope reminders

- Name the scope in the report heading, and name the base with it in branch
  scope: `## clean-comments — branch (vs. origin/main)`. A reader checking
  whether the cleanup covered their PR should not have to guess.
- Cleaning `all` in a repository nobody has cleaned before produces a large
  diff. Say so up front, and offer to go directory by directory instead.
- Never combine a cleanup with any other edit in the same commit. A
  comment-only diff is reviewable at a glance; a mixed one is not.
