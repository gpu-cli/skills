---
name: context-curation
description: "Checks whether staged changes should update CLAUDE.md or other agent context files. Use before committing."
---

# Context Curation

Decide whether staged changes have made a repository's agent context files wrong
or incomplete, and say exactly what to add or remove.

Run after staging and before committing — most usefully when a change
introduces a convention, alters a public interface, or deletes something the
context files still describe.

## Context Files

Scan every location a project might be using, not just the one you expect:

| Platform | Locations |
|---|---|
| Claude Code | `.claude/`, `CLAUDE.md` |
| Codex | `.codex/`, `codex.md` |
| Cursor | `.cursor/`, `.cursorrules` |
| Aider | `.aider/`, `.aider.conf.yml` |
| GitHub Copilot | `COPILOT.md`, `.github/copilot-instructions.md` |
| Generic | `AGENTS.md`, `AI.md`, `CONTEXT.md` |
| Project docs | `docs/`, architecture sections of `README.md` |

## Workflow

1. **Read the change.** `git diff --staged --stat` for the shape, then
   `git diff --staged` for the substance: new files and their purpose, modified
   functions and interfaces, deleted code, changed contracts.

2. **Read the context.** Open every file found above and extract what it
   currently claims — documented patterns, architecture decisions and their
   rationale, API examples, project rules.

3. **Cross-reference.** Four things make a context file wrong:

   - **New pattern** — the change establishes a convention nothing documents.
   - **API change** — a public interface moved, grew, or changed meaning.
   - **Deprecated code** — something was removed that context still instructs on.
   - **Stale reference** — context names a file, function, or pattern that no
     longer exists.

4. **Recommend**, in the format given by
   [references/output-format.md](references/output-format.md). Each
   recommendation cites the staged change that motivates it.

Suggest; do not edit. The user decides what lands, and a diff they did not ask
for is harder to review than a list they did.
