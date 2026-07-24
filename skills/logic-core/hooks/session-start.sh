#!/usr/bin/env bash
# logic-core: Claude Code SessionStart hook (Layer-2 orientation, not enforcement).
#
# Emits a single line of context when decision-trail tracking is active for the
# current checkout, so the agent knows to log decisions. Silent when tracking is
# off or the runtime is absent. Wire it in .claude/settings.json:
#   { "hooks": { "SessionStart": [ { "hooks":
#       [ { "type":"command", "command":"bash .logic/hooks/session-start.sh" } ] } ] } }

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

  msg="Decision-trail tracking is ON for branch '${logical}' (storage: ${storage}). Log decision points as you work — a fork chosen, a unit finished with its check, a pivot or revert — with /track-logic \"<what> because <why>\" --confidence <high|medium|low> or the logic-core log helper. Confidence is your perception, not a correctness score; commit stubs and unassessed legacy rows remain unknown. Commit stubs are captured automatically; give the ones that mattered a one-line 'why' and confidence before finishing. The row protocol lives in the track-logic skill."

  # Surface anything the hooks recorded silently (e.g. a backend downgrade),
  # then clear it so it is reported once per session rather than forever.
  wfile="$root/.logic/WARNINGS"
  if [ -s "$wfile" ]; then
    msg="${msg}

Decision-trail warnings (shown once):
$(cat "$wfile" 2>/dev/null)"
    : >"$wfile" 2>/dev/null
  fi

  if command -v jq >/dev/null 2>&1; then
    printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' \
      "$(printf '%s' "$msg" | jq -Rs .)"
  else
    printf '%s\n' "$msg"
  fi
} 2>/dev/null

exit 0
