#!/usr/bin/env bash
# logic: push a rendered decision trail into the PR description, idempotently.
#
# Reads Markdown from stdin (or --file), wraps it in stable HTML-comment markers,
# and replaces the marked section in the PR body — so re-running updates in place
# instead of stacking copies. Requires gh and an open PR for the branch.
#
# Usage: render.sh output | pr-push.sh [branch]
#        pr-push.sh --file trail.md [branch]
set -u

command -v gh >/dev/null 2>&1 || { echo "logic: gh CLI not found; cannot push to PR." >&2; exit 1; }

file=""; branch=""
while [ $# -gt 0 ]; do
  case "$1" in
    --file) file="$2"; shift 2 ;;
    --*) shift ;;
    *) branch="$1"; shift ;;
  esac
done

if [ -n "$file" ]; then
  section=$(cat "$file")
else
  section=$(cat)
fi
[ -z "$section" ] && { echo "logic: nothing to push (empty section)." >&2; exit 1; }

BEGIN="<!-- logic:decision-trail:begin -->"
END="<!-- logic:decision-trail:end -->"

# Resolve the PR.
if [ -n "$branch" ]; then
  pr=$(gh pr view "$branch" --json number -q .number 2>/dev/null)
else
  pr=$(gh pr view --json number -q .number 2>/dev/null)
fi
[ -z "$pr" ] && { echo "logic: no open PR found for this branch. Open one first, then re-run --pr." >&2; exit 1; }

cur=$(gh pr view "$pr" --json body -q .body 2>/dev/null)
[ "$cur" = "null" ] && cur=""

block="${BEGIN}
${section}
${END}"

tmp_cur="$(mktemp)"; printf '%s' "$cur" >"$tmp_cur"
tmp_block="$(mktemp)"; printf '%s' "$block" >"$tmp_block"

if printf '%s' "$cur" | grep -qF "$BEGIN"; then
  # Replace existing marked block (awk, marker-delimited).
  new=$(awk -v b="$BEGIN" -v e="$END" -v bf="$tmp_block" '
    BEGIN { while ((getline line < bf) > 0) block = block line ORS }
    $0 ~ b { inblk=1; printf "%s", block; next }
    $0 ~ e { inblk=0; next }
    !inblk { print }
  ' "$tmp_cur")
else
  # Append with a separating blank line.
  new=$(printf '%s\n\n%s\n' "$cur" "$block")
fi
rm -f "$tmp_cur" "$tmp_block"

printf '%s' "$new" | gh pr edit "$pr" --body-file - >/dev/null 2>&1 \
  && echo "logic: updated decision trail in PR #${pr}." \
  || { echo "logic: failed to update PR #${pr}." >&2; exit 1; }
