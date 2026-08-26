#!/usr/bin/env bash
# decision-trail: clean up decision rows whose branch was deleted without merging.
#
# A row is an orphan when its commit SHA is reachable from no branch (the branch
# was deleted unmerged, or the commit was rebased away). Rows whose SHA is
# contained in any branch — including merged mainline history — are kept. Rows
# with no SHA (manual entries) are never auto-removed.
#
# Usage: gc.sh [--apply] [branch]
#   default: dry run, lists candidates. --apply: bd delete them.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib.sh"

command -v jq >/dev/null 2>&1 || { echo "decision-trail: jq required" >&2; exit 1; }
if ! dt_bd_ok; then
  dt_warn_stderr
  echo "decision-trail: gc applies to the beads backend. TSV trails are append-only — remove .decision-trail/audit/<branch>/ directly when a branch is abandoned." >&2
  exit 0
fi

apply=0; branch=""
for a in "$@"; do
  case "$a" in
    --apply) apply=1 ;;
    --*) ;;
    *) branch="$a" ;;
  esac
done

# All decision-trail rows (optionally scoped to one branch).
all=$(bd query "type=decision" --all --json 2>/dev/null | jq '[.[] | select((.labels//[]) | map(startswith("decision-trail:")) | any)]')
[ -z "$all" ] && all='[]'
if [ -n "$branch" ]; then
  all=$(printf '%s' "$all" | jq --arg b "$branch" '[.[] | select((.metadata.branch // "")==$b)]')
fi

candidates="$(mktemp 2>/dev/null || echo /tmp/decision-trail-gc.$$)"; : >"$candidates"
printf '%s' "$all" | jq -c '.[]' | while IFS= read -r row; do
  id=$(printf '%s' "$row" | jq -r '.id')
  sha=$(printf '%s' "$row" | jq -r '.metadata.sha // ""')
  br=$(printf '%s' "$row" | jq -r '.metadata.branch // ""')
  dec=$(printf '%s' "$row" | jq -r '.title // ""')
  [ -z "$sha" ] && continue    # keep manual rows without a sha
  # Reachable from any branch? Then keep.
  if git branch -a --contains "$sha" >/dev/null 2>&1; then
    n=$(git branch -a --contains "$sha" 2>/dev/null | grep -c .)
    [ "${n:-0}" -gt 0 ] && continue
  fi
  printf '%s\t%s\t%s\n' "$id" "$br" "$dec" >>"$candidates"
done

if [ ! -s "$candidates" ]; then
  echo "gc: no orphaned decision rows."
  rm -f "$candidates"; exit 0
fi

count=$(wc -l <"$candidates" | tr -d ' ')
echo "gc: ${count} orphaned decision row(s) (branch deleted unmerged / commit gone):"
while IFS=$'\t' read -r id br dec; do
  printf -- '- %s  [%s]  %s\n' "$id" "$br" "$dec"
done <"$candidates"

if [ "$apply" -eq 1 ]; then
  ids=$(cut -f1 "$candidates" | tr '\n' ' ')
  # shellcheck disable=SC2086
  bd delete $ids --force >/dev/null 2>&1 && echo "gc: deleted ${count} row(s)." || echo "gc: delete failed." >&2
else
  echo
  echo "Dry run. Re-run with --apply to delete."
fi
rm -f "$candidates"
