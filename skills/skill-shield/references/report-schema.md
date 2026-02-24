# skill-shield Report Schema Reference

This reference defines the canonical report structure for `skill-shield` audits in two formats:

1. Human-readable Markdown reports for reviewers
2. Machine-readable JSON reports for tooling and automation

All report artifacts MUST use `skill-shield` naming (not `skill-audit`).

---

## 1) Human-Readable Report (Markdown)

### File Name Pattern

```text
skill-shield-report-<skill>-<timestamp>.md
```

### Purpose

- Provide a decision-ready trust and risk summary for maintainers
- Explain findings with clear evidence and remediation guidance
- Capture scope, provenance, permissions, and blast-radius context

### Required Section Order

The following sections are REQUIRED and should appear in this order.

## Executive Summary

- Skill assessed, date/time, and overall verdict
- One-paragraph trust conclusion
- Top 3 risks and immediate actions

## Skill Metadata

Use a table with these fields:

| Field | Value |
|---|---|
| Skill Name | `<skill-name>` |
| Skill Version | `<version or commit>` |
| Source | `<repository/local path/package>` |
| Auditor | `skill-shield` |
| Audit Timestamp (UTC) | `<ISO-8601>` |
| Schema Version | `<schema-version>` |
| Total Files Reviewed | `<count>` |
| Total Findings | `<count>` |

## Trust Assessment

Include:

- Provenance confidence (`HIGH`/`MEDIUM`/`LOW`)
- Integrity posture (hash coverage and verification result)
- Authenticity signals (signed commits/releases, origin reliability)
- Dependency and script execution trust notes

## File Inventory (with Hashes)

Include a table of all in-scope files:

| File | SHA-256 | Type | Size (bytes) | Reviewed |
|---|---|---|---:|---|
| `SKILL.md` | `<hash>` | `markdown` | `<n>` | `yes` |
| `scripts/example.sh` | `<hash>` | `shell` | `<n>` | `yes` |

Notes:

- Hash algorithm MUST be SHA-256
- Paths MUST be workspace-relative inside the skill package
- Generated artifacts MAY be listed separately

## Findings (Grouped by Severity)

Create severity groups in this exact order:

1. `CRITICAL`
2. `HIGH`
3. `MEDIUM`
4. `LOW`
5. `INFO`

Each finding entry should include:

- Finding ID (`SS-<severity>-<index>`)
- Category
- File and line
- Description
- Evidence
- Remediation
- Auto-remediable flag
- OWASP alignment reference (if applicable)

## Permission Profile

Summarize requested/used permissions and risk:

- Filesystem access scope
- Network egress/ingress behavior
- Process execution behavior
- Environment variable/secret access potential
- Privilege escalation vectors

## Data Flow Summary

Describe:

- Sources (inputs, files, env vars, network)
- Processing/transformation steps
- Sinks (disk, stdout, remote endpoints)
- Trust boundaries crossed
- Data sensitivity handling

## Risk Matrix

Provide matrix entries with at least:

- Finding ID
- Severity
- Exploitability
- Blast radius
- Calculated risk score contribution

Include a compact table:

| Finding | Severity | Exploitability | Blast Radius | Score |
|---|---|---|---|---:|
| `SS-HIGH-001` | `HIGH` | `LIKELY` | `PROJECT` | `49` |

## Recommendations

Split recommendations into three groups:

### Must Fix

- Blocking issues before release/use

### Should Fix

- Important improvements with moderate risk reduction

### Nice to Have

- Hardening and maintainability improvements

## Remediation Plan

For each action include:

- Action ID
- Owner
- Priority
- ETA
- Validation method
- Residual risk after remediation

## Framework Alignment

Map findings/control posture to relevant standards where applicable:

- OWASP ASVS / Top 10 references
- SLSA / provenance expectations
- Internal secure coding or policy controls

### Markdown Template

```markdown
# skill-shield Audit Report: <skill-name>

**Report ID:** `skill-shield-report-<skill>-<timestamp>`
**Generated (UTC):** `<ISO-8601>`
**Schema Version:** `<schema-version>`

## Executive Summary
- **Verdict:** `<PASS | REVIEW | FAIL>`
- **Risk Score:** `<0-100>`
- **Provenance Confidence:** `<HIGH | MEDIUM | LOW>`
- **Top Risks:**
  - `<risk-1>`
  - `<risk-2>`
  - `<risk-3>`

<one paragraph summary>

## Skill Metadata
| Field | Value |
|---|---|
| Skill Name | `<skill-name>` |
| Skill Version | `<version>` |
| Source | `<source>` |
| Auditor | `skill-shield` |
| Audit Timestamp (UTC) | `<ISO-8601>` |
| Schema Version | `<schema-version>` |
| Total Files Reviewed | `<count>` |
| Total Findings | `<count>` |

## Trust Assessment
- **Provenance Confidence:** `<HIGH | MEDIUM | LOW>`
- **Integrity:** `<summary>`
- **Authenticity Signals:** `<summary>`
- **Dependency Trust Notes:** `<summary>`

## File Inventory (SHA-256)
| File | SHA-256 | Type | Size (bytes) | Reviewed |
|---|---|---|---:|---|
| `<path>` | `<hash>` | `<type>` | `<size>` | `yes` |

## Findings

### CRITICAL
#### SS-CRITICAL-001 - <title>
- **Category:** `<category>`
- **Location:** `<file>:<line>`
- **Description:** `<description>`
- **Evidence:** `<evidence>`
- **Remediation:** `<remediation>`
- **Auto-remediable:** `<true|false>`
- **OWASP Alignment:** `<reference>`

### HIGH
#### SS-HIGH-001 - <title>
- **Category:** `<category>`
- **Location:** `<file>:<line>`
- **Description:** `<description>`
- **Evidence:** `<evidence>`
- **Remediation:** `<remediation>`
- **Auto-remediable:** `<true|false>`
- **OWASP Alignment:** `<reference>`

### MEDIUM
<repeat finding format>

### LOW
<repeat finding format>

### INFO
<repeat finding format>

## Permission Profile
- **Filesystem:** `<scope + risk>`
- **Network:** `<scope + risk>`
- **Process Execution:** `<scope + risk>`
- **Secrets/Env Access:** `<scope + risk>`
- **Privilege Escalation Potential:** `<assessment>`

## Data Flow Summary
- **Sources:** `<list>`
- **Transformations:** `<list>`
- **Sinks:** `<list>`
- **Trust Boundaries:** `<list>`
- **Sensitive Data Handling:** `<assessment>`

## Risk Matrix
| Finding | Severity | Exploitability | Blast Radius | Score |
|---|---|---|---|---:|
| `<id>` | `<severity>` | `<factor>` | `<factor>` | `<score>` |

## Recommendations

### Must Fix
- `<action>`

### Should Fix
- `<action>`

### Nice to Have
- `<action>`

## Remediation Plan
| Action ID | Owner | Priority | ETA | Validation | Residual Risk |
|---|---|---|---|---|---|
| `<id>` | `<owner>` | `<P0-P3>` | `<date>` | `<method>` | `<level>` |

## Framework Alignment
- `<control mapping 1>`
- `<control mapping 2>`
- `<control mapping 3>`
```

---

## 2) Machine-Readable Report (JSON)

### File Name Pattern

```text
skill-shield-report-<skill>-<timestamp>.json
```

### JSON Schema (Canonical)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://skill-shield.dev/schema/report/v1.json",
  "title": "skill-shield Audit Report",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schema_version",
    "audit_timestamp",
    "skill",
    "verdict",
    "risk_score",
    "provenance_confidence",
    "trust_assessment",
    "file_inventory",
    "findings",
    "permissions",
    "data_flows",
    "blast_radius",
    "recommendations",
    "remediation_plan"
  ],
  "properties": {
    "schema_version": {
      "type": "string",
      "pattern": "^v[0-9]+\\.[0-9]+(\\.[0-9]+)?$"
    },
    "audit_timestamp": {
      "type": "string",
      "format": "date-time"
    },
    "skill": {
      "type": "object",
      "additionalProperties": false,
      "required": ["name", "version", "source", "entrypoint"],
      "properties": {
        "name": { "type": "string", "minLength": 1 },
        "version": { "type": "string", "minLength": 1 },
        "source": { "type": "string", "minLength": 1 },
        "entrypoint": { "type": "string", "minLength": 1 },
        "hash_manifest": { "type": "string" }
      }
    },
    "verdict": {
      "type": "string",
      "enum": ["PASS", "REVIEW", "FAIL"]
    },
    "risk_score": {
      "type": "number",
      "minimum": 0,
      "maximum": 100
    },
    "provenance_confidence": {
      "type": "string",
      "enum": ["HIGH", "MEDIUM", "LOW"]
    },
    "trust_assessment": {
      "type": "object",
      "additionalProperties": false,
      "required": ["integrity", "authenticity", "dependency_trust", "notes"],
      "properties": {
        "integrity": { "type": "string" },
        "authenticity": { "type": "string" },
        "dependency_trust": { "type": "string" },
        "notes": {
          "type": "array",
          "items": { "type": "string" }
        }
      }
    },
    "file_inventory": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["path", "sha256", "type", "size_bytes", "reviewed"],
        "properties": {
          "path": { "type": "string", "minLength": 1 },
          "sha256": {
            "type": "string",
            "pattern": "^[a-fA-F0-9]{64}$"
          },
          "type": { "type": "string" },
          "size_bytes": { "type": "integer", "minimum": 0 },
          "reviewed": { "type": "boolean" }
        }
      }
    },
    "findings": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "id",
          "severity",
          "category",
          "file",
          "line",
          "description",
          "evidence",
          "remediation",
          "auto_remediable",
          "owasp_alignment"
        ],
        "properties": {
          "id": {
            "type": "string",
            "pattern": "^SS-(CRITICAL|HIGH|MEDIUM|LOW|INFO)-[0-9]{3}$"
          },
          "severity": {
            "type": "string",
            "enum": ["CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO"]
          },
          "category": { "type": "string", "minLength": 1 },
          "file": { "type": "string", "minLength": 1 },
          "line": { "type": "integer", "minimum": 1 },
          "description": { "type": "string", "minLength": 1 },
          "evidence": { "type": "string", "minLength": 1 },
          "remediation": { "type": "string", "minLength": 1 },
          "auto_remediable": { "type": "boolean" },
          "owasp_alignment": {
            "type": "array",
            "items": { "type": "string" }
          }
        }
      }
    },
    "permissions": {
      "type": "object",
      "additionalProperties": false,
      "required": ["filesystem", "network", "process", "secrets", "escalation"],
      "properties": {
        "filesystem": { "type": "string" },
        "network": { "type": "string" },
        "process": { "type": "string" },
        "secrets": { "type": "string" },
        "escalation": { "type": "string" }
      }
    },
    "data_flows": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["source", "transformation", "sink", "boundary", "sensitivity"],
        "properties": {
          "source": { "type": "string" },
          "transformation": { "type": "string" },
          "sink": { "type": "string" },
          "boundary": { "type": "string" },
          "sensitivity": { "type": "string" }
        }
      }
    },
    "blast_radius": {
      "type": "string",
      "enum": ["LOCAL", "PROJECT", "ORG", "ECOSYSTEM"]
    },
    "recommendations": {
      "type": "object",
      "additionalProperties": false,
      "required": ["must_fix", "should_fix", "nice_to_have"],
      "properties": {
        "must_fix": {
          "type": "array",
          "items": { "type": "string" }
        },
        "should_fix": {
          "type": "array",
          "items": { "type": "string" }
        },
        "nice_to_have": {
          "type": "array",
          "items": { "type": "string" }
        }
      }
    },
    "remediation_plan": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["action_id", "owner", "priority", "eta", "validation", "residual_risk"],
        "properties": {
          "action_id": { "type": "string" },
          "owner": { "type": "string" },
          "priority": { "type": "string", "enum": ["P0", "P1", "P2", "P3"] },
          "eta": { "type": "string" },
          "validation": { "type": "string" },
          "residual_risk": { "type": "string", "enum": ["LOW", "MEDIUM", "HIGH"] }
        }
      }
    }
  }
}
```

---

## 3) Verdict Calculation

### Risk Score Formula

**Scoring is fully deterministic.** Every check ID has fixed exploitability and blast_radius factors defined in `references/dangerous-patterns.md`. The agent MUST look up these values — never invent or adjust them.

For each finding:

```text
finding_score = severity_weight × exploitability × blast_radius
```

Both `exploitability` and `blast_radius` are **fixed per check ID** (see the Scoring Lookup Table in `references/dangerous-patterns.md`). They are NOT subjective judgments.

Overall report score:

```text
risk_score = min(100, round(sum(all finding_scores)))
```

**The risk_score MUST equal the rounded sum of finding_scores.** No normalization, no scaling, no "provenance uplift", no adjustments of any kind. If the sum is 28.0, the risk_score is 28. If the sum is 28.5, the risk_score is 29 (standard rounding).

### Severity Weights (fixed)

```text
CRITICAL = 10
HIGH     = 7
MEDIUM   = 4
LOW      = 1
INFO     = 0
```

### Exploitability Factors (fixed per check ID — see dangerous-patterns.md)

```text
UNLIKELY = 0.5   (requires significant preconditions)
POSSIBLE = 1.0   (standard attack path)
LIKELY   = 1.5   (well-known, low barrier)
TRIVIAL  = 2.0   (self-exploiting pattern)
```

### Blast Radius Factors (fixed per check ID — see dangerous-patterns.md)

```text
LOCAL     = 0.5   (current file/process only)
PROJECT   = 1.0   (current project/repository)
ORG       = 1.5   (can reach other projects/credentials)
ECOSYSTEM = 2.0   (downstream users, registries, CI/CD)
```

### Verdict Thresholds

```text
PASS   : risk_score 0-29 AND no CRITICAL findings
REVIEW : risk_score 30-59
FAIL   : risk_score 60-100 OR any CRITICAL finding
```

Hard rules:

- Any `CRITICAL` finding forces `FAIL` regardless of score
- HIGH findings do NOT override the verdict — their risk is already reflected in the score
- No other overrides or adjustments exist
- The score shown in the verdict MUST match the sum shown in the scorecard table

### Provenance Confidence Levels

Provenance confidence is informational context displayed alongside the score. It does NOT modify the risk_score.

```text
HIGH   : verified source provenance, full hash coverage, strong authenticity signals
MEDIUM : partial provenance evidence, good integrity, limited authenticity proof
LOW    : weak/unknown provenance, integrity gaps, authenticity unverified
```

---

## 4) Output Naming Conventions

### Output Root

All generated artifacts MUST be written under:

```text
skills/skill-shield/artifacts/
```

This keeps all skill-shield output isolated alongside the skill itself. Never write to the repository root.

### Report Artifacts

All reports MUST be prefixed with:

```text
skill-shield-report-*
```

Examples:

- `skills/skill-shield/artifacts/skill-shield-report-example-skill-20260224T163501Z.md`
- `skills/skill-shield/artifacts/skill-shield-report-example-skill-20260224T163501Z.json`

### Remediated Output Package

Remediated results MUST be emitted under the artifacts directory as:

```text
skills/skill-shield/artifacts/[skill-name]-shielded/
```

Required contents:

- `SKILL.md`
- `scripts/`
- `PERMISSIONS.md`
- `CHECKSUMS.sha256`
- `PROVENANCE.md`

Recommended optional contents:

- `CHANGELOG.md`
- `REMEDIATION.md`
- `report/` (embedded copy of report artifacts)

---

## Compliance Notes

- Use UTC ISO-8601 timestamps in all report fields
- Preserve immutable finding IDs once published
- Do not omit zero-count severity sections in Markdown templates
- Keep JSON keys snake_case as defined above
- Do not substitute `skill-shield` naming with legacy labels
