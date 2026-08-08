#!/usr/bin/env bash
# less self-test. The skill ships no scripts, so what can rot is the prose:
# a worked example that quietly breaks the cap it is demonstrating, a
# reference link that no longer resolves, or agent-specific machinery
# reintroduced into a skill that is meant to be portable.
#
# Usage: bash selftest.sh   (exits non-zero if any assertion fails)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; }
assert()      { if eval "$2"; then ok "$1"; else bad "$1 -> [$2]"; fi; }
assert_grep() { if grep -qi -- "$2" "$3"; then ok "$1"; else bad "$1 (no match /$2/ in $3)"; fi; }

echo "less selftest in $SKILL_DIR"

# --- structure --------------------------------------------------------------

for f in SKILL.md references/compression.md references/sticky.md; do
    assert "$f exists" "[ -f '$SKILL_DIR/$f' ]"
done

assert_grep "frontmatter declares the skill name" '^name: less$' "$SKILL_DIR/SKILL.md"
assert_grep "frontmatter carries a description" '^description:' "$SKILL_DIR/SKILL.md"

# Every relative markdown link in the skill must resolve.
while IFS= read -r link; do
    target="$SKILL_DIR/$link"
    case "$link" in references/*) ;; *) target="$SKILL_DIR/references/$link" ;; esac
    assert "link resolves: $link" "[ -f '$target' ]"
done < <(grep -rho '](\([a-z/.-]*\.md\))' "$SKILL_DIR"/SKILL.md "$SKILL_DIR"/references/*.md \
    | sed 's/^](\(.*\))$/\1/' | sort -u)

# --- the router covers every documented command -----------------------------

for arg in 'paragraph' 'set' 'unset'; do
    assert_grep "router documents \`$arg\`" "$arg" "$SKILL_DIR/SKILL.md"
done
assert_grep "router handles an unrecognized argument" 'anything else' "$SKILL_DIR/SKILL.md"
assert_grep "body carries all six rules" '^6\. \*\*' "$SKILL_DIR/SKILL.md"

# --- portability: no agent-specific machinery -------------------------------
#
# The skill is deliberately in-context only. Hooks, settings files, and state
# files would tie it to one agent; catching that here keeps the decision from
# being undone by accident.

for forbidden in 'settings\.json' 'UserPromptSubmit' 'hooks\?:' '\.claude/'; do
    if grep -rqiE -- "$forbidden" "$SKILL_DIR"/SKILL.md "$SKILL_DIR"/references/*.md; then
        bad "portability: /$forbidden/ appears in the skill"
    else
        ok "portability: no /$forbidden/"
    fi
done
assert "skill ships no scripts directory" "[ ! -d '$SKILL_DIR/scripts' ]"

# --- the worked examples obey the caps they demonstrate ----------------------
#
# Pull the blockquote under a worked-example heading and count sentences the
# way a reader would: terminal punctuation followed by a space or end of line,
# with code spans stripped first so `foo.sh:12` and `palette.ts` do not count.

sentences_under() {
    awk -v want="$1" '
        $0 == want { grab = 1; next }
        grab && /^###/ { exit }
        grab && /^> / { sub(/^> /, ""); buf = buf " " $0 }
        END {
            gsub(/`[^`]*`/, "X", buf)
            n = split(buf, _, /[.!?]("|'"'"')?([ \t]|$)/)
            print n - 1
        }
    ' "$SKILL_DIR/references/compression.md"
}

one=$(sentences_under '### `/less 1`')
two=$(sentences_under '### `/less 2`')
para=$(sentences_under '### `/less paragraph`')

assert "worked example for /less 1 is one sentence (got $one)"  "[ '$one' -eq 1 ]"
assert "worked example for /less 2 is two sentences (got $two)" "[ '$two' -eq 2 ]"
assert "worked example for /less paragraph is 3-5 sentences (got $para)" \
    "[ '$para' -ge 3 ] && [ '$para' -le 5 ]"

# No worked example may smuggle content past the cap as a list or a header.
assert "worked examples use prose, not bullets" \
    "! awk '/^## Worked examples/,/^## Degenerate/' '$SKILL_DIR/references/compression.md' | grep -qE '^> *[-*] '"

# --- the fidelity floor is stated where it is needed -------------------------

assert_grep "compression.md defines the fidelity floor" 'fidelity floor' \
    "$SKILL_DIR/references/compression.md"
assert_grep "sticky.md separates the cap from the work" 'never the work' \
    "$SKILL_DIR/references/sticky.md"

# The body must carry this on its own. A reader who never opens sticky.md must
# still know a cap shortens the report and not the work behind it.
assert_grep "SKILL.md body separates the cap from the work" 'never the work' \
    "$SKILL_DIR/SKILL.md"

# Status text must not become a way to stay verbose under a cap.
assert_grep "status text is not a side channel around the cap" 'not a side channel' \
    "$SKILL_DIR/references/sticky.md"
assert_grep "the compression source is the message the reader received" 'actually received' \
    "$SKILL_DIR/SKILL.md"
assert_grep "sticky.md documents the context limitation" 'compact' \
    "$SKILL_DIR/references/sticky.md"

# --- resolutions that eval found the skill needed ---------------------------
#
# Each of these settles a conflict a reader hit in an earlier draft. Losing one
# reopens a question the skill previously failed to answer, so they are pinned.

assert_grep "the floor is ranked, not a flat set" '^| 1 |' \
    "$SKILL_DIR/references/compression.md"
assert_grep "the bend is scoped to rows 1-3" 'rows only' \
    "$SKILL_DIR/references/compression.md"
assert_grep "the bend is per response, not per item" 'per response, not one per unmet item' \
    "$SKILL_DIR/references/compression.md"
assert_grep "the clause bound is stated" 'clause bound' \
    "$SKILL_DIR/references/compression.md"
assert_grep "prose series are distinguished from banned lists" 'a free line that never has to pay' \
    "$SKILL_DIR/references/compression.md"
assert_grep "risk-bearing hedging is protected" 'not hedging' \
    "$SKILL_DIR/references/compression.md"
assert_grep "a worked example shows the free code block" '^> ```bash' \
    "$SKILL_DIR/references/compression.md"
assert_grep "a worked example covers an unresolved failure" 'When the failure is still open' \
    "$SKILL_DIR/references/compression.md"
assert_grep "uncertainty around a decision is protected too" 'risk or a$' \
    "$SKILL_DIR/references/compression.md"
assert_grep "prose is preferred over pointing when it fits" 'point only when they will not' \
    "$SKILL_DIR/references/compression.md"

# The acknowledgment must stay plain text: fencing it would claim the one code
# block that rule 5 reserves for the payload.
assert "sticky-cap acknowledgment is not shown fenced" \
    "! grep -q '^\`\`\`' '$SKILL_DIR/references/sticky.md'"

echo
printf 'less selftest: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
