# AI Dev Skills

A collection of AI agent skills we're collecting as we find gaps and needs in our day-to-day work in applied AI. These address real friction points we've encountered and will grow over time.

## Installation

Install one skill into the current project:

```bash
npx skills add gpu-cli/skills --skill logic
npx skills add gpu-cli/skills --skill lyrebird
```

Or install the whole collection:

```bash
npx skills add gpu-cli/skills
```

## Skills

### lyrebird

Creates brand-aware content strategy and platform-native posts for Blog, LinkedIn, Reddit, and X. Lyrebird establishes a durable `VOICE.md` file, researches current platform guidance and factual claims, and writes social output under `social/<proposal-slug>/`.

**Invoke:** `/lyrebird`

**How it works:**

1. `/lyrebird voice` interviews the user, inspects repo context, analyzes exemplars, and writes root `VOICE.md`, including an optional UTM link-tracking convention
2. `/lyrebird brainstorm [topic]` researches current discussion and returns 3-5 steelmanned content takes
3. `/lyrebird hone [idea]` turns a rough idea into a sourced proposal with thesis, argument outline, evidence, risks, and suggested platforms
4. `/lyrebird write [platform?] [proposal]` writes `blog.md`, `linkedin.md`, `reddit.md`, and `x.md` by default, or one platform when specified
5. `/lyrebird modify [platform] [post]` adapts an existing URL, file, or pasted post to another platform without adding an image

**Link tracking:** When `VOICE.md` defines a UTM convention, `write` and `modify` tag backlinks to your own domains with `utm_*` parameters (`utm_source` set per platform, so a LinkedIn→X conversion updates the source). Third-party and citation links are never tagged.

**Path:** `skills/lyrebird`

**Outputs:** `VOICE.md` for reusable voice context and `social/<proposal-slug>/` for generated post files. X output is always named `x.md`.

---

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

4. Outputs `tui-analysis/[app-name]-[timestamp].md` — a complete clone spec

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
3. **Phase 2 — Static Analysis**: Applies 36 pattern-matching checks from a comprehensive dangerous-patterns database covering shell script risks (credential access, code execution, persistence, exfiltration), instruction risks (prompt injection, hidden instructions, scope violations), and supply chain risks (missing permissions, mutable refs, undeclared dependencies)
4. **Phase 3 — Behavioral Analysis**: Evaluates scope proportionality, data flow asymmetry, privilege escalation paths, time/state bombs, anti-analysis techniques, and self-modification
5. **Phase 4 — Risk Scoring**: Calculates weighted risk score (severity x exploitability x blast radius) and determines verdict (PASS / REVIEW / FAIL)
6. **Phase 5 — Present Results**: Displays a compact scorecard inline — verdict, risk score, one summary paragraph, and one row per finding. Full evidence, permission profile, and data flow analysis stay in the optional Markdown/JSON reports, which are never auto-written
7. **Phase 6 — Remediation** (optional): Rewrites the skill to a separate directory with security concerns addressed, generates `PERMISSIONS.md`, `CHECKSUMS.sha256`, and `PROVENANCE.md` integrity bundle. Auto-fixes LOW/MEDIUM issues; requires explicit user approval for HIGH/CRITICAL changes

**Requires:** `sha256sum` (or `shasum`), `git`

---

### logic — decision trails

Keeps a reviewable decision trail for a branch worked by several agents and the
user at once: what was decided, why, with what perceived confidence, on what
evidence, and by whom. Adapted from
Cursor's `show-me-your-work` skill into one beads-native, multi-agent,
PR-oriented skill with three subcommands.

**Invoke:**

- `/logic toggle [on|off] [branch]` — turn tracking on/off for a branch;
  enabling installs the committed `.logic/` runtime and the capture hooks.
- `/logic track "<what> because <why>" [--confidence high|medium|low]` — record
  a decision (yours or the user's), including coarse perceived confidence. Owns
  the row protocol the suite shares.
- `/logic show [branch] [--pr]` — render the trail as a table; validate evidence
  against the diff, flag cross-worktree conflicts, add separate decision-quality
  notes, and — when tracking was off — reconstruct a clearly-marked best-effort
  trail. `--pr` writes it into the PR.

**How it works:**

1. **Capture can't fail.** A git `post-commit` hook records one stub row per
   commit on a tracked branch — deterministic, covers the user's commits and
   every worktree, so the trail is never empty. An optional Claude Code Stop hook
   asks agents to add a one-line *why* and perceived confidence to the stubs
   that mattered before finishing.
2. **Storage is beads-native.** Rows are `decision` beads labeled
   `logic:<branch>`, kept out of `bd ready`, visible across worktrees via the
   shared Dolt server. A per-writer TSV backend is the automatic fallback when
   `bd` is absent.
3. **Reading is honest.** `/logic show` distinguishes tracked, partial, and
   untracked branches; reconstructs untracked history as inferred rows behind a
   warning banner (never written back); groups parallel worktrees into separate
   tables with a three-tier conflict check; calls out assumption, evidence, and
   confidence problems in a separate Decision quality section; and runs a
   cross-model review before any PR push.
4. **It cleans up after itself.** Rows whose branch was deleted unmerged are gc'd;
   merged history and manual rows are kept.

**Requires:** `git`; `jq` and `bd` (beads) for the default backend; `gh` for
`--pr`. Degrades to a TSV trail without `bd`.

**Test:** `bash skills/logic/tests/selftest.sh`

---

### clean-comments

Deletes agent commentary from code and rewrites the comments worth keeping as
one plain line. Agents restate the code, narrate their own edits, carry issue
IDs no reader can resolve, and spend three lines where none were needed. This
removes that layer without touching a single line of executable code.

**Invoke:** `/clean-comments [path]`, `/clean-comments all`,
`/clean-comments check`, `/clean-comments install`

**How it works:**

1. **Triage, not search-and-replace.** Every comment goes down a ten-rung
   ladder and stops at the first match: toolchain directives and license
   headers are kept verbatim; doc comments keep their contract and lose the
   padding that repeats the signature; commented-out code, restatements, edit
   narration, agent self-references, and unresolvable issue IDs are deleted;
   unfinished work becomes a `TODO:`/`FIXME:`/`HACK:` notation; and a comment
   explaining a constraint, a bug fix, unidiomatic code, or a business rule is
   kept and tightened to one line.
2. **Plain style for what survives.** Kept comments are rewritten in a
   condensed ASD-STE100 style — active voice, simple tense, one idea, twenty
   words or fewer, no hedging.
3. **Comment-only, and checked.** `verify.mjs` strips every comment from both
   versions of each changed file and compares what is left, so a code change
   that slipped into a "comment cleanup" fails loudly instead of shipping. The
   stripper tracks string, regex, heredoc, and docstring state: a `//` inside
   a URL string or a regex literal, a `#` inside `${x#y}` or a heredoc, does
   not read as a comment. It is a strong backstop, not a proof — files it has
   no syntax for are listed as unchecked rather than silently passed.
4. **Diff-scoped by default.** Untouched comments in a changed file are out of
   scope unless you ask for a path or `all`.
5. **What it will not do.** It never edits code — a comment that can only be
   fixed by changing the code is reported instead, which is where "comments
   don't excuse unclear code" lands. It never deletes a comment it cannot
   understand.

**Prevention:** `/clean-comments install` writes a fifteen-line comment policy
into `CLAUDE.md`, `AGENTS.md`, `.cursorrules`, and friends, fenced by markers so
reruns update in place. Preventing the comments beats scrubbing them, so this is
the part worth running first.

**Checking:** `/clean-comments check` reports without editing, for CI or PR
review. `--ci` fails only on the four mechanically decidable rules. There is
deliberately no pre-commit rewrite hook: an LLM pass at commit time is slow,
non-deterministic, and rewrites code the author has already reviewed.

**Requires:** `git`, `node`

**Test:** `bash skills/clean-comments/tests/selftest.sh`

---

## Contributing

Skills are billed in two places, and the difference drives how they are written.
A frontmatter `description` is injected into **every** session whether the skill
runs or not; a `SKILL.md` body loads once per invocation; everything under
`references/` loads only when a phase asks for it. So descriptions are routing
triggers, bodies are orchestration outlines, and detail lives in references.

Budgets are **60 estimated tokens** for a description and **1,500** for a body,
enforced by:

```bash
bash scripts/skill-lint.sh    # per-skill description and body token estimates
bash scripts/selftest.sh      # the lint plus every skill's own self-test
```

The lint also fails if generated output (reports, analyses, audit artifacts) is
tracked inside a skill directory — those ship to every install and an agent
reading the package can mistake them for instructions.

See [AGENTS.md](AGENTS.md) for the full convention.
