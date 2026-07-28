#!/usr/bin/env bash
# logic self-test: exercises the bundled runtime in a throwaway git repo
# using the TSV backend (no beads, fully isolated). Proves the capture floor —
# a commit produces a stub, manual logging adds a row, ancestry resolves a
# derived branch — and carries a regression case for every fix from the Codex
# review (epic skills-uxf).
#
# Usage: bash selftest.sh   (exits non-zero if any assertion fails)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(dirname "$SCRIPT_DIR")"          # skills/logic

pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; }
assert()          { if eval "$2"; then ok "$1"; else bad "$1 -> [$2]"; fi; }
assert_grep()     { if printf '%s' "$3" | grep -q "$2"; then ok "$1"; else bad "$1 (no match /$2/)"; fi; }
assert_not_grep() { if printf '%s' "$3" | grep -q "$2"; then bad "$1 (unexpected /$2/)"; else ok "$1"; fi; }

TMP="$(mktemp -d 2>/dev/null || echo /tmp/logic-selftest.$$)"
cleanup() {
  git -C "$TMP/repo" worktree remove --force "$TMP/unrelated" >/dev/null 2>&1
  rm -rf "$TMP" 2>/dev/null
}
trap cleanup EXIT

echo "logic selftest in $TMP"

# --- set up a throwaway repo with the skill installed ----------------------
mkdir -p "$TMP/repo/.agents/skills"
cp -R "$CORE_DIR" "$TMP/repo/.agents/skills/logic"
cd "$TMP/repo" || exit 1
git init -q -b main
git config user.name  "Selftest Bot"
git config user.email "selftest@example.com"
echo "hello" > README.md
git add -A && git commit -q -m "init"

SK=".agents/skills/logic/scripts"

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
assert_grep "stub row confidence is unknown" $'\tunknown$' "$rows"

# --- manual logging adds an enriched row -----------------------------------
mlog=$(bash "$SK/log.sh" --decision "kept Metal" --why "Canvas dropped frames" \
  --actor user --phase render --confidence medium 2>&1)
assert_grep "manual log confirms" "logged" "$mlog"
assert_grep "manual log echoes confidence" "confidence=medium" "$mlog"
if bash "$SK/log.sh" --decision "bad confidence" --confidence certain >/dev/null 2>&1; then
  bad "invalid confidence is rejected"
else
  ok "invalid confidence is rejected"
fi

# --- collect + render ------------------------------------------------------
collected=$(bash "$SK/collect.sh" feature/widget)
n=$(printf '%s' "$collected" | jq 'length' 2>/dev/null)
assert "collect returns >=2 rows" "[ ${n:-0} -ge 2 ]"
assert_grep "collect has manual why" "Canvas dropped frames" "$collected"
mc=$(printf '%s' "$collected" | jq -r '[.[] | select(.decision=="kept Metal")][0].confidence')
assert "collect preserves perceived confidence" "[ '$mc' = medium ]"
mb=$(printf '%s' "$collected" | jq -r '[.[] | select(.decision=="kept Metal")][0].branch')
assert "TSV collection preserves logical branch" "[ '$mb' = feature/widget ]"

rendered=$(printf '%s' "$collected" | bash "$SK/render.sh" --title "Trail")
assert_grep "render has a table header" "| ts | actor | phase | decision |" "$rendered"
assert_grep "render includes confidence column" "| confidence | evidence |" "$rendered"
assert_grep "render flags the stub"     "no why" "$rendered"

# --- old ten-column TSV rows remain readable ------------------------------
printf 'ts\tactor\tphase\tdecision\twhy\tevidence\tresult\tkind\tsha\tworktree\n2026-01-01T00:00:00Z\tlegacy\tcore\tlegacy choice\tlegacy why\t\topen\tmanual\t\t%s\n' \
  "$TMP/repo" >"$tsv/legacy.tsv"
legacy_collected=$(bash "$SK/collect.sh" feature/widget)
lc=$(printf '%s' "$legacy_collected" | jq -r '[.[] | select(.decision=="legacy choice")][0].confidence')
assert "legacy TSV row defaults confidence to unknown" "[ '$lc' = unknown ]"

# --- ancestry: an unmerged derived branch resolves to its logical branch ----
git checkout -q -b feature/widget-agent1
anc=$(bash "$SK/resolve-branch.sh")
assert_grep "derived branch resolves to logical via ancestry" "feature/widget" "$anc"
assert_grep "derived branch is tracked (on)" "^on " "$anc"
git checkout -q feature/widget

audit=$(bash "$SK/audit.sh" feature/widget 2>&1)
assert_grep "audit produces a report" "Evidence resolution and coverage" "$audit"

# ===========================================================================
# Regressions for the Codex review fixes (skills-uxf)
# ===========================================================================

# uxf.1 — an incompatible bd must downgrade to TSV, and say so.
mkdir -p "$TMP/fakebin"
cat > "$TMP/fakebin/bd" <<'FAKE'
#!/bin/sh
case "$1" in
  query) echo "unknown command: query" >&2; exit 1 ;;
  create) echo "Usage: bd create [title]"; exit 0 ;;
  --version|version) echo "bd version 0.49.1"; exit 0 ;;
esac
exit 0
FAKE
chmod +x "$TMP/fakebin/bd"
bash "$SK/config-edit.sh" set storage beads >/dev/null
cap=$(PATH="$TMP/fakebin:$PATH" bash -c "rm -f .logic/.bd-capability; . '$SK/lib.sh'; logic_bd_capability")
assert "old bd probes as incompatible" "[ '$cap' = incompatible ]"
st=$(PATH="$TMP/fakebin:$PATH" bash -c "rm -f .logic/.bd-capability; . '$SK/lib.sh'; logic_effective_state")
assert_grep "incompatible bd downgrades storage to tsv" "tsv$" "$st"
warn=$(PATH="$TMP/fakebin:$PATH" bash -c "rm -f .logic/.bd-capability; . '$SK/lib.sh'; logic_warn_stderr" 2>&1)
assert_grep "the downgrade is announced, never silent" "TSV fallback" "$warn"

# A compatible beads backend receives confidence in decision metadata.
cat > "$TMP/fakebin/bd" <<'FAKE'
#!/bin/sh
case "$1" in
  --version|version) echo "bd version selftest-compatible"; exit 0 ;;
  query)
    [ "${2:-}" = "--help" ] && exit 0
    echo '[]'; exit 0
    ;;
  create)
    if [ "${2:-}" = "--help" ]; then echo "Usage: bd create --metadata TYPE decision"; exit 0; fi
    printf '%s\n' "$@" >>"${FAKE_BD_LOG:?}"
    echo "skills-selftest"
    exit 0
    ;;
  close|update|label) exit 0 ;;
esac
exit 0
FAKE
chmod +x "$TMP/fakebin/bd"
rm -f .logic/.bd-capability "$TMP/fake-bd.log"
blog=$(FAKE_BD_LOG="$TMP/fake-bd.log" PATH="$TMP/fakebin:$PATH" \
  bash "$SK/log.sh" --decision "beads confidence" --why "exercise metadata" \
    --confidence high 2>&1)
assert_grep "compatible beads log succeeds" "logged skills-selftest" "$blog"
bmeta=$(cat "$TMP/fake-bd.log" 2>/dev/null)
assert_grep "beads metadata carries confidence" '"confidence":"high"' "$bmeta"

bash "$SK/config-edit.sh" set storage tsv >/dev/null
rm -f .logic/.bd-capability

# uxf.2 — once a tracked branch merges, it must stop tracking its descendants.
git checkout -q main
git merge -q --no-ff feature/widget -m "merge widget" 2>/dev/null || git merge -q feature/widget -m "merge widget"
mstate=$(bash "$SK/resolve-branch.sh")
assert_grep "merged branch does not leak tracking onto main" "^off " "$mstate"

# uxf.3 / uxf.4 — audit and reconstruct must target the REQUESTED branch,
# not the current checkout. Both are run from main against an unmerged branch.
git checkout -q -b feature/other main
echo "other" > other.txt
git add -A && git commit -q -m "other work"
git checkout -q main
a=$(bash "$SK/audit.sh" feature/other 2>&1)
assert_grep "audit names the requested branch" "feature/other" "$a"
assert_grep "audit uses the requested branch's diff" "other.txt" "$a"
r=$(bash "$SK/reconstruct.sh" feature/other 2>/dev/null)
rc=$(printf '%s' "$r" | jq '.commits | length' 2>/dev/null)
assert "reconstruct sees the requested branch's commits" "[ ${rc:-0} -ge 1 ]"
assert_grep "reconstruct includes the requested branch's file" "other.txt" "$r"

# uxf.5 — toggling a non-current branch must not claim it took effect there.
t=$(bash "$SK/toggle.sh" on feature/other 2>&1)
assert_grep "toggle admits the config is not yet on the target branch" "does NOT apply on" "$t"
assert_not_grep "toggle no longer claims it takes effect there" "it takes effect there" "$t"

# uxf.6 — TSV enrichment supersedes the stub instead of duplicating it.
git checkout -q feature/widget
echo "v2" >> widget.txt
git add -A && git commit -q -m "widget v2"
sha2=$(git rev-parse HEAD)
c=$(bash "$SK/collect.sh" feature/widget)
before=$(printf '%s' "$c" | jq --arg s "$sha2" '[.[] | select(.sha==$s)] | length')
assert "stub captured for the new commit" "[ ${before:-0} -eq 1 ]"
bash "$SK/log.sh" --enrich "$sha2" --why "needed a second pass for the highlight" \
  --confidence high >/dev/null 2>&1
c2=$(bash "$SK/collect.sh" feature/widget)
after=$(printf '%s' "$c2" | jq --arg s "$sha2" '[.[] | select(.sha==$s)] | length')
assert "enrichment supersedes rather than duplicating" "[ ${after:-0} -eq 1 ]"
why2=$(printf '%s' "$c2" | jq -r --arg s "$sha2" '[.[] | select(.sha==$s)][0].why')
assert_grep "the enriched why is what survives" "second pass" "$why2"
conf2=$(printf '%s' "$c2" | jq -r --arg s "$sha2" '[.[] | select(.sha==$s)][0].confidence')
assert "enrichment records confidence" "[ '$conf2' = high ]"

# uxf.7 — two distinct rows in the same second must both survive.
bash "$SK/log.sh" --decision "first same-second call"  --why "a" --actor sameactor >/dev/null 2>&1
bash "$SK/log.sh" --decision "second same-second call" --why "b" --actor sameactor >/dev/null 2>&1
c3=$(bash "$SK/collect.sh" feature/widget)
ss=$(printf '%s' "$c3" | jq '[.[] | select(.decision | test("same-second call"))] | length')
assert "same-second distinct rows both survive" "[ ${ss:-0} -eq 2 ]"

# uxf.8 — fabricated commit evidence must be reported, not rubber-stamped.
bash "$SK/log.sh" --decision "claims a fake commit" --why "testing the audit" --evidence "commit deadbeef" >/dev/null 2>&1
a2=$(bash "$SK/audit.sh" feature/widget 2>&1)
assert_grep "audit opens an unresolved section" "Unresolved evidence" "$a2"
assert_grep "fabricated commit evidence is flagged" "claims a fake commit" "$a2"

# uxf.9 — an unrelated worktree must not appear in this trail's conflict streams.
git worktree add -q "$TMP/unrelated" -b unrelated/branch main >/dev/null 2>&1
cf=$(bash "$SK/conflicts.sh" feature/widget 2>/dev/null)
idx=$(printf '%s' "$cf" | jq -r '[.streams[].branch] | index("unrelated/branch") | tostring' 2>/dev/null)
assert "unrelated worktree excluded from conflict streams" "[ '${idx:-null}' = 'null' ]"

echo
echo "selftest: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
