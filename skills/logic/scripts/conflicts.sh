#!/usr/bin/env bash
# logic: mechanical conflict pre-filters between parallel worktree streams.
#
# Feeds the model's tier-3 judgment. Emits JSON:
#   tier1 — territory overlap: a file touched by rows from >1 worktree
#   tier2 — real textual conflicts from git merge-tree between stream branches
# The model reads the paired rows and decides which overlaps are genuine
# semantic contradictions. A clean result means "none detected", not "none exist".
#
# Only worktrees that PARTICIPATE in the requested trail are considered: those
# that wrote rows, plus those on an unmerged branch derived from the logical
# branch. Otherwise unrelated feature worktrees would be reported as conflicts
# inside this branch's trail.
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
logical_ref=$(logic_resolve_ref "$branch" 2>/dev/null || true)

# Worktrees that wrote rows for this trail.
row_wts="$(mktemp 2>/dev/null || echo /tmp/logic-rowwt.$$)"; : >"$row_wts"
printf '%s' "$rows" | jq -r '[.[].worktree] | map(select(length>0)) | unique | .[]' 2>/dev/null >>"$row_wts"

# All checked-out worktrees with their branch.
all_wts="$(mktemp 2>/dev/null || echo /tmp/logic-allwt.$$)"; : >"$all_wts"
git worktree list --porcelain 2>/dev/null | awk '
  /^worktree /{wt=$2}
  /^branch /{sub("refs/heads/","",$2); print wt "\t" $2}
' >>"$all_wts"

# Keep a worktree when it wrote rows, or when its branch is a descendant of the
# logical branch (a derived agent stream).
#
# Ancestry-derivation is only meaningful while the logical branch is unmerged.
# Once it lands in the mainline, every later branch trivially descends from it,
# so inheriting on that basis would sweep in unrelated feature worktrees.
dbase="$(logic_default_base 2>/dev/null)"
logical_merged=0
if [ -n "$dbase" ] && [ -n "$logical_ref" ] \
   && git merge-base --is-ancestor "$logical_ref" "$dbase" 2>/dev/null; then
  logical_merged=1
fi

kept="$(mktemp 2>/dev/null || echo /tmp/logic-kept.$$)"; : >"$kept"
while IFS=$'\t' read -r wt br; do
  [ -z "$wt" ] && continue
  keep=0
  if grep -qxF "$wt" "$row_wts" 2>/dev/null; then keep=1; fi
  if [ "$keep" -eq 0 ] && [ "$logical_merged" -eq 0 ] && [ -n "$logical_ref" ] && [ -n "$br" ]; then
    if git rev-parse --verify -q "$br" >/dev/null 2>&1 \
       && git merge-base --is-ancestor "$logical_ref" "$br" 2>/dev/null; then
      keep=1
    fi
  fi
  [ "$keep" -eq 1 ] && printf '%s\t%s\n' "$wt" "$br" >>"$kept"
done <"$all_wts"

streams_json=$(jq -R -s 'split("\n") | map(select(length>0)) | map(split("\t")) | map({worktree:.[0], branch:.[1]})' "$kept")
[ -z "$streams_json" ] && streams_json='[]'

# --- tier1: territory overlap across worktrees ------------------------------
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

# --- tier2: textual conflicts via merge-tree between participating streams ---
merge_tree_conflicts() { # $1 $2 = branch refs; prints conflicted files
  local a="$1" b="$2" rc
  if git merge-tree --write-tree --name-only "$a" "$b" >"/tmp/.logic_mt.$$" 2>/dev/null; then
    rc=0
  else
    rc=$?
  fi
  if [ -f "/tmp/.logic_mt.$$" ]; then
    if [ "$rc" -ne 0 ]; then
      tail -n +2 "/tmp/.logic_mt.$$"
    fi
    rm -f "/tmp/.logic_mt.$$"
    return 0
  fi
  local mbab
  mbab=$(git merge-base "$a" "$b" 2>/dev/null) || return 0
  if git merge-tree "$mbab" "$a" "$b" 2>/dev/null | grep -q '^+<<<<<<<'; then
    echo "(conflicts present — file names unavailable on this git version)"
  fi
}

tier2_json='[]'
brs=$(cut -f2 "$kept" 2>/dev/null | sort -u | grep -v '^$' || true)
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
rm -f "$row_wts" "$all_wts" "$kept" 2>/dev/null

jq -nc --arg branch "$branch" --argjson streams "$streams_json" \
  --argjson tier1 "$tier1_json" --argjson tier2 "$tier2_json" \
  '{branch:$branch, streams:$streams, tier1:$tier1, tier2:$tier2}'
