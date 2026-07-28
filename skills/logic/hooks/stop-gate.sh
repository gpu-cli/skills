#!/usr/bin/env bash
# logic: Claude Code Stop hook (Layer-2 enrichment gate).
#
# When the turn touched a tracked branch and left commit stubs with no 'why',
# blocks completion ONCE to ask the agent to enrich the ones that represent real
# decisions. Guarded by stop_hook_active so it fires once and never loops. Wire
# it in .claude/settings.json:
#   { "hooks": { "Stop": [ { "hooks":
#       [ { "type":"command", "command":"bash .logic/hooks/stop-gate.sh" } ] } ] } }

input=$(cat 2>/dev/null)

# Never loop: if we already blocked once this turn, let the agent stop.
active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$active" = "true" ] && exit 0

{
  root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
  lib="$root/.logic/runtime/logic.sh"
  [ -f "$lib" ] || exit 0
  # shellcheck source=/dev/null
  . "$lib" 2>/dev/null || exit 0

  read -r state logical storage <<EOF
$(logic_effective_state)
EOF
  [ "$state" = "on" ] || exit 0
  # Enrichment gate is only meaningful for the beads backend (labels + update).
  # An incompatible bd already downgrades storage to tsv upstream of this.
  [ "$storage" = "beads" ] || exit 0
  logic_bd_ok || exit 0
  command -v jq >/dev/null 2>&1 || exit 0

  slug=$(logic_slug "$logical")
  count=$(bd query "label=logic:${slug}" --all --json 2>/dev/null \
    | jq '[.[] | select((.labels // []) | index("logic-stub"))] | length' 2>/dev/null)
  [ -z "$count" ] && count=0

  if [ "$count" -gt 0 ]; then
    reason="Decision trail: ${count} commit stub(s) on '${logical}' have no recorded 'why' yet. Before finishing, enrich the ones that represent a real decision (a fork, a non-obvious approach, a revert): set the why and your perceived confidence (high, medium, or low) via the logic enrich helper or restate it with /logic track. Leave purely mechanical commits (formatting, renames, trivial fixes) as stubs with unknown confidence — they expire in gc. If ALL ${count} are mechanical, say so briefly and stop."
    printf '{"decision":"block","reason":%s}\n' "$(printf '%s' "$reason" | jq -Rs .)"
  fi
} 2>/dev/null

exit 0
