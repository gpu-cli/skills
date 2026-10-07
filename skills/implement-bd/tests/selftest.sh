#!/usr/bin/env bash
# implement-bd self-test. What can rot: the Stop guard that stands in for
# /goal, the per-host invocation switches, the reviewer contract, and the one
# word the skill must never contain.
#
# Usage: bash selftest.sh   (exits non-zero if any assertion fails)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
SKILL_MD="$SKILL_DIR/SKILL.md"

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; }
assert()      { if eval "$2"; then ok "$1"; else bad "$1 -> [$2]"; fi; }
assert_grep() { if grep -qE -- "$2" "$3"; then ok "$1"; else bad "$1 (no match /$2/ in $3)"; fi; }

# Prose reflows, so a phrase pinned by grep must not die to a line wrap.
assert_flat() {
    if tr '\n' ' ' < "$3" | tr -s ' ' | grep -qiF -- "$2"; then
        ok "$1"
    else
        bad "$1 (no match '$2' in flattened $3)"
    fi
}

echo "implement-bd selftest in $SKILL_DIR"

# --- structure --------------------------------------------------------------

for f in SKILL.md references/reviewer.md references/verdict.schema.json agents/openai.yaml; do
    assert "$f exists" "[ -f '$SKILL_DIR/$f' ]"
done

assert_grep "frontmatter declares the skill name" '^name: implement-bd$' "$SKILL_MD"
assert_grep "Claude Code: user-invoked only"       '^disable-model-invocation: true$' "$SKILL_MD"
assert_grep "Codex: user-invoked only"             'allow_implicit_invocation: false' "$SKILL_DIR/agents/openai.yaml"

for md in "$SKILL_MD" "$SKILL_DIR"/references/*.md; do
    base_dir="$(dirname "$md")"
    while IFS= read -r link; do
        [ -n "$link" ] || continue
        case "$link" in http*|/*) continue ;; esac
        assert "link resolves: $(basename "$md") -> $link" "[ -f '$base_dir/$link' ]"
    done < <(grep -oE '\]\([A-Za-z0-9/._-]+\.(md|json)\)' "$md" | sed 's/^](\(.*\))$/\1/' | sort -u)
done

if command -v python3 >/dev/null 2>&1; then
    assert "verdict schema is valid JSON" \
        "python3 -I -m json.tool '$SKILL_DIR/references/verdict.schema.json' >/dev/null"
fi

# --- the argument table covers every documented argument ---------------------

for arg in '`<id>`' '`review=`' '`effort=`' '`branch=`' '`finish=`'; do
    assert "argument row: $arg" "grep -qF -- '| $arg |' '$SKILL_MD'"
done
finish_row="$(grep -F -- '| `finish=` |' "$SKILL_MD")"
for mode in commit draft pr; do
    case "$finish_row" in
        *"\`$mode\`"*) ok "finish mode documented: $mode" ;;
        *) bad "finish mode documented: $mode" ;;
    esac
done

# --- the deep-reasoning keyword stays the user's to type ---------------------
#
# Claude Code raises reasoning depth whenever that word appears in skill
# content, so a single mention here would silently force it on every run.

word="ult""rathink"
hits="$(grep -rli -- "$word" "$SKILL_DIR"; echo "status=$?")"
assert "no file in the skill contains the reasoning keyword" "[ '$hits' = 'status=1' ]"

# --- the completion condition and its goal adapters --------------------------

assert_flat "final line: APPROVED" 'IMPLEMENT-BD: APPROVED <id>' "$SKILL_MD"
assert_flat "final line: BLOCKED"  'IMPLEMENT-BD: BLOCKED <id>'  "$SKILL_MD"
assert_flat "Claude Code arms the Stop hook with the session id" 'touch "$d/${CLAUDE_SESSION_ID}"' "$SKILL_MD"
assert_flat "Codex sets a goal with its goal tool" 'create_goal' "$SKILL_MD"
assert_flat "other hosts keep working in the turn" 'Any other host' "$SKILL_MD"
assert_flat "the review loop is capped" 'three rounds' "$SKILL_MD"
assert_flat "the reviewer never sees the implementer's reasoning" 'never your reasoning' "$SKILL_MD"
assert_flat "reviewer table covers cross-vendor CLIs" 'codex exec -m' "$SKILL_DIR/references/reviewer.md"
assert_flat "reviewer table covers cross-vendor CLIs" 'claude -p --model' "$SKILL_DIR/references/reviewer.md"
assert_flat "suggestions never block" 'never blocks' "$SKILL_DIR/references/reviewer.md"

# Skill hook commands get no ${CLAUDE_SKILL_DIR}, so the guard must be inline.
assert "hook command does not depend on CLAUDE_SKILL_DIR" \
    "! awk '/^---$/{n++; next} n==1' '$SKILL_MD' | grep -q 'CLAUDE_SKILL_DIR'"

# --- the Stop guard, run against real hook input -----------------------------

tmp="$(mktemp -d 2>/dev/null || echo "/tmp/implement-bd-selftest.$$")"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

# The command is the block scalar under `command: |`, indented 12 spaces.
awk '/^---$/{n++; next} n==1 && /command: \|/{grab=1; next} grab && /^            /{sub(/^            /, ""); print; next} grab{exit}' \
    "$SKILL_MD" > "$tmp/guard.sh"
assert "guard extracted from frontmatter" "[ -s '$tmp/guard.sh' ]"

repo="$tmp/repo"
git init -q "$repo"
nogit="$tmp/nogit"
mkdir -p "$nogit"

hook_input() {  # <cwd> <last message, JSON-escaped> <background tasks JSON>
    printf '{"session_id":"s1","cwd":"%s","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"%s","background_tasks":%s,"session_crons":[]}' \
        "$1" "$2" "$3"
}
run_guard() { hook_input "$@" | bash "$tmp/guard.sh"; }
blocks()    { run_guard "$@" | grep -q '"decision":"block"'; }
marker="$repo/.git/implement-bd/s1"

assert "unarmed session: stop allowed" "! blocks '$repo' 'Done.' '[]'"
assert "outside a git repo: stop allowed" "! blocks '$nogit' 'Done.' '[]'"

mkdir -p "$repo/.git/implement-bd" && : > "$marker"
assert "armed, no final line: stop blocked" "blocks '$repo' 'Tests pass, starting review.' '[]'"
assert "armed, final line only quoted mid-sentence: stop blocked" \
    "blocks '$repo' 'I will print IMPLEMENT-BD: APPROVED when done.' '[]'"
assert "armed, final line restated early in a plan: stop blocked" \
    "blocks '$repo' 'Plan, ending with:\\nIMPLEMENT-BD: APPROVED x-1 sha\\nStarting now.' '[]'"
assert "armed, final line in markdown: stop blocked" \
    "blocks '$repo' '**IMPLEMENT-BD: APPROVED x-1 sha**' '[]'"
assert "armed, subagent reviewer still running: stop allowed" \
    "! blocks '$repo' 'Waiting on the reviewer.' '[{\"id\":\"a1\",\"type\": \"subagent\",\"agent_type\":\"general-purpose\"}]'"
assert "the allowed background stop keeps the run armed" "[ -f '$marker' ]"
assert "armed, only a background shell running: stop blocked" \
    "blocks '$repo' 'Dev server is up.' '[{\"id\":\"b1\",\"type\":\"shell\",\"command\":\"npm run dev\"}]'"
assert "another session's run does not block this one" \
    "! hook_input '$repo' 'Done.' '[]' | sed 's/\"s1\"/\"s2\"/' | bash '$tmp/guard.sh' | grep -q block"

assert "armed, BLOCKED final line on its own line: stop allowed" \
    "! blocks '$repo' 'Three rounds used.\\nIMPLEMENT-BD: BLOCKED x-1 open findings' '[]'"
assert "the final line disarms the run" "[ ! -f '$marker' ]"

: > "$marker"
assert "armed, message that is only the APPROVED line: stop allowed" \
    "! blocks '$repo' 'IMPLEMENT-BD: APPROVED x-1 abc123' '[]'"
assert "APPROVED disarms the run" "[ ! -f '$marker' ]"

: > "$marker"
assert "armed, final line then a trailing newline: stop allowed" \
    "! blocks '$repo' 'Done.\\nIMPLEMENT-BD: APPROVED x-1 https://example.test/pr/1\\n' '[]'"

: > "$marker"
touch -t 202001010000 "$marker"
assert "a marker idle past six hours no longer blocks" "! blocks '$repo' 'Unrelated work.' '[]'"
assert "the stale marker is removed" "[ ! -f '$marker' ]"

echo
printf 'implement-bd selftest: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
