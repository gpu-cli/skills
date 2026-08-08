# Output Format

Every recommendation names the file it touches, argues for itself, and cites the
staged change that motivates it. A suggestion a reader cannot trace back to the
diff is a suggestion they cannot evaluate.

## Additions

~~~text
## ADD: [Brief description]

**Context file**: [path to the file that should be updated]
**Rationale**: [why this should be documented]
**Suggested content**:
[proposed text to add, written in the voice of the surrounding file]

**Evidence from staged changes**:
- [file:line] — [the code or change that motivates this]
~~~

## Removals

~~~text
## REMOVE: [Brief description]

**Context file**: [path to the file containing outdated content]
**Current content**: [the text that should be removed or rewritten]
**Rationale**: [why this is now stale]

**Evidence from staged changes**:
- [file] — [the deleted or changed code that invalidates it]
~~~

## Nothing to change

Say so explicitly, with the scope you actually covered — silence reads as a
skipped step rather than a clean result.

~~~text
## Context files are up to date

Reviewed [N] context files against staged changes.
No updates recommended.
~~~

## No context files exist

Name the file the project should adopt and why that one: match the tooling
already in the repository (a `.cursor/` directory implies Cursor, a `.claude/`
directory implies Claude Code), and fall back to `AGENTS.md` when nothing
indicates a preference.
