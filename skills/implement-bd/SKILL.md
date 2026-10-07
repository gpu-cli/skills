---
name: implement-bd
description: "Implements a bd task or epic, then loops with an independent reviewer until it approves. Use to implement a bd issue."
argument-hint: "<id> [review=<model>] [effort=<level>] [branch=<name>] [finish=commit|draft|pr]"
disable-model-invocation: true
hooks:
  Stop:
    - hooks:
        - type: command
          # The /goal check, made deterministic: while this session's run is
          # armed, block every stop until the last line of the last message is
          # the final IMPLEMENT-BD line. A running subagent reviewer wakes the
          # session itself, so that stop is let through. A marker idle for six
          # hours belongs to an abandoned run and is dropped.
          command: |
            in="$(cat)"
            get() { printf '%s' "$in" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1; }
            sid="$(get session_id)"; [ -n "$sid" ] || exit 0
            git_dir="$(git -C "$(get cwd)" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || exit 0
            marker="$git_dir/implement-bd/$sid"; [ -f "$marker" ] || exit 0
            if [ -n "$(find "$marker" -mmin +360 2>/dev/null)" ]; then rm -f "$marker"; exit 0; fi
            if printf '%s' "$in" | grep -qE '("last_assistant_message"[[:space:]]*:[[:space:]]*"|\\n)IMPLEMENT-BD: (APPROVED|BLOCKED)([^"\\]|\\[^n])*(\\n)*"'; then rm -f "$marker"; exit 0; fi
            printf '%s' "$in" | grep -qE '"type"[[:space:]]*:[[:space:]]*"subagent"' && exit 0
            touch "$marker"
            echo '{"decision":"block","reason":"/implement-bd is not finished. Continue the implement and review loop. If it cannot finish, or the user has redirected you, end with IMPLEMENT-BD: BLOCKED and the reason as the last line, written plain with no markdown."}'
---

# Implement bd

Implement a bd issue, have an independent agent review the result, fix what it
finds, and stop only when it approves.

```text
/implement-bd <id> [review=<model>] [effort=<level>] [branch=<name>] [finish=commit|draft|pr]
```

| Argument | Default | Meaning |
| --- | --- | --- |
| `<id>` | required | A bd task, or an epic, meaning its open children in dependency order |
| `review=` | the current model | Reviewer model, any vendor — resolved by [references/reviewer.md](references/reviewer.md) |
| `effort=` | the host default | Reviewer reasoning effort: `low` … `max` |
| `branch=` | the current branch and worktree | Create a worktree on this new branch and work there |
| `finish=` | `commit` | `commit`; `draft` pushes and opens a draft PR; `pr` opens a ready PR |

No `<id>`, an unknown key, or no `branch=` while on the default branch: print
the usage line and stop. The implementer's own reasoning depth is the
session's setting; this skill never changes it.

## Completion condition

One condition governs the run on every host:

> `<id>` is implemented on the working branch, the repository's quality gates
> pass, and an independent reviewer returned `APPROVED` on the final diff — or
> the run cannot get there and says why.

The run ends with exactly one final line — the last line of the message,
plain text, no markdown:

```text
IMPLEMENT-BD: APPROVED <id> <commit sha or PR URL>
IMPLEMENT-BD: BLOCKED <id> <reason>
```

Set it as the session goal before touching code, so the run cannot stop early:

- **Claude Code:** arm the skill's Stop hook, which then blocks every stop
  until the final line appears — the same after-each-turn check `/goal` makes:
  `d="$(git rev-parse --path-format=absolute --git-common-dir)/implement-bd" && mkdir -p "$d" && touch "$d/${CLAUDE_SESSION_ID}"`
- **Codex:** create a goal with the goal tool (`create_goal`) using the
  condition with `<id>` filled in. Mark it complete only after `APPROVED`.
- **Any other host:** keep working in this turn until the final line.

## Steps

1. **Resolve the reviewer** per [references/reviewer.md](references/reviewer.md).
   An unreachable reviewer ends the run as `BLOCKED` now, before any code or
   claim.
2. **Set up the branch.** With `branch=`: `git fetch origin`, then
   `git worktree add -b <branch> .worktrees/<last path segment> origin/<default>`
   (drop `-b` if the branch exists), add `.worktrees/` to
   `$(git rev-parse --git-common-dir)/info/exclude`,
   and work from that directory for the rest of the run — in Claude Code, enter
   it with `EnterWorktree path=…`. Record `BASE` as the commit the work starts
   from. Without `branch=`, the working branch is the current one.
3. **Read and claim.** `bd show <id> --json`; for an epic, also
   `bd list --parent <id> --status open,in_progress --json`. Then
   `bd update <id> --claim`. With no acceptance criteria, state the ones you
   will hold yourself to before writing code.
4. **Implement** each issue with tests. Run the repository's quality gates —
   tests, lint, type checks, whatever it defines — until they pass, then commit
   that issue's work. The reviewer never sees failures a gate would catch.
5. **Review.** Send the brief in [references/reviewer.md](references/reviewer.md).
   The reviewer sees the issue text, the diff from `BASE`, and the repository —
   never your reasoning or a summary of it.
6. **Fix and re-review.** Fix each blocking finding, or refute it with
   evidence. Rerun the gates, commit, and send the same reviewer the follow-up
   brief. After three rounds without `APPROVED`, end as `BLOCKED` and list the
   open findings.
7. **Finish** on `APPROVED`:
   - `draft` or `pr`: `git push -u origin <working branch>`, then
     `gh pr create [--draft] --base <default> --title "<issue title>"` with a
     body naming the issue, what changed, and the review rounds.
   - `bd close <id> --reason "<one line> — <sha or PR URL>"`, plus each closed
     child of an epic.
   - Print the final line.

   On `BLOCKED` after the claim, leave the issue claimed and record why with
   `bd update <id> --append-notes "…"`. Either way, print the final line.

## Rules

- Nothing is pushed, opened as a PR, or closed before `APPROVED`. Never
  force-push, never merge, never commit to the default branch.
- A finding is evidence to weigh, not an order. Fix it or refute it with
  evidence; a refuted finding goes back to the reviewer, who decides.
- Suggestions never block. Note the ones you decline in the PR body or the
  close reason.
