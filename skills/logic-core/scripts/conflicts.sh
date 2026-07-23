#!/usr/bin/env bash
# logic-core: mechanical conflict pre-filters between parallel worktree streams.
#
# Feeds the model's tier-3 judgment. Emits JSON:
#   tier1 — territory overlap: a file touched by rows from >1 worktree
#   tier2 — real textual conflicts from git merge-tree between stream branches
# The model reads the paired rows and decides which overlaps are genuine
# semantic contradictions. A clean result means "none detected", not "none exist".
#
# Usage: conflicts.sh [branch]
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib.sh"

command -v jq >/dev/null 2>&1 || { echo "logic: jq is required for conflicts" >&2; exit 1; }

branch=""
[ -n "${1:-}" ] && branch="$1"
if [ -z "$branch" ]; then
  read -r _ branch _ <<EOF
$(logic_effective_state)
EOF
fi

rows=$("$SCRIPT_DIR/collect.sh" "$branch"); [ -z "$rows" ] && rows='[]'

# Streams currently checked out (worktree path + branch ref).
streams_json=$(git worktree list --porcelain 2>/dev/null | awk '
  /^worktree /{wt=$2}
  /^branch /{sub("refs/heads/","",$2); print wt "\t" $2}
' | jq -R -s 'split("\n") | map(select(length>0)) | map(split("\t")) | map({worktree:.[0], branch:.[1]})')
[ -z "$streams_json" ] && streams_json='[]'

# --- tier1: territory overlap across worktrees ------------------------------
# Build file -> worktrees/rows from each row's commit.
pairs="$(mktemp 2>/dev/null || echo /tmp/logic-t1.$$)"; : >"$pairs"
printf '%s' "$rows" | jq -c '.[] | select((.sha//"")!="")' | while IFS= read -r row; do
  sha=$(printf '%s' "$row" | jq -r '.sha')
  wt=$(printf '%s' "$row" | jq -r '.worktree // ""')
  id=$(printf '%s' "$row" | jq -r '.id')
  actor=$(printf '%s' "$row" | jq -r '.actor')
  dec=$(printf '%s' "$row" | jq -r '.decision')
  git show --name-only --format= "$sha" 2>/dev/null | while IFS= read -r f; do
    [ -z "$f" ] && continue
    printf '%s\t%s\t%s\t%s\t%s\n' "$f" "$wt" "$id" "$actor" "$dec" >>"$pairs"
  done
done

tier1_json='[]'
if [ -s "$pairs" ]; then
  tier1_json=$(jq -R -s '
    split("\n") | map(select(length>0)) | map(split("\t"))
    | map({file:.[0], worktree:.[1], id:.[2], actor:.[3], decision:.[4]})
    | group_by(.file)
    | map(select((map(.worktree)|unique|length) > 1))
    | map({file: .[0].file,
           worktrees: (map(.worktree)|unique),
           rows: map({id, actor, decision, worktree})})' "$pairs")
  [ -z "$tier1_json" ] && tier1_json='[]'
fi
rm -f "$pairs"

# --- tier2: textual conflicts via merge-tree between stream branches --------
merge_tree_conflicts() { # $1 $2 = branch refs; prints conflicted files, one per line
  local a="$1" b="$2" out rc
  if git merge-tree --write-tree --name-only "$a" "$b" >/tmp/.logic_mt.$$ 2>/dev/null; then
    rc=0
  else
    rc=$?
  fi
  if [ -f /tmp/.logic_mt.$$ ]; then
    if [ "$rc" -ne 0 ]; then
      # first line is the (conflicted) tree oid; the rest are file names
      tail -n +2 /tmp/.logic_mt.$$
    fi
    rm -f /tmp/.logic_mt.$$
    return 0
  fi
  # Fallback: 3-arg form, detect markers, filenames unknown.
  local mbab
  mbab=$(git merge-base "$a" "$b" 2>/dev/null) || return 0
  if git merge-tree "$mbab" "$a" "$b" 2>/dev/null | grep -q '^+<<<<<<<'; then
    echo "(conflicts present — file names unavailable on this git version)"
  fi
}

tier2_json='[]'
brs=$(printf '%s' "$streams_json" | jq -r '.[].branch' | sort -u | grep -v '^$' || true)
set -- $brs
if [ "$#" -ge 2 ]; then
  t2="$(mktemp 2>/dev/null || echo /tmp/logic-t2.$$)"; printf '[]' >"$t2"
  i=1
  for a in "$@"; do
    j=1
    for b in "$@"; do
      if [ "$j" -gt "$i" ]; then
        files=$(merge_tree_conflicts "$a" "$b" | jq -R -s 'split("\n")|map(select(length>0))')
        n=$(printf '%s' "$files" | jq 'length')
        if [ "${n:-0}" -gt 0 ]; then
          obj=$(jq -nc --arg a "$a" --arg b "$b" --argjson files "$files" '{a:$a,b:$b,files:$files}')
          jq --argjson o "$obj" '. + [$o]' "$t2" >"${t2}.n" && mv -f "${t2}.n" "$t2"
        fi
      fi
      j=$((j+1))
    done
    i=$((i+1))
  done
  tier2_json=$(cat "$t2"); rm -f "$t2"
fi

jq -nc --arg branch "$branch" --argjson streams "$streams_json" \
  --argjson tier1 "$tier1_json" --argjson tier2 "$tier2_json" \
  '{branch:$branch, streams:$streams, tier1:$tier1, tier2:$tier2}'
