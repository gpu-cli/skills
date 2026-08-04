---
name: clean-comments
description: "Deletes agent commentary from code and rewrites the comments worth keeping as one plain line. Use when cleaning comments in a diff, file, or repository; when reviewing AI-written code before a commit or PR; or when asked to add comment rules to a project's agent instructions. Invoke as /clean-comments."
---

# Clean Comments

Agents comment too much. They restate the code, narrate their own edits, carry
issue IDs no reader can resolve, and spend three lines where none were needed.
This skill removes that layer and rewrites what survives as one plain line.

**Edit comment text only. Never change executable code.** If a comment can only
be fixed by changing the code, report it instead — see
[references/rules.md](references/rules.md).

```text
/clean-comments [command | path]
```

| Command | Use for | Read |
| --- | --- | --- |
| `[path]` | Clean the current diff, or a file or directory when given a path | [references/cleanup.md](references/cleanup.md) |
| `all` | Clean every source file in the repository | [references/cleanup.md](references/cleanup.md) |
| `check [scope]` | Report violations without editing, for CI or PR review | [references/check.md](references/check.md) |
| `install` | Write the comment rules into the project's agent files | [references/install.md](references/install.md) |

With no argument, clean the current diff. Treat an unrecognized argument as a
path. Never widen the scope the user asked for.

## Triage

Judge every comment in scope against this ladder and stop at the first match.
[references/rules.md](references/rules.md) holds the full test and examples for
each rung.

1. **Directive** — a pragma the toolchain reads (`eslint-disable`, `# noqa`,
   `//go:generate`, `# type: ignore`), a license header, a shebang, or a
   generated-file marker. **Keep it exactly as written.**
2. **Doc comment on a public interface** — a docstring, JSDoc, or rustdoc block
   that states a contract. **Keep the contract**, drop padding that repeats the
   signature. The one-line rule does not apply.
3. **Commented-out code** — **delete**. Version control already has it.
4. **Restates the code** — the comment says what the next line or the function
   name already says. **Delete.**
5. **Narrates an edit** — "added", "updated", "now handles", "refactored",
   "as requested". **Delete**, keeping any reason it carried.
6. **Names the agent or the session** — "I've", "as an AI", "Claude", "per your
   request". **Delete the reference.** Keep the technical content, if any.
7. **Cites an unshared tracker** — an issue ID that a reader of this repository
   cannot resolve. **Delete the ID**, keep the substance.
8. **Marks unfinished work** — **rewrite** to `TODO:`, `FIXME:`, `HACK:`, or
   `XXX:` so tooling can find it.
9. **Explains a constraint, a bug fix, unidiomatic code, or a business rule** —
   **keep it.** Rewrite it to one line in the style of
   [references/ste.md](references/ste.md).
10. **You cannot tell what it means** — **flag it, do not delete it.** An
    unclear comment usually marks unclear code, which is the human's call.

## Rules of thumb

- One line, almost always. A comment that needs a paragraph is usually a sign
  the code needs work — report that rather than writing the paragraph.
- Say why, never what. The code already says what.
- Delete freely when the code is self-evident, and never when you are unsure.

## Validation

Run `bash tests/selftest.sh` after changing the bundled scripts. After any
cleanup, `node scripts/verify.mjs` proves that only comment text changed.
