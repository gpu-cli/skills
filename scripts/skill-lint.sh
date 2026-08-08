#!/usr/bin/env bash
# Report and enforce the always-on context cost of every skill in skills/.
#
# A skill's frontmatter description is injected into every session whether or
# not the skill is used, so it is billed on every turn. The SKILL.md body is
# billed once per invocation. Details belong in references/, which load only
# when a phase needs them.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$ROOT/skills"
ALLOW_FILE="$ROOT/scripts/skill-lint.allow"

DESC_MAX="${SKILL_LINT_DESC_MAX:-45}"
BODY_MAX="${SKILL_LINT_BODY_MAX:-2000}"

# Characters per token. Claude Code picks this per model: 4 for Claude 3.x and
# 4.x, 3 for every model since. Match the model you actually run.
BYTES_PER_TOKEN="${SKILL_LINT_BYTES_PER_TOKEN:-3}"

# Claude Code's own estimate: round(chars / bytesPerToken), half away from zero.
est_tokens() {
    local chars
    chars=$(wc -m | tr -d ' ')
    echo $(((chars * 2 + BYTES_PER_TOKEN) / (BYTES_PER_TOKEN * 2)))
}

# How Claude Code renders that estimate in the /skills picker.
display_tokens() {
    if [ "$1" -lt 20 ]; then
        echo '< 20'
    else
        echo "~$(((($1 + 5) / 10) * 10))"
    fi
}

# Value of a frontmatter key, with block scalars and continuation lines folded
# onto one line and surrounding quotes stripped.
read_field() {
    awk -v key="$2" '
        NR == 1 && $0 != "---" { exit }
        NR == 1 { fm = 1; next }
        fm && $0 == "---" { exit }
        fm {
            if (in_val) {
                if ($0 ~ /^[ \t]+[^ \t]/) {
                    line = $0
                    sub(/^[ \t]+/, "", line)
                    printf " %s", line
                    next
                }
                in_val = 0
            }
            if (index($0, key ":") == 1) {
                val = substr($0, length(key) + 2)
                sub(/^[ \t]*/, "", val)
                if (val == ">" || val == "|" || val == ">-" || val == "|-") val = ""
                printf "%s", val
                in_val = 1
            }
        }
    ' "$1" | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/" -e 's/^ *//' -e 's/ *$//'
}

# Everything after the closing frontmatter delimiter, or the whole file when
# there is no frontmatter.
read_body() {
    awk '
        NR == 1 && $0 != "---" { body = 1 }
        NR == 1 && $0 == "---" { fm = 1; next }
        fm && !body && $0 == "---" { body = 1; next }
        body { print }
    ' "$1"
}

allowed_body_max() {
    local skill="$1"
    [ -f "$ALLOW_FILE" ] || { echo "$BODY_MAX"; return; }
    awk -v s="$skill" -v d="$BODY_MAX" '
        /^[ \t]*(#|$)/ { next }
        $1 == s { print $2; found = 1; exit }
        END { if (!found) print d }
    ' "$ALLOW_FILE"
}

failures=0
desc_total=0

printf '%-18s %12s %8s %13s\n' 'SKILL' 'ALWAYS-ON' 'SHOWN' 'BODY TOKENS'
printf '%-18s %12s %8s %13s\n' '------------------' '------------' '--------' '-------------'

for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
    [ -e "$skill_md" ] || continue
    skill="$(basename "$(dirname "$skill_md")")"

    desc="$(read_field "$skill_md" description)"
    if [ -z "$desc" ]; then
        printf '%-18s %12s %8s %13s  FAIL: no frontmatter description\n' "$skill" '-' '-' '-'
        failures=$((failures + 1))
        continue
    fi

    # Claude Code bills `[name, description, whenToUse].join(" ")`, not the
    # description alone — the name rides along on every session too.
    name="$(read_field "$skill_md" name)"
    when="$(read_field "$skill_md" whenToUse)"
    routing="$name $desc"
    [ -n "$when" ] && routing="$routing $when"

    desc_tokens=$(printf '%s' "$routing" | est_tokens)
    desc_shown=$(display_tokens "$desc_tokens")
    body_tokens=$(read_body "$skill_md" | est_tokens)
    limit="$(allowed_body_max "$skill")"
    desc_total=$((desc_total + desc_tokens))

    desc_flag=''
    body_flag=''
    if [ "$desc_tokens" -gt "$DESC_MAX" ]; then
        desc_flag="  FAIL: description ${desc_tokens} > ${DESC_MAX} tokens"
        failures=$((failures + 1))
    fi
    if [ "$body_tokens" -gt "$limit" ]; then
        body_flag="  FAIL: body ${body_tokens} > ${limit} tokens"
        failures=$((failures + 1))
    fi

    printf '%-18s %12s %8s %13s%s%s\n' \
        "$skill" "$desc_tokens" "$desc_shown" "$body_tokens" "$desc_flag" "$body_flag"
done

printf '%-18s %12s\n' '------------------' '------------'
printf '%-18s %12s   (every session, used or not)\n' 'TOTAL ALWAYS-ON' "$desc_total"

# Generated outputs must never be tracked inside a skill directory: they ship to
# every install and an agent reading the skill can mistake them for instructions.
payload="$(git -C "$ROOT" ls-files skills/ \
    | grep -E '(^|/)artifacts/|-analysis-.*\.md$|-report-.*\.md$|-shielded/' || true)"
if [ -n "$payload" ]; then
    echo
    echo "FAIL: generated outputs tracked inside skills/ — move them out or gitignore them:"
    printf '  %s\n' $payload
    failures=$((failures + 1))
fi

echo
if [ "$failures" -gt 0 ]; then
    echo "skill-lint: $failures failure(s)"
    echo "Trim the description to routing triggers, or move body detail into references/."
    exit 1
fi
echo "skill-lint: ok"
