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

---

### tmux-cli-test

Test CLI applications interactively using tmux sessions. Provides a helper library for launching commands, waiting on conditions (never sleeping), sending keypresses, capturing output, and asserting on content. Works with any CLI or TUI — GPU CLI patterns included. Also supports testing inside Docker containers.

**Invoke:** `/tmux-cli-test`

**How it works:**

1. Sources `tmux_helpers.sh` for a full set of primitives:
   - `tmux_start` / `tmux_kill` — session lifecycle
   - `tmux_wait_for` / `tmux_wait_for_regex` / `tmux_wait_gone` / `tmux_wait_exit` — condition-based polling (never `sleep`)
   - `tmux_send` / `tmux_type` — keyboard input
   - `tmux_capture` / `tmux_capture_ansi` — frame snapshots
   - `tmux_assert_contains` / `tmux_assert_matches` / `tmux_assert_not_contains` — assertions

2. Test pattern:
   ```
   Start session → wait for ready signal → interact → assert → kill
   ```

3. Docker support via `tmux_docker_helpers.sh` — routes all tmux commands through `docker exec` for container-based testing.

**Requires:** `tmux`

---

### tui-clone

Explore and analyze TUI applications to produce clone-ready documentation. Launches the target TUI in a tmux session, systematically explores all views and keybindings, captures ASCII diagrams of each screen, and writes findings incrementally to a timestamped markdown file (survives context compaction).

**Invoke:** `/tui-clone`

**How it works:**

1. Launches target TUI in a sized tmux session using `tmux_helpers.sh`
2. Immediately writes each discovered screen to the output file as it's found — context compaction safe
3. Captures across 12 dimensions:
   - Screen catalog with ASCII diagrams and entry paths
   - Full keybinding table by context
   - State transition map (From → Trigger → To)
   - Component inventory (lists, modals, tabs, inputs, status bars)
   - Color palette via ANSI capture
   - Responsive behavior at compact (80×24) and wide (200×50) sizes
   - Error, loading, and empty states
   - Data structure patterns (lists, trees, tables, diffs)

4. Outputs `tui-analysis-[app-name]-[timestamp].md` — a complete clone spec

**Supports:** Claude Code, OpenCode, Codex, lazygit, lazydocker, htop, btop, k9s, and any ratatui/ncurses app.

---

### tui-review

Critically review terminal user interfaces across 10 UX dimensions. Launches the TUI in tmux, takes color screenshots at key states using `freeze`, visually inspects each one, and produces a graded report. Benchmarks against Claude Code, OpenCode, and Codex — the three best-in-class AI terminal UIs.

**Invoke:** `/tui-review`

**How it works:**

1. Enables true-color tmux support (`Tc` override) so RGB colors from ratatui/crossterm are preserved in captures
2. Takes color PNG screenshots via `capture-pane -e | freeze --language ansi` at:
   - Initial load, help overlay, command palette, processing/streaming, completed response, error state, dialog/modal, permission flow, and resize at 80×24 / 120×30 / 160×40 / 200×50
3. Visually inspects every screenshot using the Read tool — evaluating color semantics, contrast, layout density, typography, and polish
4. Tests 10 dimensions:
   1. **Responsiveness** — visible change within 100ms per keypress
   2. **Input Mode Integrity** — trigger chars don't hijack mid-sentence text
   3. **Visual Feedback** — every app state has a distinct indicator
   4. **Navigation & Escape** — Escape always goes back, never stuck
   5. **Feedback Loops** — submit → echo → loading → stream → completion
   6. **Error & Empty States** — every state has a designed appearance
   7. **Layout & Resize** — usable at 80×24, scales to 200×50+
   8. **Keyboard Design** — all features keyboard-reachable, discoverable
   9. **Permission Flows** — destructive actions show preview + confirmation
   10. **Visual Design & Color** — color communicates meaning, sufficient contrast
5. Flags excessive border usage (full-screen borders waste real estate; best-in-class TUIs use divider lines and selective borders only)
6. Produces a graded report (A–F) with screenshots, dimension scores, and CRITICAL / WARNING / INFO findings

**Requires:** `tmux`, `freeze` (`brew install charmbracelet/tap/freeze`)

---

### skill-shield

Security audit and active remediation for agent skills. Analyzes SKILL.md instructions and bundled scripts for prompt injection, data exfiltration, excessive permissions, supply chain risks, and other threats aligned with OWASP Top 10 for LLMs (2025), NIST AI RMF, SLSA, and OpenSSF Scorecard best practices. Presents findings inline first, then optionally generates structured reports (Markdown + JSON) and can rewrite skills to remove security concerns.

**Invoke:** `/skill-shield <path>`, `/skill-shield <path> --remediate`, or `/skill-shield --all`

**How it works:**

1. **Phase 0 — Trust & Source Verification**: Assesses skill provenance (source pinning, publisher identity, repository health signals), checks against local allowlist/denylist, and calculates a provenance confidence score
2. **Phase 1 — File Inventory**: Enumerates all files, classifies them (instruction, executable, reference, config), calculates SHA-256 hashes, and maps dependencies
3. **Phase 2 — Static Analysis**: Applies 30+ pattern-matching checks from a comprehensive dangerous-patterns database covering shell script risks (credential access, code execution, persistence, exfiltration), instruction risks (prompt injection, hidden instructions, scope violations), and supply chain risks (missing permissions, mutable refs, undeclared dependencies)
4. **Phase 3 — Behavioral Analysis**: Evaluates scope proportionality, data flow asymmetry, privilege escalation paths, time/state bombs, anti-analysis techniques, and self-modification
5. **Phase 4 — Risk Scoring**: Calculates weighted risk score (severity x exploitability x blast radius) and determines verdict (PASS / WARN / FAIL)
6. **Phase 5 — Present Results**: Displays full findings, verdict, permission profile, and recommendations inline. Asks the user if they want Markdown/JSON report files generated (reports are optional, never auto-written)
7. **Phase 6 — Remediation** (optional): Rewrites the skill to a separate directory with security concerns addressed, generates `PERMISSIONS.md`, `CHECKSUMS.sha256`, and `PROVENANCE.md` integrity bundle. Auto-fixes LOW/MEDIUM issues; requires explicit user approval for HIGH/CRITICAL changes

**Requires:** `sha256sum` (or `shasum`), `git`
