#!/usr/bin/env bash
# logic-core: render collected rows (JSON array on stdin) as Markdown tables.
#
# One table per stream (worktree), the current checkout first, then a summary.
# Stub rows show "(no why — stub)" so unrecorded reasoning is visible. Output is
# Markdown so it reads cleanly in a terminal and can be pushed to a PR verbatim.
#
# Usage: collect.sh <branch> | render.sh [--title "..."]
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib.sh"

title="Decision trail"
[ "${1:-}" = "--title" ] && { title="$2"; shift 2; }

command -v jq >/dev/null 2>&1 || { echo "logic: jq is required for render" >&2; exit 1; }

data=$(cat)
[ -z "$data" ] && data='[]'

total=$(printf '%s' "$data" | jq 'length' 2>/dev/null); [ -z "$total" ] && total=0
if [ "$total" -eq 0 ]; then
  echo "## ${title}"
  echo
  echo "_No decision rows found for this branch._"
  exit 0
fi

stubs=$(printf '%s' "$data" | jq '[.[] | select(.stub)] | length')
this_root="$(logic_repo_root)"

echo "## ${title}"
echo
echo "_${total} row(s), ${stubs} unenriched stub(s)._"
echo

# Stream order: current checkout first, then the rest alphabetically.
streams=$(printf '%s' "$data" | jq -r --arg here "$this_root" '
  ([.[].worktree] | map(select(length>0)) | unique) as $all
  | ($all | map(select(.==$here))) + ($all | map(select(.!=$here)) | sort)
  | .[]')

# Rows with no worktree recorded (e.g. older/TSV) get a catch-all stream.
has_blank=$(printf '%s' "$data" | jq '[.[] | select((.worktree//"")=="")] | length')

emit_table() {
  local sel="$1" heading="$2"
  local branch actors
  branch=$(printf '%s' "$data" | jq -r "$sel | .[0].branch // \"\"")
  actors=$(printf '%s' "$data" | jq -r "[$sel | .[].actor] | unique | join(\", \")")
  echo "### ${heading}"
  [ -n "$branch" ] && echo "_branch: ${branch} — actors: ${actors}_" || echo "_actors: ${actors}_"
  echo
  echo "| ts | actor | phase | decision | why | evidence | result |"
  echo "|---|---|---|---|---|---|---|"
  printf '%s' "$data" | jq -r "
    $sel | sort_by(.ts) | .[] |
    \"| \(.ts) | \(.actor) | \(.phase) | \(.decision|gsub(\"\\\\|\";\"\\\\|\")) | \(if .stub then \"⚠ (no why — stub)\" else (.why|gsub(\"\\\\|\";\"\\\\|\")) end) | \(.evidence) | \(.result) |\""
  echo
}

if [ -n "$streams" ]; then
  printf '%s\n' "$streams" | while IFS= read -r s; do
    [ -z "$s" ] && continue
    label="$s"
    [ "$s" = "$this_root" ] && label="$s (this checkout)"
    emit_table "[.[] | select(.worktree==\"$s\")]" "Stream: ${label}"
  done
fi
if [ "$has_blank" -gt 0 ]; then
  emit_table '[.[] | select((.worktree//"")=="")]' "Stream: (unattributed)"
fi

if [ "$stubs" -gt 0 ]; then
  echo "> ${stubs} row(s) are commit stubs with no recorded reasoning. Enrich the ones that mattered with /track-logic or the enrich helper; the rest can be left for gc."
fi
