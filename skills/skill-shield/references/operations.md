# skill-shield Operations

Configuration, output locations, the questions to ask before starting, and how
to pick an audit back up after context compaction. Read this at the start of an
audit; nothing here changes how findings are scored.

## Configuration Variables

| Variable | Default | Description |
|---|---|---|
| `SKILL_SHIELD_OUTPUT` | `./skills/skill-shield/artifacts/` | Directory for report artifacts (isolated alongside the skill) |
| `SKILL_SHIELD_SEVERITY` | `LOW` | Minimum severity to report (`CRITICAL`, `HIGH`, `MEDIUM`, `LOW`, `INFO`) |
| `SKILL_SHIELD_FORMAT` | `markdown` | Report format when the user requests file output (`markdown`, `json`, `both`) |

## Output Directories

| Purpose | Directory | When created |
|---|---|---|
| Report files (optional) | `skills/skill-shield/artifacts/` | Only if the user requests report files |
| Remediated skill copy | `skills/skill-shield/artifacts/<skill-name>-shielded/` | Only with `--remediate` |

Never create an output directory unless it is actually needed. Generated
reports and shielded copies are build products: they belong in the ignored
`artifacts/` directory, never committed inside a skill package.

## Upfront Questions

Before starting the audit, ask:

1. **Target** — which skill(s)? A path, or `--all` for everything under `./skills/`.
2. **Remediation** — also produce a hardened copy? (`--remediate`)
3. **Severity filter** — minimum severity to report (default: LOW).
4. **Context** — first audit or re-audit? This selects the drift-detection baseline.

If the invocation already answers these (e.g. `/skill-shield ./skills/foo
--remediate`), skip the questions and proceed.

## Finding Record Fields

Record every finding with:

- **Finding ID** — e.g. `SS-HIGH-001`
- **Check ID** — e.g. `SH-005`
- **Severity** — CRITICAL, HIGH, MEDIUM, LOW, INFO
- **Location** — file path and line number
- **Evidence** — the exact snippet or pattern matched
- **Description** — what was found and why it matters
- **Remediation** — a concrete fix
- **Auto-remediable** — whether `--remediate` can fix it
- **OWASP alignment** — the relevant framework reference

## Resuming After Context Compaction

If compaction happens mid-audit:

1. **Check `skills/skill-shield/artifacts/`** for a partial report and read it
   to see which phases completed.
2. **Re-read the `references/` files** to restore the pattern databases.
3. **Re-read the target's file inventory** to restore analysis context.
4. **Resume from the last incomplete phase.** Each phase has a discrete output:
   Phase 0 → provenance confidence level; Phase 1 → file inventory with hashes;
   Phases 2–3 → findings list; Phase 4 → risk score and verdict; Phase 5 →
   always redo the inline presentation; Phase 6 → check
   `artifacts/<skill-name>-shielded/` for partial output.

If you cannot determine the last completed phase, restart the audit. The
process is idempotent — re-running produces the same result.

## Remediation Integrity Bundle

Generated inside `skills/skill-shield/artifacts/<skill-name>-shielded/` during
`--remediate`, after the fixes are applied.

| File | Contents |
|---|---|
| `PERMISSIONS.md` | Every filesystem path, network destination, tool, and secret the hardened skill accesses, each with the reason it needs it |
| `CHECKSUMS.sha256` | SHA-256 of every file in the hardened package |
| `PROVENANCE.md` | Source origin, audit timestamp, the findings that motivated each change, and the changes made |

Then summarize inline — and only this, since full detail belongs in the report
files:

- What changed, and which finding each change resolves.
- What was deliberately left alone, with the risk-acceptance note for any
  declined HIGH or CRITICAL fix.
- How to verify: `sha256sum --check CHECKSUMS.sha256` run from inside the
  hardened directory.

The original skill is never modified in place, so the user can diff the two
directories to see exactly what the remediation did.
