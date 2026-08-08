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

# Prose reflows, so a phrase pinned by grep must not die to a line wrap.
# Flatten the file to one line before matching.
assert_flat() {
    if tr '\n' ' ' < "$3" | grep -qi -- "$2"; then
        ok "$1"
    else
        bad "$1 (no match /$2/ in flattened $3)"
    fi
}

echo "less selftest in $SKILL_DIR"

# --- structure --------------------------------------------------------------

for f in SKILL.md references/compression.md references/sticky.md; do
    assert "$f exists" "[ -f '$SKILL_DIR/$f' ]"
done

assert_grep "frontmatter declares the skill name" '^name: less$' "$SKILL_DIR/SKILL.md"
assert_grep "frontmatter carries a description" '^description:' "$SKILL_DIR/SKILL.md"

# Every relative markdown link must resolve FROM THE FILE THAT CONTAINS IT —
# a link's meaning depends on where it is written, so resolving everything
# against references/ would bless links that render broken.
for md in "$SKILL_DIR"/SKILL.md "$SKILL_DIR"/references/*.md; do
    base_dir="$(dirname "$md")"
    while IFS= read -r link; do
        [ -n "$link" ] || continue
        case "$link" in http*|/*) continue ;; esac
        assert "link resolves: $(basename "$md") -> $link" "[ -f '$base_dir/$link' ]"
    done < <(grep -oE '\]\([A-Za-z0-9/._-]+\.md\)' "$md" | sed 's/^](\(.*\))$/\1/' | sort -u)
done

# --- the router covers every documented command -----------------------------
#
# Anchored to the argument table's own rows: a stray mention of the word
# elsewhere in the body must not stand in for a deleted router entry.

assert_grep "router row: bare /less"          '^| \*(none)\*'    "$SKILL_DIR/SKILL.md"
assert_grep "router row: N sentences"         '^| `N`'           "$SKILL_DIR/SKILL.md"
assert_grep "router row: paragraph"           '^| `paragraph`'   "$SKILL_DIR/SKILL.md"
assert_grep "router row: sticky set"          'set` |'           "$SKILL_DIR/SKILL.md"
assert_grep "router row: unset"               '^| `unset`'       "$SKILL_DIR/SKILL.md"
assert_grep "router row: unrecognized"        '^| anything else' "$SKILL_DIR/SKILL.md"
assert_flat "bare set has a defined meaning"  'bare `set`'       "$SKILL_DIR/SKILL.md"

# All six rules, individually — a lone "6." after a merge must not pass.
for n in 1 2 3 4 5 6; do
    assert_grep "body carries rule $n" "^$n\. \*\*" "$SKILL_DIR/SKILL.md"
done

# --- portability: no agent-specific machinery -------------------------------
#
# The skill is deliberately in-context only. Hooks, settings files, and state
# files would tie it to one agent; catching that here keeps the decision from
# being undone by accident.

for forbidden in 'settings\.json' 'UserPromptSubmit' 'hooks?:' '\.claude/'; do
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
# way a reader would. Heuristic, so it hedges the known traps: code spans are
# stripped first (`foo.sh:12` must not count), common abbreviations are
# neutralized, and terminal punctuation still counts when a quote, paren, or
# bold marker closes over it.

sentences_under() {
    awk -v want="$1" '
        $0 == want { grab = 1; next }
        grab && /^###/ { exit }
        grab && /^> / { sub(/^> /, ""); buf = buf " " $0 }
        END {
            gsub(/`[^`]*`/, "X", buf)
            gsub(/[eE]\.g\.|[iI]\.e\.|vs\.|etc\./, "X", buf)
            n = split(buf, _, /[.!?]["'"'"')*]*([ \t]|$)/)
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

# The counter itself is exercised, so a regex regression cannot pass silently.
probe_dir="$(mktemp -d 2>/dev/null || echo /tmp/less-selftest.$$)"
trap 'rm -rf "$probe_dir"' EXIT
cat > "$probe_dir/probe.md" <<'EOF'
### probe
> First sentence (with a paren.) Second, e.g. with an abbreviation. **Third in
> bold.** Fourth mentions `file.sh:12` and stops.
EOF
probe=$(awk -v want='### probe' '
    $0 == want { grab = 1; next }
    grab && /^###/ { exit }
    grab && /^> / { sub(/^> /, ""); buf = buf " " $0 }
    END {
        gsub(/`[^`]*`/, "X", buf)
        gsub(/[eE]\.g\.|[iI]\.e\.|vs\.|etc\./, "X", buf)
        n = split(buf, _, /[.!?]["'"'"')*]*([ \t]|$)/)
        print n - 1
    }
' "$probe_dir/probe.md")
assert "sentence counter handles parens, bold, abbreviations (got $probe)" "[ '$probe' -eq 4 ]"

# No worked example may smuggle content past the cap as free lines: bullets,
# numbered steps, and headers all escape the sentence count the same way.
assert "worked examples use prose, not list or header lines" \
    "! awk '/^## Worked examples/,/^## Degenerate/' '$SKILL_DIR/references/compression.md' | grep -qE '^> *([-*+] |[0-9]+[.)] |#)'"

# --- the fidelity floor is stated where it is needed -------------------------

assert_flat "compression.md defines the fidelity floor" 'fidelity floor' \
    "$SKILL_DIR/references/compression.md"
assert_flat "sticky.md separates the cap from the work" 'never the work' \
    "$SKILL_DIR/references/sticky.md"
assert_flat "sticky.md documents the context limitation" 'compact' \
    "$SKILL_DIR/references/sticky.md"

# The body must carry these on its own. A reader who never opens the
# references must still know a cap shortens the report, not the work behind
# it, and that the floor can bend the cap.
assert_flat "SKILL.md body separates the cap from the work" 'never the work' \
    "$SKILL_DIR/SKILL.md"
assert_flat "SKILL.md body carries the bend, not just the hard cap" 'bend the cap' \
    "$SKILL_DIR/SKILL.md"

# --- resolutions that eval found the skill needed ---------------------------
#
# Each of these settles a conflict a reader hit in an earlier draft. Losing one
# reopens a question the skill previously failed to answer, so they are pinned.

assert_grep "the floor is ranked, not a flat set" '^| 1 |' \
    "$SKILL_DIR/references/compression.md"
assert_flat "the bend is scoped to rows 1-3" 'rows only' \
    "$SKILL_DIR/references/compression.md"
assert_flat "the bend is per response, not per item" 'per response, not one per unmet item' \
    "$SKILL_DIR/references/compression.md"
assert_flat "the clause bound is stated" 'clause bound' \
    "$SKILL_DIR/references/compression.md"
assert_flat "prose series are distinguished from banned lists" 'a free line that never has to pay' \
    "$SKILL_DIR/references/compression.md"
assert_flat "risk-bearing hedging is protected" 'not hedging' \
    "$SKILL_DIR/references/compression.md"
assert_grep "a worked example shows the free code block" '^> ```bash' \
    "$SKILL_DIR/references/compression.md"
assert_flat "a worked example covers an unresolved failure" 'When the failure is still open' \
    "$SKILL_DIR/references/compression.md"
assert_flat "uncertainty around a decision is protected too" 'risk or a decision' \
    "$SKILL_DIR/references/compression.md"
assert_flat "prose is preferred over pointing when it fits" 'point only when they will not' \
    "$SKILL_DIR/references/compression.md"

# Status text must not become a way to stay verbose under a cap.
assert_flat "status text is not a side channel around the cap" 'not a side channel' \
    "$SKILL_DIR/references/sticky.md"
assert_flat "the compression source is the message the reader received" 'actually received' \
    "$SKILL_DIR/SKILL.md"

# The acknowledgment must stay plain text: fencing it would claim the one code
# block that rule 5 reserves for the payload.
assert "sticky-cap acknowledgment is not shown fenced" \
    "! grep -q '^\`\`\`' '$SKILL_DIR/references/sticky.md'"

echo
printf 'less selftest: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
