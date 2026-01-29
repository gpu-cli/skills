# AI Dev Skills

A collection of AI agent skills we're collecting as we find gaps and needs in our day-to-day work in applied AI. These address real friction points we've encountered and will grow over time.

## Installation

```bash
npx skills add gpu-cli/skills
```

## Skills

### context-curation

Analyzes staged git changes and evaluates agentic context files to suggest additions or removals. Keeps your AI context (CLAUDE.md, .cursorrules, AGENTS.md, etc.) synchronized with actual code.

**Invoke:** `/context-curation` after staging changes

**How it works:**

1. Inspects staged changes via `git diff --staged` to understand new files, modified functions, deleted code, and API changes
2. Scans for context files across platforms:
   - Claude Code (`.claude/`, `CLAUDE.md`)
   - Cursor (`.cursor/`, `.cursorrules`)
   - GitHub Copilot (`COPILOT.md`, `.github/copilot-instructions.md`)
   - Generic (`AGENTS.md`, `AI.md`, `CONTEXT.md`)
3. Cross-references changes against existing context to identify:
   - New patterns that should be documented
   - API changes needing updates
   - Stale references to removed code
4. Outputs actionable ADD/REMOVE recommendations with evidence from the diff

#### Precommit Hook

Ensure context evolves with your codebase by adding a precommit hook.

Add to `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/precommit-context.sh"
          }
        ]
      }
    ]
  }
}
```

Create `.claude/hooks/precommit-context.sh`:

```bash
#!/bin/bash
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')

if [[ "$cmd" =~ ^git[[:space:]]+commit ]]; then
  echo "Run /context-curation first to check if context files need updates." >&2
fi
exit 0
```

Make it executable: `chmod +x .claude/hooks/precommit-context.sh`

---

### research-spike

Conducts time-boxed technical investigations with structured, citation-backed output. Produces markdown reports suitable for sharing with stakeholders or preserving decision context.

**Invoke:** `/research-spike`

**How it works:**

1. Asks upfront questions to scope the work:
   - **Research type**: Technical spike (deep dive), competitive research (compare options), or feasibility analysis (assess viability)
   - **Depth level**: Quick (high-level overview), standard (actionable depth), or deep dive (production-ready guidance)
   - **Constraints**: Technologies to include/exclude, budget, team expertise, success criteria

2. Follows a structured methodology:
   - Scope definition and research planning
   - Information gathering from web, docs, and codebase
   - Synthesis with trade-off analysis
   - Source tracking for all citations

3. Outputs a structured report to `research/[topic-slug]/spike-report.md` including:
   - Executive summary (<250 words) for busy stakeholders
   - Detailed findings with evidence and citations
   - Trade-offs, risks, and decision matrices
   - Primary recommendation with confidence level
   - Concrete next steps

4. Applies anti-hallucination protocols: only states what sources confirm, uses hedging for inferences, marks opinions vs facts.
