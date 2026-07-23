#!/usr/bin/env bash
# logic-core self-test: exercises the mechanical core in a throwaway git repo
# using the TSV backend (no beads, fully isolated). Proves the capture floor:
# a commit produces a stub, manual logging adds a row, ancestry resolves a
# derived branch to its logical branch, and collect/render/audit run clean.
#
# Usage: bash selftest.sh   (exits non-zero on first failed assertion)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(dirname "$SCRIPT_DIR")"          # skills/logic-core
SCRIPTS="$CORE_DIR/scripts"

pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; }
assert()      { if eval "$2"; then ok "$1"; else bad "$1 -> [$2]"; fi; }
assert_grep() { if printf '%s' "$3" | grep -q "$2"; then ok "$1"; else bad "$1 (no match /$2/)"; fi; }

TMP="$(mktemp -d 2>/dev/null || echo /tmp/logic-selftest.$$)"
cleanup() { rm -rf "$TMP" 2>/dev/null; }
trap cleanup EXIT

echo "logic-core selftest in $TMP"

# --- set up a throwaway repo with the skill installed ----------------------
mkdir -p "$TMP/repo/.agents/skills"
cp -R "$CORE_DIR" "$TMP/repo/.agents/skills/logic-core"
cd "$TMP/repo" || exit 1
git init -q -b main
git config user.name  "Selftest Bot"
git config user.email "selftest@example.com"
echo "hello" > README.md
git add -A && git commit -q -m "init"

SK=".agents/skills/logic-core/scripts"

# --- enable tracking on a feature branch, TSV backend ----------------------
git checkout -q -b feature/widget
out=$(bash "$SK/toggle.sh" on feature/widget 2>&1)
assert_grep "toggle prints ON" "is now ON" "$out"
bash "$SK/config-edit.sh" set storage tsv >/dev/null
assert "core.hooksPath wired" "[ \"\$(git config --local core.hooksPath)\" = '.logic/githooks' ]"
assert "runtime materialized"  "[ -f .logic/runtime/logic.sh ]"
assert "post-commit installed" "[ -x .logic/githooks/post-commit ]"

state=$(bash "$SK/resolve-branch.sh")
assert_grep "resolve: on + branch + tsv" "^on feature/widget tsv" "$state"

# --- a commit produces a stub row (Layer-1 capture) ------------------------
echo "widget v1" > widget.txt
git add -A && git commit -q -m "add widget"
slug="feature-widget"
tsv=".logic/audit/${slug}"
assert "stub TSV dir exists" "[ -d '$tsv' ]"
rows=$(cat "$tsv"/*.tsv 2>/dev/null)
assert_grep "stub row has commit subject" "add widget" "$rows"
assert_grep "stub row is a stub kind"     "stub"       "$rows"

# --- manual logging adds an enriched row -----------------------------------
mlog=$(bash "$SK/log.sh" --decision "kept Metal" --why "Canvas dropped frames" --actor user --phase render 2>&1)
assert_grep "manual log confirms" "logged" "$mlog"

# --- collect + render ------------------------------------------------------
collected=$(bash "$SK/collect.sh" feature/widget)
n=$(printf '%s' "$collected" | jq 'length' 2>/dev/null)
assert "collect returns >=2 rows" "[ \"\${n:-0}\" -ge 2 ]"
assert_grep "collect has manual why" "Canvas dropped frames" "$collected"

rendered=$(printf '%s' "$collected" | bash "$SK/render.sh" --title "Trail")
assert_grep "render has a table header" "| ts | actor | phase | decision |" "$rendered"
assert_grep "render flags the stub"     "no why" "$rendered"

# --- ancestry: a derived branch resolves to its logical branch -------------
git checkout -q -b feature/widget-agent1
anc=$(bash "$SK/resolve-branch.sh")
assert_grep "derived branch resolves to logical via ancestry" "feature/widget" "$anc"
assert_grep "derived branch is tracked (on)" "^on " "$anc"

# --- audit + gc dry-run run without error ----------------------------------
git checkout -q feature/widget
audit=$(bash "$SK/audit.sh" feature/widget 2>&1)
assert_grep "audit produces a report" "Evidence audit" "$audit"

echo
echo "selftest: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
