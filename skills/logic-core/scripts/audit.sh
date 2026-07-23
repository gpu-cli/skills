#!/usr/bin/env bash
# logic-core: git-evidence audit of a branch's decision rows.
#
# Replaces the transcript audit of the original show-me-your-work skill with an
# artifact that always exists: the git history. Checks that each row's evidence
# resolves inside the branch range, and reports diff regions that no row covers.
#
# Usage: audit.sh [branch]
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib.sh"

command -v jq >/dev/null 2>&1 || { echo "logic: jq is required for audit" >&2; exit 1; }

branch=""
[ -n "${1:-}" ] && branch="$1"
if [ -z "$branch" ]; then
  read -r _ branch _ <<EOF
$(logic_effective_state)
EOF
fi

rows=$("$SCRIPT_DIR/collect.sh" "$branch")
[ -z "$rows" ] && rows='[]'
total=$(printf '%s' "$rows" | jq 'length')

# Determine the base ref for this branch's range.
base=""
for r in origin/main main origin/master master; do
  if git rev-parse --verify -q "$r" >/dev/null 2>&1; then base="$r"; break; fi
done
mb=""
[ -n "$base" ] && mb=$(git merge-base HEAD "$base" 2>/dev/null)

echo "## Evidence audit — ${branch}"
echo
if [ -z "$mb" ]; then
  echo "_No base ref (main/master) found; range checks limited to reachability from HEAD._"
fi
echo

# Covered files: union of files touched by commits any row points at.
covered="$(mktemp 2>/dev/null || echo /tmp/logic-cov.$$)"; : >"$covered"
unresolved="$(mktemp 2>/dev/null || echo /tmp/logic-unres.$$)"; : >"$unresolved"
resolved=0

# iterate rows
printf '%s' "$rows" | jq -c '.[]' | while IFS= read -r row; do
  sha=$(printf '%s' "$row" | jq -r '.sha // ""')
  ev=$(printf '%s' "$row" | jq -r '.evidence // ""')
  dec=$(printf '%s' "$row" | jq -r '.decision // ""')
  id=$(printf '%s' "$row" | jq -r '.id // ""')
  ok=0
  # sha-based evidence
  if [ -n "$sha" ] && git cat-file -e "$sha" 2>/dev/null; then
    if [ -z "$mb" ] || git merge-base --is-ancestor "$sha" HEAD 2>/dev/null; then ok=1; fi
    git show --name-only --format= "$sha" 2>/dev/null >>"$covered"
  fi
  # path evidence: "path" or "path:line"
  if [ "$ok" -eq 0 ] && [ -n "$ev" ]; then
    p="${ev%%:*}"
    if [ -n "$p" ] && [ -e "$(logic_repo_root)/$p" ]; then ok=1; printf '%s\n' "$p" >>"$covered"; fi
    case "$ev" in commit\ *) ok=1 ;; esac
  fi
  if [ "$ok" -eq 1 ]; then
    resolved=$((resolved+1))
    printf '%s\n' "$resolved" >/dev/null
  else
    printf -- '- [%s] %s  (evidence: %s)\n' "$id" "$dec" "${ev:-none}" >>"$unresolved"
  fi
done

# The subshell above can't export counters; recompute resolved for the summary.
res_count=$(printf '%s' "$rows" | jq -r '
  [.[] | select(((.sha // "")!="") or ((.evidence // "")!=""))] | length')

echo "Rows: ${total}. Rows with some evidence pointer: ${res_count}."
echo
if [ -s "$unresolved" ]; then
  echo "### Unresolved evidence"
  cat "$unresolved"
  echo
else
  echo "_All rows carry a resolvable evidence pointer._"
  echo
fi

# Coverage gaps: changed files with no covering row.
if [ -n "$mb" ]; then
  gaps="$(mktemp 2>/dev/null || echo /tmp/logic-gaps.$$)"; : >"$gaps"
  sort -u "$covered" >"${covered}.s" 2>/dev/null; mv -f "${covered}.s" "$covered"
  git diff --name-only "$mb"..HEAD 2>/dev/null | while IFS= read -r f; do
    [ -z "$f" ] && continue
    if ! grep -qxF "$f" "$covered" 2>/dev/null; then printf -- '- %s\n' "$f" >>"$gaps"; fi
  done
  if [ -s "$gaps" ]; then
    gapn=$(wc -l <"$gaps" | tr -d ' ')
    echo "### Coverage gaps (${gapn} changed file(s) no row explains)"
    cat "$gaps"
  else
    echo "_Every changed file is covered by at least one decision row._"
  fi
  rm -f "$gaps"
fi
rm -f "$covered" "$unresolved" 2>/dev/null
