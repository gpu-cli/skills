#!/usr/bin/env bash
# logic-core: collect all decision rows for a branch into one normalized set.
#
# Reads the beads backend (one query — the shared Dolt server already sees every
# worktree) and any TSV fallback files across all worktrees, merges, dedupes, and
# sorts by timestamp.
#
# Usage: collect.sh [branch] [--json|--tsv]   (default --json, array on stdout)
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib.sh"

branch=""; fmt="json"
for a in "$@"; do
  case "$a" in
    --tsv) fmt="tsv" ;;
    --json) fmt="json" ;;
    --*) ;;
    *) branch="$a" ;;
  esac
done
if [ -z "$branch" ]; then
  read -r _ branch _ <<EOF
$(logic_effective_state)
EOF
fi
slug=$(logic_slug "$branch")

have_jq=0; command -v jq >/dev/null 2>&1 && have_jq=1
if [ "$have_jq" -eq 0 ]; then
  echo "logic: jq is required for collect" >&2; exit 1
fi

# --- beads rows (single query covers every worktree via the shared server) ---
beads_json='[]'
if command -v bd >/dev/null 2>&1; then
  beads_json=$(bd query "label=logic:${slug}" --all --json 2>/dev/null | jq '
    map({
      id: .id,
      ts: (.metadata.ts // .created_at // .created // .updated_at // ""),
      actor: (.metadata.actor // "unknown"),
      phase: (.metadata.phase // ""),
      decision: (.title // ""),
      why: (if ((.labels // []) | index("logic-stub")) then "" else (.description // "") end),
      evidence: (.metadata.evidence // ""),
      result: (.metadata.result // ""),
      kind: (.metadata.kind // ""),
      sha: (.metadata.sha // ""),
      worktree: (.metadata.worktree // ""),
      branch: (.metadata.branch // ""),
      stub: (((.labels // []) | index("logic-stub")) != null),
      source: "beads"
    })' 2>/dev/null)
  [ -z "$beads_json" ] && beads_json='[]'
fi

# --- TSV rows across all worktrees -----------------------------------------
tsv_list_file="$(mktemp 2>/dev/null || echo /tmp/logic-tsv.$$)"
: >"$tsv_list_file"
git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}' | while IFS= read -r wt; do
  [ -n "$wt" ] && printf '%s\n' "$wt/.logic/audit/${slug}"
done >>"$tsv_list_file"
printf '%s\n' "$(logic_dir)/audit/${slug}" >>"$tsv_list_file"

tsv_data_file="$(mktemp 2>/dev/null || echo /tmp/logic-tsvdata.$$)"
: >"$tsv_data_file"
sort -u "$tsv_list_file" | while IFS= read -r d; do
  [ -d "$d" ] || continue
  for f in "$d"/*.tsv; do
    [ -f "$f" ] || continue
    tail -n +2 "$f" >>"$tsv_data_file"
  done
done

tsv_json='[]'
if [ -s "$tsv_data_file" ]; then
  tsv_json=$(sort -u "$tsv_data_file" | jq -R -s '
    split("\n") | map(select(length > 0)) | map(split("\t")) | map({
      id: ("tsv:" + (.[0]//"") + ":" + (.[1]//"") + ":" + (.[8]//"")),
      ts:(.[0]//""), actor:(.[1]//""), phase:(.[2]//""), decision:(.[3]//""),
      why:(.[4]//""), evidence:(.[5]//""), result:(.[6]//""), kind:(.[7]//""),
      sha:(.[8]//""), worktree:(.[9]//""), branch:"",
      stub: (((.[4]//"")=="") or ((.[4]//"")=="(pending why)")),
      source:"tsv"
    })' 2>/dev/null)
  [ -z "$tsv_json" ] && tsv_json='[]'
fi
rm -f "$tsv_list_file" "$tsv_data_file" 2>/dev/null

merged=$(printf '%s\n%s\n' "$beads_json" "$tsv_json" | jq -s 'add | unique_by(.id) | sort_by(.ts)' 2>/dev/null)
[ -z "$merged" ] && merged='[]'

if [ "$fmt" = "tsv" ]; then
  printf 'ts\tactor\tphase\tdecision\twhy\tevidence\tresult\tkind\tsha\tworktree\tsource\n'
  printf '%s' "$merged" | jq -r '.[] | [.ts,.actor,.phase,.decision,.why,.evidence,.result,.kind,.sha,.worktree,.source] | @tsv'
else
  printf '%s\n' "$merged"
fi
