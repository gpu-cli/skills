# Trust Policy Reference

The trust policy defines the baseline posture for evaluating skill provenance, publisher identity, and source integrity. It is inspired by SLSA (Supply-chain Levels for Software Artifacts), OpenSSF Scorecard, and CISA Secure-by-Design guidance.

## Default Posture

**Deny by default.** Every skill starts at zero trust and must earn a passing score through transparent, verifiable properties. The absence of evidence is treated as a risk signal, not a neutral state.

## Trust Dimensions

### 1. Source Pinning

| Signal | Verdict | Rationale |
|--------|---------|-----------|
| Installed via `owner/repo@commit-sha` | PASS | Immutable reference; content cannot change after install |
| Installed via `owner/repo@tag` (signed tag) | PASS | Verifiable release with cryptographic attestation |
| Installed via `owner/repo@tag` (unsigned) | WARN | Tag could be force-pushed; mutable reference |
| Installed via `owner/repo` (no ref) | WARN | Tracks HEAD of default branch; content changes silently |
| Installed via `owner/repo@branch` | WARN | Branch ref is mutable; content drifts without notice |
| Source origin unknown or unresolvable | FAIL | No provenance chain; cannot verify anything |

### 2. Publisher Identity

| Signal | Verdict | Rationale |
|--------|---------|-----------|
| Publisher is in local allowlist | PASS | Explicitly trusted by the user |
| GitHub org with 2FA enforced, multiple contributors, active history | PASS | Strong identity signals (OpenSSF Scorecard criteria) |
| Single-contributor repo, recently created, no stars/forks | WARN | Low community trust signal; could be typosquat |
| Publisher account age < 90 days | WARN | New accounts are higher risk for impersonation |
| Publisher in local denylist (`known-bad-skills.yaml`) | FAIL | Explicitly blocked |

### 3. Repository Health (Provenance Confidence Score)

These signals are inspired by OpenSSF Scorecard checks. When the skill is sourced from a GitHub repo, assess:

| Signal | Weight | Description |
|--------|--------|-------------|
| Branch protection enabled | +2 | Prevents direct pushes to main/default branch |
| Signed commits/tags | +2 | Cryptographic authorship verification |
| Multiple contributors | +1 | Reduces single-point-of-compromise risk |
| Active maintenance (commits in last 90 days) | +1 | Maintained projects get security fixes faster |
| Security policy present (`SECURITY.md`) | +1 | Shows security-aware publisher |
| License declared | +1 | Transparent terms of use |
| CI/CD pipeline present | +1 | Automated quality gates |
| Dependency update tooling | +1 | Reduced stale dependency risk |

**Provenance confidence score**: Sum of weights (0-10).
- 7-10: HIGH confidence
- 4-6: MEDIUM confidence
- 0-3: LOW confidence

### 4. Content Integrity

| Signal | Verdict | Rationale |
|--------|---------|-----------|
| All files have SHA-256 hashes recorded at install time | PASS | Enables tamper detection on re-audit |
| File hashes match previous audit | PASS | Content unchanged since last review |
| File hashes differ from previous audit | WARN | Content changed; re-audit required |
| No previous hash baseline exists | INFO | First audit; establish baseline now |
| Binary files present in skill directory | WARN | Binaries cannot be inspected; opaque risk |

### 5. Update Drift Detection

Skills installed from mutable refs (branches, untagged HEAD) can silently change. The trust policy defines:

- **On first audit**: Record SHA-256 of all files + git commit SHA (if available) as baseline.
- **On re-audit**: Compare current hashes to baseline.
- **If drift detected**: Automatically escalate all findings by one severity level and flag for manual review.
- **Recommendation**: Always pin to immutable refs (`@commit-sha` or `@signed-tag`).

## Local Policy Files

### Allowlist (`trusted-publishers.yaml`)

Users can maintain a local allowlist of trusted publishers:

```yaml
# ~/.config/opencode/skill-shield/trusted-publishers.yaml
trusted:
  - owner: gpu-cli
    reason: "First-party skills from this repository"
  - owner: vercel-labs
    reason: "Verified corporate publisher"
  - owner: ComposioHQ
    reason: "Well-known skill publisher"
```

### Denylist (`known-bad-skills.yaml`)

A local denylist for skills that have been flagged:

```yaml
# ~/.config/opencode/skill-shield/known-bad-skills.yaml
blocked:
  - pattern: "*/crypto-miner-*"
    reason: "Known malicious skill pattern"
    date_added: "2026-01-15"
  - pattern: "suspicious-user/helpful-skill"
    reason: "Reported data exfiltration via WebSearch"
    date_added: "2026-02-01"
```

### Egress Declaration (`PERMISSIONS.md`)

Every audited/remediated skill should include a `PERMISSIONS.md` that declares:

```markdown
# Permissions Declaration

## Filesystem Access
- READ: Project directory (git diffs, source files)
- WRITE: `social-posts/` output directory only

## Network Access
- WebSearch: Platform best practices research (twitter, linkedin, bluesky)
- No outbound data upload

## Tool Access
- git (read-only: log, diff, rev-parse)
- freeze (screenshot generation, optional)
- asciinema (terminal recording, optional)

## Sensitive Data Handling
- Git diffs may contain secrets; quality gate checks for exposed credentials
- Screenshots are checked for sensitive content before inclusion
```

## Hard Fail Conditions

The following conditions result in an automatic `FAIL` verdict regardless of other scores:

1. Skill is in the local denylist
2. Skill contains executable code that contacts unknown external domains
3. Skill instructions contain explicit prompt override/injection patterns
4. Skill reads well-known credential paths (`~/.ssh/`, `~/.aws/`, `~/.env`)
5. Skill installs persistence mechanisms (cron, shell profile modification)
6. Skill contains obfuscated/encoded executable payloads
7. Source origin is completely unresolvable

## OWASP / Framework Alignment

| Trust Dimension | OWASP LLM Risk | NIST AI RMF | SLSA Level |
|----------------|----------------|-------------|------------|
| Source Pinning | LLM03 Supply Chain | Map: Provenance | Build L1+ |
| Publisher Identity | LLM03 Supply Chain | Govern: Policies | Build L2+ |
| Repository Health | LLM03 Supply Chain | Measure: Metrics | Build L1+ |
| Content Integrity | LLM03 Supply Chain | Manage: Monitor | Build L2+ |
| Egress Declaration | LLM06 Excessive Agency | Govern: Constraints | N/A |
