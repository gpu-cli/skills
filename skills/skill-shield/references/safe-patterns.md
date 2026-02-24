# Safe Patterns Reference

This reference defines known-safe implementation patterns for agent skills.
It serves as:

- A baseline for security comparison during reviews
- A template library for remediation and hardening
- A source of copy-paste safe defaults

Use these patterns unless a documented exception is approved.

---

## 1) Shell Script Best Practices

### 1.1 Defensive Header Pattern

Use strict mode at the top of every script and fail early.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Optional hardening for glob behavior where relevant
shopt -s failglob 2>/dev/null || true

# Consistent umask for generated files
umask 077

main() {
  printf 'Script started safely\n'
}

main "$@"
```

Why this is safe:

- `set -e`: exits when commands fail
- `set -u`: fails on undefined variables
- `set -o pipefail`: propagates pipeline errors
- `umask 077`: prevents world-readable sensitive artifacts

---

### 1.2 Quoted Variable Expansion Pattern

Always quote variable expansions, command substitutions, and paths.

```bash
#!/usr/bin/env bash
set -euo pipefail

input_path="${1:-}"
output_dir="${2:-./out}"

if [[ -z "${input_path}" ]]; then
  printf 'Usage: %s <input-path> [output-dir]\n' "$0" >&2
  exit 2
fi

mkdir -p "${output_dir}"
cp -- "${input_path}" "${output_dir}/"

file_name="$(basename -- "${input_path}")"
printf 'Copied %s to %s\n' "${file_name}" "${output_dir}"
```

Why this is safe:

- Prevents word splitting and glob expansion issues
- Handles spaces and special characters in paths correctly
- `--` protects against option-injection via filenames

---

### 1.3 Secure Temporary Files Pattern (`mktemp`)

Create unique temporary files/directories and clean up with traps.

```bash
#!/usr/bin/env bash
set -euo pipefail

tmp_dir="$(mktemp -d)"
tmp_file="$(mktemp "${tmp_dir}/payload.XXXXXX")"

cleanup() {
  rm -rf -- "${tmp_dir}"
}
trap cleanup EXIT INT TERM

printf 'temporary content\n' > "${tmp_file}"
chmod 600 "${tmp_file}"

printf 'Using temp file: %s\n' "${tmp_file}"
```

Why this is safe:

- Avoids predictable names in `/tmp`
- Prevents race conditions and symlink attacks
- Ensures temp artifacts are removed on exit

---

### 1.4 Tool Availability Checks Pattern

Check all required tools before doing work.

```bash
#!/usr/bin/env bash
set -euo pipefail

require_tool() {
  local tool="$1"
  if ! command -v "${tool}" >/dev/null 2>&1; then
    printf 'Required tool not found: %s\n' "${tool}" >&2
    exit 127
  fi
}

require_tool git
require_tool jq
require_tool sha256sum

printf 'All required tools are available\n'
```

Why this is safe:

- Fails fast with clear diagnostics
- Prevents partial execution in unknown environments
- Reduces undefined behavior from missing dependencies

---

### 1.5 Scoped File Operations Pattern

Restrict file operations to an explicit allowed root.

```bash
#!/usr/bin/env bash
set -euo pipefail

allowed_root="$(realpath "${1:-.}")"
target_rel="${2:-reports/output.txt}"
target_abs="$(realpath -m "${allowed_root}/${target_rel}")"

if [[ "${target_abs}" != "${allowed_root}"* ]]; then
  printf 'Refusing path outside allowed root: %s\n' "${target_abs}" >&2
  exit 3
fi

mkdir -p "$(dirname -- "${target_abs}")"
printf 'safe output\n' > "${target_abs}"
printf 'Wrote %s\n' "${target_abs}"
```

Why this is safe:

- Blocks directory traversal (`../`)
- Constrains writes to intended workspace only
- Produces deterministic write scope for audits

---

### 1.6 Read-Only Git Operations Pattern

Use read-only Git commands by default; avoid mutating repository state.

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"

git -C "${repo_root}" status --short
git -C "${repo_root}" log --oneline -n 20
git -C "${repo_root}" diff --stat

# Allowed read-only object inspection
head_commit="$(git -C "${repo_root}" rev-parse HEAD)"
git -C "${repo_root}" show --name-only --pretty=fuller "${head_commit}"
```

Why this is safe:

- Uses non-destructive inspection commands only
- Avoids accidental workspace mutation
- Supports auditable evidence gathering workflows

---

### 1.7 Explicit Path Validation Pattern

Validate all user-provided paths for existence, type, and containment.

```bash
#!/usr/bin/env bash
set -euo pipefail

validate_input_file() {
  local input="$1"
  local allowed_root="$2"

  local input_abs
  input_abs="$(realpath "${input}")"
  local root_abs
  root_abs="$(realpath "${allowed_root}")"

  if [[ ! -f "${input_abs}" ]]; then
    printf 'Input is not a regular file: %s\n' "${input_abs}" >&2
    return 1
  fi

  if [[ "${input_abs}" != "${root_abs}"* ]]; then
    printf 'Input file is outside allowed root: %s\n' "${input_abs}" >&2
    return 1
  fi

  return 0
}

root="${1:-.}"
candidate="${2:-README.md}"

validate_input_file "${candidate}" "${root}"
printf 'Validated path safely\n'
```

Why this is safe:

- Enforces file type expectations
- Prevents out-of-scope reads/writes
- Normalizes path checks with canonical absolute paths

---

## 2) `SKILL.md` Instruction Best Practices

Use this structure to make skill behavior explicit, reviewable, and safe.

### 2.1 Template: Safe `SKILL.md`

```markdown
# Skill: Repository Audit Reporter

## Purpose
Generate a repository audit report from read-only evidence.

## Scope
- Allowed: read repository metadata, inspect tracked files, generate report
- Not allowed: modifying code, deleting files, changing git history

## Inputs
- Repository path (required)
- Output filename (optional; defaults to audit-report.md)

## Output Directory
- All generated files must be written under: ./artifacts/audit/
- Never write outside this directory without explicit user approval

## Workflow
1. Validate repository path and required tools
2. Collect read-only git evidence (`status`, `log`, `diff --stat`)
3. Produce findings and severity labels
4. Write report to output directory

## Quality Gates
- Must include evidence links for every finding
- Must include generation timestamp in UTC
- Must fail if required tools are unavailable
- Must produce deterministic section headings

## Graceful Degradation
If optional tools are unavailable:
- Continue with reduced data
- Add a "Limitations" section
- Include exact missing-tool names

## High-Impact Actions
- Any destructive or state-changing action requires user confirmation
- Examples: `git clean`, branch deletion, permission changes, remote push

## Anti-Patterns
- Running mutation commands in discovery phase
- Writing files outside declared output directory
- Silent fallback that hides missing evidence
- Using unvalidated user input as shell commands

## Resume After Compaction
- Persist checkpoint to `./artifacts/audit/.checkpoint.json`
- Include: completed step IDs, tool availability map, output path
- On resume, reload checkpoint and continue from next incomplete step
```

Why this is safe:

- Defines intent and boundaries clearly
- Prevents hidden side effects
- Makes behavior predictable during reruns and compaction

---

### 2.2 High-Impact Confirmation Prompt Pattern

```markdown
Before proceeding, I need confirmation for a high-impact action.

Action: Delete generated artifact directory `./artifacts/audit/`
Impact: Permanently removes previous reports and checkpoints
Safer alternative: Write to a new timestamped directory

Reply with one of:
- `confirm delete artifacts`
- `use timestamped output` (recommended)
```

Why this is safe:

- Uses explicit action and impact language
- Offers a safer default
- Requires unambiguous confirmation phrase

---

### 2.3 Graceful Degradation Output Pattern

```markdown
## Limitations
- Optional tool unavailable: `trivy`
- Dependency missing: vulnerability DB could not be queried
- Degraded behavior: skipped container CVE scan

## Effect on Findings
- SAST findings: complete
- Dependency findings: complete
- Container findings: partial
```

Why this is safe:

- Avoids false confidence in incomplete results
- Preserves transparency for downstream consumers

---

## 3) Permission Declaration Template (`PERMISSIONS.md`)

Use this as a baseline declaration for skills.

### 3.1 Template: `PERMISSIONS.md`

```markdown
# Permissions Declaration

## Filesystem Access
| Path | Access | Purpose | Notes |
|---|---|---|---|
| `./` | read | Inspect repository content | No write operations |
| `./artifacts/audit/` | write | Store generated reports | Must stay in subtree |
| `/tmp/` | write | Ephemeral intermediate files | Use `mktemp`; delete on exit |

## Network Access
| Destination | Method | Required | Purpose |
|---|---|---|---|
| `api.github.com` | HTTPS GET | Optional | Fetch metadata for references |
| `security.example.com` | HTTPS GET | Optional | Pull vulnerability advisories |

## Tool Access
| Tool | Mode | Required | Purpose |
|---|---|---|---|
| `git` | read-only commands | Yes | Gather repository evidence |
| `jq` | local processing | Yes | Parse structured JSON data |
| `sha256sum` | local processing | Yes | Generate integrity hashes |
| `curl` | outbound HTTPS | Optional | Retrieve external advisories |

## Sensitive Data Handling
- Never print secrets, access tokens, or credentials
- Redact high-risk values from logs and reports
- Do not persist secrets in checkpoints or artifacts
- Prefer environment-variable references over literal values

## Excluded Capabilities
- No destructive git commands (`reset --hard`, `clean -fdx`, force-push)
- No permission broadening (`chmod -R 777`)
- No arbitrary command execution from untrusted input
- No writes outside declared output directories
```

Why this is safe:

- Makes permissions explicit and reviewable
- Narrows privilege to least necessary scope
- Documents forbidden actions for policy enforcement

---

## 4) Integrity Bundle Template

Integrity bundles make generated assets verifiable and auditable.

### 4.1 `CHECKSUMS.sha256` Format

Rules:

- One entry per line
- Format: `<sha256><two spaces><relative-path>`
- Paths are relative to bundle root
- Include all material outputs and metadata files

Example:

```text
4b1c4f0a6a8c2f5f3f472f0a4dd7fbb8d2b37e501dc6f6a80cfd84b3a53cc6a6  artifacts/audit/report.md
f9334fbc2d1d45f20994f3b8eab3111f2de47f70fdb3d7a31a8f987ca6b3db2e  artifacts/audit/findings.json
e2cc4ec7f9ccf7e84e8b2636cf130fc81d3fd5f2eb66a761af7de6beed2eeb4b  artifacts/audit/.checkpoint.json
13c7f2b0142f13ac7cce2c2e209fbb07eb2eff8ebf8e0c39e63f2ee4c6e4af21  PROVENANCE.md
```

Verification example:

```bash
#!/usr/bin/env bash
set -euo pipefail

bundle_root="${1:-.}"
cd "${bundle_root}"
sha256sum --check CHECKSUMS.sha256
```

---

### 4.2 `PROVENANCE.md` Format

Rules:

- Include source inputs and versions
- Include audit date/time in UTC
- Include findings summary and modification log
- Include references to integrity artifacts

Template:

```markdown
# Provenance Record

## Source
- Repository: `https://example.com/org/repo.git`
- Commit: `abc123def4567890abc123def4567890abc123de`
- Base branch: `main`
- Input files:
  - `src/security/policy.yaml`
  - `scripts/audit.sh`

## Audit Metadata
- Auditor: `agent-skill-shield`
- Audit date (UTC): `2026-02-24T10:35:42Z`
- Environment:
  - OS: `darwin`
  - Toolchain:
    - `git 2.49.0`
    - `jq 1.7`
    - `sha256sum (GNU coreutils) 9.5`

## Findings
- Total findings: `7`
- Critical: `0`
- High: `1`
- Medium: `3`
- Low: `3`

## Modifications
- Generated files only:
  - `artifacts/audit/report.md`
  - `artifacts/audit/findings.json`
  - `artifacts/audit/.checkpoint.json`
- No source files modified

## Integrity References
- Checksums file: `CHECKSUMS.sha256`
- Verification command:
  - `sha256sum --check CHECKSUMS.sha256`
- Signature status: `unsigned`

## Notes
- Optional network advisory feed unavailable during run
- Container scan marked as partial in report limitations
```

---

### 4.3 Integrity Bundle Generation Script Pattern

```bash
#!/usr/bin/env bash
set -euo pipefail

require_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Missing tool: %s\n' "$1" >&2
    exit 127
  }
}

require_tool sha256sum
require_tool date

bundle_root="$(realpath "${1:-.}")"
artifact_dir="${bundle_root}/artifacts/audit"
provenance_file="${bundle_root}/PROVENANCE.md"
checksum_file="${bundle_root}/CHECKSUMS.sha256"

if [[ ! -d "${artifact_dir}" ]]; then
  printf 'Artifact directory missing: %s\n' "${artifact_dir}" >&2
  exit 2
fi

if [[ ! -f "${provenance_file}" ]]; then
  printf 'Provenance file missing: %s\n' "${provenance_file}" >&2
  exit 2
fi

tmp_list="$(mktemp)"
trap 'rm -f -- "${tmp_list}"' EXIT INT TERM

{
  find "${artifact_dir}" -type f | LC_ALL=C sort
  printf '%s\n' "${provenance_file}"
} > "${tmp_list}"

(
  cd "${bundle_root}"
  while IFS= read -r abs_path; do
    rel_path="${abs_path#${bundle_root}/}"
    sha256sum "${rel_path}"
  done < "${tmp_list}" > "${checksum_file}"
)

printf 'Generated %s\n' "${checksum_file}"
printf 'Audit timestamp (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
```

Why this is safe:

- Enforces required input presence
- Generates deterministic checksum coverage
- Uses temporary files safely with cleanup trap

---

## 5) Cross-Pattern Review Checklist

Use this checklist during review or remediation.

- Script starts with `#!/usr/bin/env bash` and `set -euo pipefail`
- Variables, paths, and substitutions are always quoted
- Temporary files use `mktemp` and cleanup traps
- Required tools are validated before execution
- File operations are constrained to explicit roots
- Git commands are read-only unless confirmed by user
- `SKILL.md` declares scope, output directory, and quality gates
- `SKILL.md` includes graceful degradation and anti-patterns
- `SKILL.md` includes resume-after-compaction checkpoint plan
- `PERMISSIONS.md` documents filesystem/network/tool access explicitly
- Sensitive data handling and excluded capabilities are explicit
- Integrity bundle includes both `CHECKSUMS.sha256` and `PROVENANCE.md`

If any item fails, classify as remediation required before release.
