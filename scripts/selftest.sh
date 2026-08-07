#!/usr/bin/env bash
# Repo-level gate: the skill size lint plus every skill's own self-test.
#
# Usage: bash scripts/selftest.sh   (exits non-zero if any check fails)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0

run() {
    local label="$1"
    shift
    echo
    echo "=== $label ==="
    if "$@"; then
        echo "--- $label: ok"
    else
        echo "--- $label: FAILED"
        failures=$((failures + 1))
    fi
}

run "skill-lint" bash "$ROOT/scripts/skill-lint.sh"

for selftest in "$ROOT"/skills/*/tests/selftest.sh; do
    [ -e "$selftest" ] || continue
    skill="$(basename "$(dirname "$(dirname "$selftest")")")"
    run "$skill selftest" bash "$selftest"
done

echo
if [ "$failures" -gt 0 ]; then
    echo "selftest: $failures suite(s) failed"
    exit 1
fi
echo "selftest: all suites passed"
