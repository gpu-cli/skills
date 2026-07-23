#!/usr/bin/env bash
# logic-core: gather raw material for reconstructing a decision trail when
# tracking was off. Emits JSON only — it never writes rows. The model turns this
# into inferred rows (actor="inferred", why phrased as a hypothesis), shown
# behind a warning banner.
#
# Sources, in reliability order: commit messages + trailers, the diff grouped by
# commit, beads task issues that mention the branch, and the PR body/comments.
#
# Everything is derived from the REQUESTED branch's ref, not the current
# checkout — reconstructing an unmerged feature from a main checkout must return
# that feature's history, not main's.
#
# Usage: reconstruct.sh [branch]
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib.sh"

command -v jq >/dev/null 2>&1 || { echo "logic: jq is required for reconstruct" >&2; exit 1; }

branch=""
[ -n "${1:-}" ] && branch="$1"
[ -z "$branch" ] && branch="$(logic_current_branch)"

ref=$(logic_resolve_ref "$branch") || {
  echo "logic: cannot resolve branch '$branch' to a git ref (no local branch, no origin/$branch)." >&2
  exit 1
}

base="$(logic_default_base 2>/dev/null)"
mb=""
[ -n "$base" ] && mb=$(git merge-base "$ref" "$base" 2>/dev/null)
range="$ref"
[ -n "$mb" ] && range="${mb}..${ref}"

# commits
commits_json='[]'
shas=$(git log --format='%H' "$range" 2>/dev/null)
if [ -n "$shas" ]; then
  tmp="$(mktemp 2>/dev/null || echo /tmp/logic-commits.$$)"; printf '[]' >"$tmp"
  for sha in $shas; do
    subject=$(git show -s --format='%s' "$sha" 2>/dev/null)
    body=$(git show -s --format='%b' "$sha" 2>/dev/null)
    trailers=$(git show -s --format='%(trailers:only,unfold)' "$sha" 2>/dev/null)
    author=$(git show -s --format='%an' "$sha" 2>/dev/null)
    date=$(git show -s --format='%aI' "$sha" 2>/dev/null)
    short=$(git rev-parse --short "$sha" 2>/dev/null)
    files=$(git show --name-only --format= "$sha" 2>/dev/null | jq -R -s 'split("\n") | map(select(length>0))')
    obj=$(jq -nc \
      --arg sha "$sha" --arg short "$short" --arg subject "$subject" --arg body "$body" \
      --arg trailers "$trailers" --arg author "$author" --arg date "$date" --argjson files "${files:-[]}" \
      '{sha:$sha, short:$short, subject:$subject, body:$body, trailers:$trailers, author:$author, date:$date, files:$files}')
    jq --argjson o "$obj" '. + [$o]' "$tmp" >"${tmp}.n" && mv -f "${tmp}.n" "$tmp"
  done
  commits_json=$(cat "$tmp"); rm -f "$tmp"
fi

# changed files (whole range)
changed_json='[]'
if [ -n "$mb" ]; then
  changed_json=$(git diff --name-only "$mb".."$ref" 2>/dev/null | jq -R -s 'split("\n") | map(select(length>0))')
fi

# beads task issues mentioning the branch
bd_json='[]'
if logic_bd_ok; then
  bd_json=$(bd search "$branch" --json 2>/dev/null | jq '[.[] | {id, title, status, type, description}]' 2>/dev/null)
  [ -z "$bd_json" ] && bd_json='[]'
fi

# PR body + comments
pr_json='null'
if command -v gh >/dev/null 2>&1; then
  pr_json=$(gh pr view "$branch" --json number,title,body,comments 2>/dev/null || gh pr view --json number,title,body,comments 2>/dev/null)
  [ -z "$pr_json" ] && pr_json='null'
fi

jq -nc \
  --arg branch "$branch" --arg ref "$ref" --arg base "$base" --arg range "$range" \
  --argjson commits "$commits_json" --argjson changed "$changed_json" \
  --argjson bd "$bd_json" --argjson pr "$pr_json" \
  '{branch:$branch, ref:$ref, base:$base, range:$range, commits:$commits, changed_files:$changed, bd_tasks:$bd, pr:$pr}'
