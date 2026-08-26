#!/usr/bin/env bash
# decision-trail self-test: exercises the bundled runtime in a throwaway git repo
# using the TSV backend (no beads, fully isolated). Proves the capture floor —
# a commit produces a stub, manual logging adds a row, ancestry resolves a
# derived branch — and carries a regression case for every fix from the Codex
# review (epics skills-uxf and skills-7am).
#
# Usage: bash selftest.sh   (exits non-zero if any assertion fails)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(dirname "$SCRIPT_DIR")"          # skills/decision-trail

pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; }
assert()          { if eval "$2"; then ok "$1"; else bad "$1 -> [$2]"; fi; }
assert_grep()     { if printf '%s' "$3" | grep -q "$2"; then ok "$1"; else bad "$1 (no match /$2/)"; fi; }
assert_not_grep() { if printf '%s' "$3" | grep -q "$2"; then bad "$1 (unexpected /$2/)"; else ok "$1"; fi; }

TMP="$(mktemp -d 2>/dev/null || echo /tmp/decision-trail-selftest.$$)"
cleanup() {
  git -C "$TMP/repo" worktree remove --force "$TMP/unrelated" >/dev/null 2>&1
  git -C "$TMP/repo" worktree remove --force "$TMP/legacy-wt" >/dev/null 2>&1
  rm -rf "$TMP" 2>/dev/null
}
trap cleanup EXIT

echo "decision-trail selftest in $TMP"

# --- set up a throwaway repo with the skill installed ----------------------
mkdir -p "$TMP/repo/.agents/skills"
cp -R "$CORE_DIR" "$TMP/repo/.agents/skills/decision-trail"
cd "$TMP/repo" || exit 1
git init -q -b main
git config user.name  "Selftest Bot"
git config user.email "selftest@example.com"
echo "hello" > README.md
git add -A && git commit -q -m "init"

SK=".agents/skills/decision-trail/scripts"

# --- enable tracking on a feature branch, TSV backend ----------------------
git checkout -q -b feature/widget
out=$(bash "$SK/toggle.sh" on feature/widget 2>&1)
assert_grep "toggle prints ON" "is now ON" "$out"
bash "$SK/config-edit.sh" set storage tsv >/dev/null
assert "core.hooksPath wired" "[ \"\$(git config --local core.hooksPath)\" = '.decision-trail/githooks' ]"
assert "runtime materialized"  "[ -f .decision-trail/runtime/decision-trail.sh ]"
assert "post-commit installed" "[ -x .decision-trail/githooks/post-commit ]"

state=$(bash "$SK/resolve-branch.sh")
assert_grep "resolve: on + branch + tsv" "^on feature/widget tsv" "$state"

# --- a commit produces a stub row (Layer-1 capture) ------------------------
echo "widget v1" > widget.txt
git add -A && git commit -q -m "add widget"
slug="feature-widget"
tsv=".decision-trail/audit/${slug}"
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
cap=$(PATH="$TMP/fakebin:$PATH" bash -c "rm -f .decision-trail/.bd-capability; . '$SK/lib.sh'; dt_bd_capability")
assert "old bd probes as incompatible" "[ '$cap' = incompatible ]"
st=$(PATH="$TMP/fakebin:$PATH" bash -c "rm -f .decision-trail/.bd-capability; . '$SK/lib.sh'; dt_effective_state")
assert_grep "incompatible bd downgrades storage to tsv" "tsv$" "$st"
warn=$(PATH="$TMP/fakebin:$PATH" bash -c "rm -f .decision-trail/.bd-capability; . '$SK/lib.sh'; dt_warn_stderr" 2>&1)
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
rm -f .decision-trail/.bd-capability "$TMP/fake-bd.log"
blog=$(FAKE_BD_LOG="$TMP/fake-bd.log" PATH="$TMP/fakebin:$PATH" \
  bash "$SK/log.sh" --decision "beads confidence" --why "exercise metadata" \
    --confidence high 2>&1)
assert_grep "compatible beads log succeeds" "logged skills-selftest" "$blog"
bmeta=$(cat "$TMP/fake-bd.log" 2>/dev/null)
assert_grep "beads metadata carries confidence" '"confidence":"high"' "$bmeta"

bash "$SK/config-edit.sh" set storage tsv >/dev/null
rm -f .decision-trail/.bd-capability

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

# uxf.10 — a wedged backend must not hold the commit open. The hook promises it
# will never noticeably slow a commit; without a bound, a blocked dt_log_row
# blocks git forever. Runs in its own repo so the stub store stays untouched.
wedge="$TMP/wedged"
mkdir -p "$wedge/.decision-trail/runtime" "$wedge/.decision-trail/githooks"
git init -q "$wedge"
git -C "$wedge" config user.email t@t
git -C "$wedge" config user.name "T"
git -C "$wedge" config core.hooksPath .decision-trail/githooks
cp -f "$SK/../githooks/post-commit" "$wedge/.decision-trail/githooks/post-commit"
chmod +x "$wedge/.decision-trail/githooks/post-commit"
printf 'dt_is_tracked() { return 0; }\ndt_find_stub_by_sha() { :; }\ndt_log_row() { sleep 98765; }\n' \
  > "$wedge/.decision-trail/runtime/decision-trail.sh"
echo wedge > "$wedge/w.txt"
git -C "$wedge" add w.txt
started=$(date +%s)
DECISION_TRAIL_HOOK_TIMEOUT=2 git -C "$wedge" commit -q -m "wedged backend" </dev/null >/dev/null 2>&1
took=$(( $(date +%s) - started ))
wedge_head=$(git -C "$wedge" rev-parse -q --verify HEAD 2>/dev/null)
wedge_orphans=$(pgrep -f 'sleep 98765' 2>/dev/null)
assert "wedged hook does not hold the commit open" "[ ${took:-99} -le 20 ]"
assert "wedged hook still lets the commit succeed" "[ -n '${wedge_head}' ]"
# The killed capture must take its descendants with it, or whatever it was
# blocked in keeps git's inherited descriptors open and the bound means nothing.
assert "wedged hook leaves no orphaned descendants" "[ -z '${wedge_orphans}' ]"

# --- legacy .logic/ migration ----------------------------------------------
#
# Repos that enabled this skill before it was renamed carry a committed .logic/
# runtime. Toggling on must move it rather than build a second trail beside it,
# and the rows recorded under the old name must survive.

LEG="$TMP/legacy"
mkdir -p "$LEG/.agents/skills"
cp -R "$CORE_DIR" "$LEG/.agents/skills/decision-trail"
(
  cd "$LEG" || exit 1
  git init -q -b main
  git config user.name  "Selftest Bot"
  git config user.email "selftest@example.com"
  echo "hello" > README.md
  git add -A && git commit -q -m init

  # A pre-rename runtime, as install-hooks.sh used to write it.
  mkdir -p .logic/runtime .logic/githooks .logic/hooks .logic/audit/main
  printf '{"version":1,"default":"off","branches":{"main":"on"},"storage":"tsv","storageOverrides":{}}\n' \
    > .logic/config.json
  printf '# old engine\n' > .logic/runtime/logic.sh
  printf '#!/usr/bin/env bash\n# old hook\n' > .logic/githooks/post-commit
  chmod +x .logic/githooks/post-commit
  printf 'ts\tactor\tphase\tdecision\twhy\tevidence\tresult\tkind\tsha\tworktree\tconfidence\n' \
    > .logic/audit/main/selftest-bot.tsv
  printf '2026-01-01T00:00:00Z\tSelftest Bot\t\tchose the old engine\tit was all there was\t\t\tdecision\t\t%s\thigh\n' \
    "$LEG" >> .logic/audit/main/selftest-bot.tsv
  git config core.hooksPath .logic/githooks
  git add -A && git commit -q -m "enable logic"
) || bad "legacy fixture setup"

cd "$LEG" || exit 1
LSK=".agents/skills/decision-trail/scripts"

out=$(bash "$LSK/migrate-legacy.sh" --check 2>&1)
assert_grep "migration detects a legacy runtime" "legacy" "$out"

# Before migrating, the helpers must still read the old directory rather than
# reporting the branch as untracked.
out=$(bash "$LSK/collect.sh" main 2>&1)
assert_grep "legacy rows are readable before migration" "chose the old engine" "$out"

out=$(bash "$LSK/toggle.sh" on main 2>&1)
assert_grep "toggle migrates the legacy runtime" "migrated the pre-rename runtime" "$out"
assert "legacy directory is gone" "[ ! -d '$LEG/.logic' ]"
assert "runtime moved to the new name" "[ -f '$LEG/.decision-trail/config.json' ]"
assert "stale engine removed" "[ ! -f '$LEG/.decision-trail/runtime/logic.sh' ]"
assert "new engine written" "[ -f '$LEG/.decision-trail/runtime/decision-trail.sh' ]"
hp=$(git config core.hooksPath)
assert "hooksPath follows the move" "[ '$hp' = '.decision-trail/githooks' ]"

out=$(bash "$LSK/collect.sh" main 2>&1)
assert_grep "rows recorded under the old name survive" "chose the old engine" "$out"

# Capture has to keep working on the migrated tree, not just look right.
git add -A && git commit -q -m "post-migration commit"
out=$(bash "$LSK/collect.sh" main 2>&1)
assert_grep "capture works after migration" "post-migration commit" "$out"

out=$(bash "$LSK/toggle.sh" on main 2>&1)
assert_not_grep "migration is idempotent" "migrated the pre-rename runtime" "$out"

# Two runtimes side by side is ambiguous, and guessing would silently drop one.
mkdir -p .logic && cp .decision-trail/config.json .logic/config.json
out=$(bash "$LSK/migrate-legacy.sh" 2>&1); rc=$?
assert "migration refuses when both directories exist" "[ $rc -ne 0 ]"
assert_grep "the refusal explains the choice" "Refusing to guess" "$out"
rm -rf .logic
cd "$TMP/repo" || exit 1

# ===========================================================================
# Regressions for the migration defects (skills-7am)
# ===========================================================================

# 7am.2 — a sibling worktree still on the pre-rename name must not fall out of
# the trail. The committed-runtime design migrates branch by branch, so during
# the compatibility window one worktree holds .decision-trail/audit/ while its
# neighbour still holds .logic/audit/. dt_dir's fallback only covers the current
# checkout, so without an explicit probe the neighbour's rows vanish from show
# and from the conflict pre-filters that read the same collection.
# Branched off main, not off feature/widget: conflicts.sh also keeps worktrees
# whose branch descends from the logical branch, and that route would let this
# pass without the rows ever being read.
git worktree add -q "$TMP/legacy-wt" -b legacy/sibling main >/dev/null 2>&1
# Ask git for the path it recorded: on macOS the tmpdir is reached through a
# symlink, and a row whose worktree column disagrees with git's view would not
# match itself in conflicts.sh.
LEGWT=$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}' | grep -F legacy-wt | head -1)
assert "legacy sibling worktree created" "[ -n '$LEGWT' ] && [ -d '$LEGWT' ]"
mkdir -p "$LEGWT/.logic/audit/$slug"
{
  printf 'ts\tactor\tphase\tdecision\twhy\tevidence\tresult\tkind\tsha\tworktree\tconfidence\n'
  printf '2026-02-02T00:00:00Z\tSibling Bot\tcore\tunmigrated sibling row\tstill on the old name\t\t\tdecision\t\t%s\thigh\n' "$LEGWT"
} > "$LEGWT/.logic/audit/$slug/sibling.tsv"

cw=$(bash "$SK/collect.sh" feature/widget)
assert_grep "unmigrated sibling worktree rows reach collect" "unmigrated sibling row" "$cw"
nleg=$(printf '%s' "$cw" | jq '[.[] | select(.decision=="unmigrated sibling row")] | length' 2>/dev/null)
assert "the sibling row is collected exactly once" "[ ${nleg:-0} -eq 1 ]"

# conflicts.sh sources its rows from collect.sh, so the worktree that wrote them
# has to show up as a participating stream. Otherwise a real cross-worktree
# conflict is filtered out before the model ever sees it.
cfl=$(bash "$SK/conflicts.sh" feature/widget 2>/dev/null)
sidx=$(printf '%s' "$cfl" | jq -r --arg p "$LEGWT" '[.streams[].worktree] | index($p) | tostring' 2>/dev/null)
assert "the legacy sibling counts as a conflict stream" "[ '${sidx:-null}' != 'null' ]"

# A worktree holding the same row under both names mid-migration must not
# double-count it.
mkdir -p "$LEGWT/.decision-trail/audit/$slug"
cp "$LEGWT/.logic/audit/$slug/sibling.tsv" "$LEGWT/.decision-trail/audit/$slug/sibling.tsv"
cwb=$(bash "$SK/collect.sh" feature/widget)
nboth=$(printf '%s' "$cwb" | jq '[.[] | select(.decision=="unmigrated sibling row")] | length' 2>/dev/null)
assert "a worktree carrying both directories does not double-count" "[ ${nboth:-0} -eq 1 ]"

rm -rf "$LEGWT/.logic"
cwm=$(bash "$SK/collect.sh" feature/widget)
nmig=$(printf '%s' "$cwm" | jq '[.[] | select(.decision=="unmigrated sibling row")] | length' 2>/dev/null)
assert "the sibling row survives that worktree's own migration" "[ ${nmig:-0} -eq 1 ]"

# 7am.1 — relabelling must enumerate every legacy row, and must verify itself.
# bd's list caps at 50 by default, and a silently truncated relabel leaves rows
# under a label nothing queries any more while reporting success. Driven by a
# stub bd so the assertion is about our arguments, not the local bd build.
BDD="$TMP/bdstub"
mkdir -p "$BDD"
cat > "$BDD/bd" <<'STUB'
#!/bin/sh
# Minimal bd for the migration tests. Honours the documented list contract:
# results are capped at 50 unless --limit says otherwise. BD_STUB_FAIL lists
# ids whose update must fail; BD_STUB_NOLIMIT makes --limit unsupported.
db="${BD_STUB_DB:?}"
cmd="${1:-}"; shift 2>/dev/null
case "$cmd" in
  --version|version) echo "bd version stub-1"; exit 0 ;;
  query) [ "${1:-}" = "--help" ] && exit 0; echo '[]'; exit 0 ;;
  create)
    [ "${1:-}" = "--help" ] && { echo "Usage: bd create --metadata TYPE decision"; exit 0; }
    exit 0 ;;
  list)
    limit=50
    while [ $# -gt 0 ]; do
      case "$1" in
        --limit|-n)
          if [ -n "${BD_STUB_NOLIMIT:-}" ]; then echo "unknown flag: --limit" >&2; exit 1; fi
          limit="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    if [ "$limit" -eq 0 ]; then jq -c '.' "$db"; else jq -c ".[0:$limit]" "$db"; fi
    exit 0 ;;
  update)
    id="${1:-}"; shift 2>/dev/null
    add=""; rem=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --add-label) add="$2"; shift 2 ;;
        --remove-label) rem="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    case " ${BD_STUB_FAIL:-} " in *" $id "*) exit 1 ;; esac
    jq --arg id "$id" --arg add "$add" --arg rem "$rem" \
      'map(if .id == $id then .labels = (((.labels // []) - [$rem]) + [$add] | unique) else . end)' \
      "$db" > "$db.tmp" && mv "$db.tmp" "$db"
    exit 0 ;;
esac
exit 0
STUB
chmod +x "$BDD/bd"

BDDB="$TMP/bd-db.json"
# 60 legacy rows — past the 50 cap, so a capped enumeration cannot pass.
seed_bd_db() {
  jq -n '[range(0;60) | {id:("stub-\(.)"),
    labels: (if . % 10 == 0 then ["logic-stub"] else ["logic:main"] end)}]' > "$BDDB"
}
legacy_left_in_db() {
  jq '[.[] | (.labels // [])[] | select(startswith("logic:") or . == "logic-stub")] | length' "$BDDB"
}

LEGB="$TMP/legacy-beads"
mkdir -p "$LEGB/.agents/skills"
cp -R "$CORE_DIR" "$LEGB/.agents/skills/decision-trail"
BSK="$LEGB/.agents/skills/decision-trail/scripts"
(
  cd "$LEGB" || exit 1
  git init -q -b main
  git config user.name  "Selftest Bot"
  git config user.email "selftest@example.com"
  echo hello > README.md
  git add -A && git commit -q -m init
  mkdir -p .logic/runtime .logic/githooks .logic/audit/main
  printf '{"version":1,"default":"off","branches":{"main":"on"},"storage":"beads","storageOverrides":{}}\n' \
    > .logic/config.json
) || bad "beads legacy fixture setup"

run_migrate() {  # run_migrate <args...> — stub bd on PATH, in the beads fixture
  ( cd "$LEGB" && PATH="$BDD:$PATH" BD_STUB_DB="$BDDB" \
      BD_STUB_FAIL="${BD_STUB_FAIL:-}" BD_STUB_NOLIMIT="${BD_STUB_NOLIMIT:-}" \
      bash "$BSK/migrate-legacy.sh" "$@" 2>&1 )
}

seed_bd_db
out=$(run_migrate); rc=$?
assert "migration with a beads backend succeeds" "[ $rc -eq 0 ]"
assert_grep "every legacy row is relabelled, not just the first page" "rewritten on 60 row(s)" "$out"
assert_grep "a clean relabel says nothing is left" "0 still legacy" "$out"
assert "no legacy label survives a clean relabel" "[ \"\$(legacy_left_in_db)\" -eq 0 ]"

# A failed bd update must not be able to look like a clean run: the self-check
# re-queries rather than trusting the loop's own tally.
seed_bd_db
out=$(BD_STUB_FAIL="stub-1 stub-2 stub-3" run_migrate --relabel); rc=$?
assert "a partial relabel exits non-zero" "[ $rc -ne 0 ]"
assert_grep "a partial relabel reports the failures" "3 update(s) failed, 3 still legacy" "$out"
assert_grep "a partial relabel warns about the rows left behind" "WARNING: 3 bd row(s) still carry" "$out"
wn=$(cat "$LEGB/.decision-trail/WARNINGS" 2>/dev/null)
assert_grep "the partial relabel is recorded in WARNINGS" "still carry a logic" "$wn"

# --relabel is the recovery path: the full migration exits early once .logic/ is
# gone, so without it a partial relabel could never be finished.
out=$(run_migrate --relabel); rc=$?
assert "re-running --relabel finishes the job" "[ $rc -eq 0 ]"
assert_grep "the re-run reports nothing left" "0 still legacy" "$out"
assert "no legacy label survives the re-run" "[ \"\$(legacy_left_in_db)\" -eq 0 ]"

# A bd too old for --limit must relabel what it can and refuse to certify the
# rest, rather than reporting a clean run over a capped window.
seed_bd_db
out=$(BD_STUB_NOLIMIT=1 run_migrate --relabel); rc=$?
assert "an uncappable listing is not reported as clean" "[ $rc -ne 0 ]"
assert_grep "a capped listing still relabels what it sees" "rewritten on 50 row(s)" "$out"
assert_grep "a capped listing refuses to certify completeness" "unknown how many are left" "$out"
assert "a capped listing leaves the rows beyond the cap" "[ \"\$(legacy_left_in_db)\" -eq 10 ]"

# A beads trail relabelled where bd is missing or too old rewrites nothing, so
# reporting "none left" would be a lie about rows that are still out there.
mkdir -p "$TMP/oldbd"
cat > "$TMP/oldbd/bd" <<'OLD'
#!/bin/sh
case "$1" in
  query) echo "unknown command: query" >&2; exit 1 ;;
  --version|version) echo "bd version 0.49.1"; exit 0 ;;
esac
exit 0
OLD
chmod +x "$TMP/oldbd/bd"
rm -f "$LEGB/.decision-trail/.bd-capability"
out=$( cd "$LEGB" && PATH="$TMP/oldbd:$PATH" bash "$BSK/migrate-legacy.sh" --relabel 2>&1 ); rc=$?
rm -f "$LEGB/.decision-trail/.bd-capability"
assert "a beads trail with no usable bd is not certified clean" "[ $rc -ne 0 ]"
assert_grep "the unusable bd is named as the reason" "WARNING: this trail uses the beads backend" "$out"

echo
echo "selftest: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
