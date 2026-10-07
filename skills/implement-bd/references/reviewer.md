# Reviewer

How `/implement-bd` gets an independent review on any host, and what it asks.

## Contents

- Resolving `review=`
- Effort
- First-round brief
- Follow-up brief
- Verdict

## Resolving `review=`

Take the first row that fits. A different model family is the most
independent reviewer available; the current model in a fresh context is the
default.

| `review=` | Host | Reviewer |
| --- | --- | --- |
| omitted | any | The host's own subagent on the current model, in a fresh context — never a fork of this conversation |
| `fable`, `opus`, `sonnet`, `haiku`, or a full `claude-*` id (use its family alias) | Claude Code | Agent tool, `subagent_type: general-purpose`, `model: <name>`, `effort: <effort>`. Continue it with `SendMessage` |
| any model | Codex | The host's subagent tool if it can select that model; otherwise the CLI rows below |
| a GPT or Codex model | not Codex | `codex exec -m <model> -s read-only -c model_reasoning_effort=<effort> --json --output-schema <skill>/references/verdict.schema.json -o <verdict file> - < <brief file>`. The `thread.started` event carries the thread id; continue with `codex exec resume <thread id> -c sandbox_mode="read-only" --output-schema <same schema> -o <verdict file> - < <follow-up file>` (resume has no `-s`) |
| a Claude model | not Claude Code | `claude -p --model <model> --effort <effort> --permission-mode plan --session-id <new uuid> --output-format json --json-schema "$(cat <skill>/references/verdict.schema.json)" < <brief file>`. Continue with `claude -p --resume <uuid> …` |
| anything else | any | Another installed agent CLI with a headless, read-only mode, given the same brief on stdin |

No row fits, or the command is not installed: end the run as `BLOCKED` and name
the missing piece. `<skill>` is this skill's directory.

A CLI reviewer runs in the foreground; wait for it. Keep the brief, verdict, and
follow-up files in a temporary directory, never in the repository.

## Effort

Pass `effort=` through unchanged where the reviewer accepts it. Codex has no
`max`, so `max` becomes `xhigh` there. With no `effort=`, omit the flag and let
the reviewer use its own default.

## First-round brief

Fill the brackets. Paste the issue text in full — a read-only reviewer may not
be able to run `bd`.

```text
You are reviewing a change you did not write. Judge the code, not any account
of it.

Issue <id>: <title>
<description>
Acceptance criteria:
<criteria, or the ones the implementer stated>

Repository: <absolute worktree path>
Change: `git diff <BASE>` and `git log --oneline <BASE>..HEAD` in that directory.
Quality gates the implementer ran, all passing: <commands>. Rerun them if you can.

A finding is blocking only when the change is wrong or incomplete: a correctness
bug, an unmet acceptance criterion, new behaviour with no test or a failing
test, a regression, a security problem, or an edit outside the issue's scope
that breaks something. Everything else is a suggestion and never blocks.

Do not edit any file. Reply with JSON only, matching this schema:
<contents of references/verdict.schema.json>
`verdict` is APPROVED exactly when no finding is blocking.
```

## Follow-up brief

```text
Round <n> of 3. Since your last verdict, at <new HEAD>:
- Fixed: <finding> — <what changed>
- Refuted: <finding> — <evidence>

Check every earlier blocking finding against `git diff <BASE>`. Rule on each
refutation. Look for regressions in `git diff <previous HEAD>`. A new blocking
finding must be about code changed since your last verdict, or a bug you missed
that is serious enough to stop the merge. Reply with the same JSON.
```

## Verdict

[verdict.schema.json](verdict.schema.json) is the shared format: `verdict` is
`APPROVED` or `CHANGES`, and each finding has `severity` (`blocking` or
`suggestion`), `file`, `line`, `summary`, and `evidence`. A reply that does not
parse, or says `APPROVED` while listing a blocking finding, counts as `CHANGES`.
Ask once for a corrected reply before using up a round.
