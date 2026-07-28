#!/usr/bin/env bash
# logic: print the effective tracking state for the current checkout.
#
# Usage: resolve-branch.sh [--json]
# Plain output: "<state> <logical-branch> <storage>"  (state = on|off)
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib.sh"

read -r state logical storage <<EOF
$(logic_effective_state)
EOF

if [ "${1:-}" = "--json" ]; then
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg s "$state" --arg l "$logical" --arg t "$storage" --arg b "$(logic_current_branch)" \
      '{state:$s, logicalBranch:$l, storage:$t, currentBranch:$b}'
  else
    printf '{"state":"%s","logicalBranch":"%s","storage":"%s"}\n' "$state" "$logical" "$storage"
  fi
else
  printf '%s %s %s\n' "$state" "$logical" "$storage"
fi
