# skill-shield Inline Output

The exact shape of what the user sees in the conversation. Read before
presenting Phase 5 results.

**Keep inline output SHORT.** The user sees a scorecard and one paragraph.
Everything else — permission profiles, data flow analysis, recommendation
tiers, file inventories, per-finding evidence — goes in the optional report
files only, never inline.

## 1. Title block

Big, clear, non-technical. The verdict and score are the headline; provenance
is a technical detail that belongs in the report.

```
## Security Audit: <skill-name>

**Verdict: <VERDICT>** · Risk score: <N>/100
```

## 2. One-paragraph summary

Appears **above** the table. Cover:

- What the skill does and its overall risk posture
- The most important finding(s) and what to do about them
- Whether `--remediate` can auto-fix the issues

## 3. Scorecard table

One row per finding, sorted by severity. Exploitation and blast radius values
MUST come from the fixed lookup table in `references/dangerous-patterns.md`.
The Total row MUST equal `risk_score`.

```
| Finding | Check | Severity | Weight | Exploitation | Radius | Score |
|---------|-------|----------|--------|--------------|--------|------:|
| SS-HIGH-001 | SH-009 | HIGH | 7 | POSSIBLE (1.0) | PROJECT (1.0) | 7.0 |
| ... | ... | ... | ... | ... | ... | ... |
| | | | | | **Total** | **N** |
```

## 4. Footnote

Immediately after the table:

```
*Check IDs (e.g. SH-013, SC-004) are defined in the skill-shield dangerous-patterns reference. Reply **report** for full finding details, evidence, and remediation guidance.*
```

## 5. Next steps

> Want the full report? Reply **report** (markdown), **json**, or **both**.
> Want auto-remediation? Reply **remediate** or run `/skill-shield <path> --remediate`.

All report files and remediated copies are written to
`skills/skill-shield/artifacts/`.

## Worked Example

User invokes `/skill-shield ./skills/dev-post-generator`. The agent's **entire
visible output** is:

> ## Security Audit: dev-post-generator
>
> **Verdict: FAIL** · Risk score: 39/100
>
> This skill generates social media posts from git diffs. It fails the audit primarily because
> scripts/generate.sh downloads and executes a remote script without SHA-256 verification (SH-005,
> CRITICAL), which is a direct supply chain attack vector. It also lacks a defensive shell header
> (SH-009) and has undeclared network egress for platform API research (MD-005). All 5 auto-remediable
> findings can be fixed — run `/skill-shield ./skills/dev-post-generator --remediate`.
>
> | Finding         | Check  | Severity | Weight | Exploitation   | Radius         | Score |
> |-----------------|--------|----------|--------|----------------|----------------|------:|
> | SS-CRITICAL-001 | SH-005 | CRITICAL | 10     | LIKELY (1.5)   | PROJECT (1.0)  |  15.0 |
> | SS-HIGH-001     | SH-009 | HIGH     | 7      | POSSIBLE (1.0) | PROJECT (1.0)  |   7.0 |
> | SS-HIGH-002     | MD-005 | HIGH     | 7      | POSSIBLE (1.0) | PROJECT (1.0)  |   7.0 |
> | SS-MEDIUM-001   | SC-003 | MEDIUM   | 4      | TRIVIAL (2.0)  | PROJECT (1.0)  |   8.0 |
> | SS-MEDIUM-002   | SH-012 | MEDIUM   | 4      | POSSIBLE (1.0) | LOCAL (0.5)    |   2.0 |
> | SS-LOW-001      | SC-002 | LOW      | 1      | UNLIKELY (0.5) | LOCAL (0.5)    |  0.25 |
> |                 |        |          |        |                | **Total**      | **39** |
>
> *Check IDs (e.g. SH-005, SC-003) are defined in the skill-shield dangerous-patterns reference. Reply **report** for full finding details, evidence, and remediation guidance.*
>
> Want the full report? Reply **report**, **json**, or **both**.
> Want auto-remediation? Reply **remediate**.

Nothing more.
