#!/usr/bin/env bash
# logic-core: enable or disable decision-trail tracking for a branch.
# Backs /toggle-track-logic.
#
# Usage:
#   toggle.sh [on|off] [branch]
#     no state  -> flip the current effective state for the branch
#     no branch -> the current checkout's branch
# Always ends by printing the resulting state and scope.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib.sh"

command -v jq >/dev/null 2>&1 || { echo "logic: jq is required" >&2; exit 1; }
logic_repo_root >/dev/null || { echo "logic: not inside a git repo" >&2; exit 1; }

want=""; branch=""
for a in "$@"; do
  case "$a" in
    on|off) want="$a" ;;
    *) branch="$a" ;;
  esac
done
[ -z "$branch" ] && branch="$(logic_current_branch)"

"$SCRIPT_DIR/config-edit.sh" init >/dev/null

# Current effective state for the *target* branch. If it is the current
# checkout we can read it directly; otherwise consult the config key.
if [ "$branch" = "$(logic_current_branch)" ]; then
  read -r cur_state _ _ <<EOF
$(logic_effective_state)
EOF
else
  cur_state="$("$SCRIPT_DIR/config-edit.sh" get ".branches[\"$branch\"]")"
  [ -z "$cur_state" ] && cur_state="$("$SCRIPT_DIR/config-edit.sh" get '.default')"
  [ -z "$cur_state" ] && cur_state="off"
fi

if [ -z "$want" ]; then
  if [ "$cur_state" = "on" ]; then want="off"; else want="on"; fi
fi

"$SCRIPT_DIR/config-edit.sh" set-branch "$branch" "$want" >/dev/null

installed_note=""
if [ "$want" = "on" ]; then
  installed_note="$("$SCRIPT_DIR/install-hooks.sh")"
fi

# Report resulting effective state (read fresh).
if [ "$branch" = "$(logic_current_branch)" ]; then
  read -r state logical storage <<EOF
$(logic_effective_state)
EOF
else
  state="$want"; logical="$branch"; storage="$("$SCRIPT_DIR/config-edit.sh" get '.storage')"; [ -z "$storage" ] && storage="beads"
fi

state_uc=$(printf '%s' "$state" | tr '[:lower:]' '[:upper:]')
echo "Decision-trail tracking is now ${state_uc} for '${logical}' (storage: ${storage})."
if [ "$branch" != "$(logic_current_branch)" ]; then
  echo "  (set for branch '${branch}', which is not the current checkout — it takes effect there)"
fi
echo "  config: $("$SCRIPT_DIR/config-edit.sh" path)"
[ -n "$installed_note" ] && { echo; echo "$installed_note"; }
