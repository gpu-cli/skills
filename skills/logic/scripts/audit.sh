#!/usr/bin/env bash
# logic: git-evidence resolution and coverage check for decision rows.
#
# Replaces the transcript audit of the original show-me-your-work skill with an
# artifact that always exists: the git history. Checks that each row's evidence
# actually resolves inside the audited branch's range, and reports diff regions
# that no row covers.
#
# The audited branch is the one asked for — not the current checkout — so
# /logic show <other-branch> from anywhere reports that branch's truth.
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

ref=$(logic_resolve_ref "$branch") || {
  echo "logic: cannot resolve branch '$branch' to a git ref (no local branch, no origin/$branch)." >&2
  exit 1
}

rows=$("$SCRIPT_DIR/collect.sh" "$branch")
[ -z "$rows" ] && rows='[]'
total=$(printf '%s' "$rows" | jq 'length')

base="$(logic_default_base 2>/dev/null)"
mb=""
[ -n "$base" ] && mb=$(git merge-base "$ref" "$base" 2>/dev/null)

echo "## Evidence resolution and coverage — ${branch}"
echo
if [ -z "$mb" ]; then
  echo "_No base ref (main/master) found; range checks limited to reachability from ${ref}._"
  echo
fi

covered="$(mktemp 2>/dev/null || echo /tmp/logic-cov.$$)";      : >"$covered"
unresolved="$(mktemp 2>/dev/null || echo /tmp/logic-unres.$$)"; : >"$unresolved"
resolved="$(mktemp 2>/dev/null || echo /tmp/logic-res.$$)";     : >"$resolved"

# Validate one commit-ish: it must exist AND belong to the audited branch.
commit_in_branch() {
  local c="$1"
  git cat-file -e "${c}^{commit}" 2>/dev/null || return 1
  git merge-base --is-ancestor "$c" "$ref" 2>/dev/null
}

printf '%s' "$rows" | jq -c '.[]' | while IFS= read -r row; do
  sha=$(printf '%s' "$row" | jq -r '.sha // ""')
  ev=$(printf '%s' "$row" | jq -r '.evidence // ""')
  dec=$(printf '%s' "$row" | jq -r '.decision // ""')
  id=$(printf '%s' "$row" | jq -r '.id // ""')
  ok=0

  # 1. the row's own commit anchor
  if [ -n "$sha" ] && commit_in_branch "$sha"; then
    ok=1
    git show --name-only --format= "$sha" 2>/dev/null >>"$covered"
  fi

  # 2. "commit <sha>" evidence — parse and verify; never trust the prefix alone
  if [ "$ok" -eq 0 ] && [ -n "$ev" ]; then
    case "$ev" in
      commit\ *)
        esha="${ev#commit }"; esha="${esha%% *}"; esha="${esha%,}"
        if [ -n "$esha" ] && commit_in_branch "$esha"; then
          ok=1
          git show --name-only --format= "$esha" 2>/dev/null >>"$covered"
        fi
        ;;
    esac
  fi

  # 3. path evidence: "path" or "path:line", resolved against the audited ref
  if [ "$ok" -eq 0 ] && [ -n "$ev" ]; then
    p="${ev%%:*}"
    if [ -n "$p" ]; then
      if git cat-file -e "${ref}:${p}" 2>/dev/null; then
        ok=1; printf '%s\n' "$p" >>"$covered"
      elif [ -e "$(logic_repo_root)/$p" ]; then
        ok=1; printf '%s\n' "$p" >>"$covered"
      fi
    fi
  fi

  if [ "$ok" -eq 1 ]; then
    printf '%s\n' "$id" >>"$resolved"
  else
    printf -- '- [%s] %s  (evidence: %s)\n' "$id" "$dec" "${ev:-none}" >>"$unresolved"
  fi
done

res_count=$(grep -c . "$resolved" 2>/dev/null || true);     [ -z "$res_count" ] && res_count=0
unres_count=$(grep -c . "$unresolved" 2>/dev/null || true); [ -z "$unres_count" ] && unres_count=0

echo "Rows: ${total}. Evidence resolves: ${res_count}. Unresolved: ${unres_count}."
echo
if [ "$unres_count" -gt 0 ]; then
  echo "### Unresolved evidence"
  echo "_These rows point at nothing this branch can confirm — a missing commit, a fabricated SHA, or a path that does not exist here._"
  echo
  cat "$unresolved"
  echo
else
  echo "_Every row's evidence resolves inside this branch._"
  echo
fi

# Coverage gaps: changed files with no covering row.
if [ -n "$mb" ]; then
  gaps="$(mktemp 2>/dev/null || echo /tmp/logic-gaps.$$)"; : >"$gaps"
  sort -u "$covered" >"${covered}.s" 2>/dev/null && mv -f "${covered}.s" "$covered"
  git diff --name-only "$mb".."$ref" 2>/dev/null | while IFS= read -r f; do
    [ -z "$f" ] && continue
    if ! grep -qxF "$f" "$covered" 2>/dev/null; then printf -- '- %s\n' "$f" >>"$gaps"; fi
  done
  if [ -s "$gaps" ]; then
    gapn=$(grep -c . "$gaps" 2>/dev/null || true); [ -z "$gapn" ] && gapn=0
    echo "### Coverage gaps (${gapn} changed file(s) no row explains)"
    cat "$gaps"
  else
    echo "_Every changed file is covered by at least one decision row._"
  fi
  rm -f "$gaps"
fi
rm -f "$covered" "$unresolved" "$resolved" 2>/dev/null
