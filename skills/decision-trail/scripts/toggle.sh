#!/usr/bin/env bash
# decision-trail: enable or disable decision-trail tracking for a branch.
# Backs /decision-trail toggle.
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

command -v jq >/dev/null 2>&1 || { echo "decision-trail: jq is required" >&2; exit 1; }
dt_repo_root >/dev/null || { echo "decision-trail: not inside a git repo" >&2; exit 1; }

want=""; branch=""
for a in "$@"; do
  case "$a" in
    on|off) want="$a" ;;
    *) branch="$a" ;;
  esac
done
[ -z "$branch" ] && branch="$(dt_current_branch)"

"$SCRIPT_DIR/config-edit.sh" init >/dev/null

# Current effective state for the *target* branch. If it is the current
# checkout we can read it directly; otherwise consult the config key.
if [ "$branch" = "$(dt_current_branch)" ]; then
  read -r cur_state _ _ <<EOF
$(dt_effective_state)
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
if [ "$branch" = "$(dt_current_branch)" ]; then
  read -r state logical storage <<EOF
$(dt_effective_state)
EOF
else
  state="$want"; logical="$branch"; storage="$("$SCRIPT_DIR/config-edit.sh" get '.storage')"; [ -z "$storage" ] && storage="beads"
fi

state_uc=$(printf '%s' "$state" | tr '[:lower:]' '[:upper:]')
echo "Decision-trail tracking is now ${state_uc} for '${logical}' (storage: ${storage})."
if [ "$branch" != "$(dt_current_branch)" ]; then
  # Be honest: the edit landed in THIS checkout's config. It governs the target
  # branch only once that config is present on it.
  echo
  echo "  NOTE: '${branch}' is not the current checkout. The config change was written to"
  echo "  this checkout's .decision-trail/config.json, so it does NOT apply on '${branch}' yet."
  other_wt=$(git worktree list --porcelain 2>/dev/null \
    | awk -v b="branch refs/heads/${branch}" '/^worktree /{w=$2} $0==b{print w; exit}')
  if [ -n "$other_wt" ]; then
    echo "  '${branch}' is checked out at: ${other_wt}"
    echo "  Run /decision-trail toggle from there for it to take effect immediately."
  else
    echo "  Commit this change and get it onto '${branch}' for it to take effect:"
    echo "    git add .decision-trail/config.json && git commit -m \"chore: track ${branch}\""
    echo "    # then merge or cherry-pick that commit into ${branch}, or re-run the toggle from a checkout of it"
  fi
fi
echo "  config: $("$SCRIPT_DIR/config-edit.sh" path)"
dt_warn_stderr
[ -n "$installed_note" ] && { echo; echo "$installed_note"; }
