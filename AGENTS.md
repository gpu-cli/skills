# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Skill Authoring Convention

A skill costs context in two places, and they are billed very differently.

**The frontmatter `description` is always on.** It is injected into every
session whether or not the skill is ever used, so it is the most expensive text
in the repository per unit of value. Write it as routing triggers only: one
sentence on what the skill does plus the words a user would actually type. No
feature enumerations, no dimension lists, no benchmarks, and no "Invoke as
/name" — the name is already in the listing. Budget: **45 tokens**.

Claude Code prices that listing as:

```js
tokens = round([name, description, whenToUse].filter(Boolean).join(" ").length / bytesPerToken)
```

Two consequences worth internalizing. The **skill name is billed with the
description**, so a long name is a permanent tax. And `bytesPerToken` is **3**
for every model from Claude 5 on (Claude 3.x and 4.x used 4) — so a description
costs a third more than a chars/4 rule of thumb suggests. `/skills` shows this
number rounded to the nearest 10, which is what `SHOWN` in the lint reproduces.

Two caps sit above the budget, neither normally binding: a single description is
truncated past `skillListingMaxDescChars` (1536), and once the whole listing
exceeds `skillListingBudgetFraction` of the context window (1%, so ~30,000
characters at 1M) Claude Code starts dropping the longest descriptions entirely,
leaving those skills listed by name alone.

**The `SKILL.md` body loads once per invocation.** Write it as an orchestration
outline: what the phases are, what order they run in, the rules that must be
resident before the agent touches anything, and a pointer to the reference that
carries each phase's detail. Budget: **2,000 estimated tokens**.

**Detail lives in `references/`, loaded on demand.** Templates, check
catalogues, worked examples, cookbooks, and per-phase procedures go here. State
each fact in exactly one place — if the body and a reference both define the
check IDs, they will drift, and the body copy is the one being paid for on
every invocation.

**Never track generated output inside a skill directory.** Reports, analyses,
and audit artifacts ship to every install of the skill and an agent reading the
package can mistake them for instructions. Put them in `planning/`, or gitignore
them.

Check the budgets before committing:

```bash
bash scripts/skill-lint.sh    # per-skill description and body token estimates
bash scripts/selftest.sh      # the lint plus every skill's own self-test
```

Raising a body budget requires an entry with a justification in
`scripts/skill-lint.allow`, and is a last resort — the first question is always
whether the content is orchestration or detail.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work atomically
bd close <id>         # Complete work
bd dolt push          # Push beads data to remote
```

## Non-Interactive Shell Commands

**ALWAYS use non-interactive flags** with file operations to avoid hanging on confirmation prompts.

Shell commands like `cp`, `mv`, and `rm` may be aliased to include `-i` (interactive) mode on some systems, causing the agent to hang indefinitely waiting for y/n input.

**Use these forms instead:**
```bash
# Force overwrite without prompting
cp -f source dest           # NOT: cp source dest
mv -f source dest           # NOT: mv source dest
rm -f file                  # NOT: rm file

# For recursive operations
rm -rf directory            # NOT: rm -r directory
cp -rf source dest          # NOT: cp -r source dest
```

**Other commands that may prompt:**
- `scp` - use `-o BatchMode=yes` for non-interactive
- `ssh` - use `-o BatchMode=yes` to fail instead of prompting
- `apt-get` - use `-y` flag
- `brew` - use `HOMEBREW_NO_AUTO_UPDATE=1` env var

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
