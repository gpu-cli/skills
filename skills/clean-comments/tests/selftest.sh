#!/usr/bin/env bash
# clean-comments self-test: exercises the bundled scripts in a throwaway git
# repo. The cases that matter most are the ones where a naive comment stripper
# would let a real code change through — a `//` inside a URL string, a `#`
# inside a shell parameter expansion, a Python triple-quoted value that is not
# a docstring.
#
# Usage: bash selftest.sh   (exits non-zero if any assertion fails)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(dirname "$SCRIPT_DIR")"
S="$CORE_DIR/scripts"

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; }
assert()          { if eval "$2"; then ok "$1"; else bad "$1 -> [$2]"; fi; }
assert_grep()     { if printf '%s' "$3" | grep -q "$2"; then ok "$1"; else bad "$1 (no match /$2/)"; fi; }
assert_not_grep() { if printf '%s' "$3" | grep -q "$2"; then bad "$1 (unexpected /$2/)"; else ok "$1"; fi; }

TMP="$(mktemp -d 2>/dev/null || echo /tmp/cc-selftest.$$)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP" || exit 1
git init -q -b main
git config user.name "Selftest Bot"
git config user.email "selftest@example.com"

echo "clean-comments selftest in $TMP"

# --- verify: only comment text may change ----------------------------------

cat > app.js <<'EOF'
// Loop through the users and send each one an email
const endpoint = "https://example.com/a";
for (const u of users) send(u, endpoint);
EOF
git add -A && git commit -q -m init

cat > app.js <<'EOF'
const endpoint = "https://example.com/a";
for (const u of users) send(u, endpoint);
EOF
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify passes a comment-only deletion" "[ $rc -eq 0 ]"
assert_grep "verify names the file count" "comment-only in 1 file" "$out"

# A `//` inside a string must not read as a comment, or this change hides.
cat > app.js <<'EOF'
// Loop through the users and send each one an email
const endpoint = "https://example.com/CHANGED";
for (const u of users) send(u, endpoint);
EOF
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify catches a change inside a URL string" "[ $rc -eq 1 ]"
assert_grep "verify reports the changed line" "CODE CHANGED" "$out"
git checkout -q app.js

# Trailing comments: removing one is fine, editing the code beside it is not.
cat > trail.go <<'EOF'
package main

func main() {
	x := compute(1) // this computes the thing
	_ = x
}
EOF
git add -A && git commit -q -m trail
cat > trail.go <<'EOF'
package main

func main() {
	x := compute(1)
	_ = x
}
EOF
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify passes trailing-comment removal" "[ $rc -eq 0 ]"

cat > trail.go <<'EOF'
package main

func main() {
	x := compute(2)
	_ = x
}
EOF
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify catches a code edit beside a removed comment" "[ $rc -eq 1 ]"
git checkout -q trail.go

# Python: a docstring is a comment, a triple-quoted value is code.
cat > svc.py <<'EOF'
def fetch(url):
    """
    Fetch a URL.

    Args:
        url: The URL to fetch.
    """
    query = """
        SELECT id FROM users WHERE active = 1
    """
    return run(query, url)
EOF
git add -A && git commit -q -m py

cat > svc.py <<'EOF'
def fetch(url):
    """Fetch url and return the active user ids."""
    query = """
        SELECT id FROM users WHERE active = 1
    """
    return run(query, url)
EOF
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify passes a docstring rewrite" "[ $rc -eq 0 ]"

cat > svc.py <<'EOF'
def fetch(url):
    """Fetch url and return the active user ids."""
    query = """
        SELECT id FROM users WHERE active = 0
    """
    return run(query, url)
EOF
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify catches an edit inside a triple-quoted value" "[ $rc -eq 1 ]"
git checkout -q svc.py

# A triple-quoted value directly after a `:` line is still a value: `query =`
# before the quote means no docstring, whatever the previous line ends with.
cat > direct.py <<'EOF'
def fetch(url):
    query = """
        SELECT id FROM users WHERE active = 1
    """
    return run(query, url)
EOF
git add -A && git commit -q -m directpy
sed_inplace() { sed -i.bak "$1" "$2" && rm -f "$2.bak"; }
sed_inplace 's/active = 1/active = 0/' direct.py
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify catches an edit in a triple-quoted value after 'def f():'" "[ $rc -eq 1 ]"
git checkout -q direct.py

# A template literal spans lines, so a // on a continuation line is string
# content, not a comment that hides the rest of the line from verify.
cat > tpl.ts <<'EOF'
const tpl = `
  visit https://example.com/v1 for docs
`;
EOF
git add -A && git commit -q -m tpl
sed_inplace 's|/v1|/v2|' tpl.ts
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify catches an edit after // inside a multiline template literal" "[ $rc -eq 1 ]"
git checkout -q tpl.ts

# Same shape in Go: a raw backtick string spans lines.
cat > raw.go <<'EOF'
package main

const usage = `
  see https://example.com/v1 for docs
`
EOF
git add -A && git commit -q -m rawgo
sed_inplace 's|/v1|/v2|' raw.go
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify catches an edit after // inside a Go raw string" "[ $rc -eq 1 ]"
git checkout -q raw.go

# A JS regex literal can contain //; everything after it is still code.
cat > re.js <<'EOF'
const ok = /https:\/\//.test(u);
if (ok) grant(); else deny();
EOF
git add -A && git commit -q -m re
sed_inplace 's/else deny()/else grant()/' re.js
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify catches a change after a regex literal containing //" "[ $rc -eq 1 ]"
git checkout -q re.js

# Heredoc bodies are data: a # line inside one is not a comment.
cat > hd.sh <<'EOF'
#!/usr/bin/env bash
cat <<BANNER
welcome # rules: be nice
BANNER
EOF
git add -A && git commit -q -m hd
sed_inplace 's/be nice/be evil/' hd.sh
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify catches a change inside a shell heredoc" "[ $rc -eq 1 ]"
git checkout -q hd.sh

cat > hd.rb <<'EOF'
CONF = <<~TXT
  retries=3 # max 3 then abort
TXT
EOF
git add -A && git commit -q -m hdrb
sed_inplace 's/max 3/max 9/' hd.rb
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify catches a change inside a ruby heredoc" "[ $rc -eq 1 ]"
git checkout -q hd.rb

# YAML block scalars are strings: a # inside one is not a comment.
cat > ci.yml <<'EOF'
steps:
  - name: fetch
    script: |
      curl -fsSL https://example.com/install.sh # v1 pinned
EOF
git add -A && git commit -q -m yml
sed_inplace 's/v1 pinned/v2 unpinned/' ci.yml
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify catches a change inside a YAML block scalar" "[ $rc -eq 1 ]"
git checkout -q ci.yml

# A triple-quoted string under a dict key is a value, not a docstring.
cat > q.py <<'EOF'
QUERIES = {
    'active':
        """SELECT id FROM users WHERE active = 1""",
}
EOF
git add -A && git commit -q -m qpy
sed_inplace 's/active = 1/active = 0/' q.py
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify catches an edit in a triple-quoted dict value" "[ $rc -eq 1 ]"
git checkout -q q.py

# Rust: '"' is a char literal and must not flip string state.
cat > ch.rs <<'EOF'
fn main() {
    let q = '"';
    let url = "https://x/v1";
}
EOF
git add -A && git commit -q -m chrs
sed_inplace 's|/v1|/v2|' ch.rs
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify catches a change after a rust '\"' char literal" "[ $rc -eq 1 ]"
git checkout -q ch.rs

# A backslash at end of line continues the string onto the next line.
printf 'const s = "abc\\\nxyz // limit is 5";\n' > cont.js
git add -A && git commit -q -m cont
printf 'const s = "abc\\\nxyz // limit is 9";\n' > cont.js
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify catches a change on a backslash-continued string line" "[ $rc -eq 1 ]"
git checkout -q cont.js

# The shebang is executable metadata, not a removable comment.
cat > she.py <<'EOF'
#!/usr/bin/env python3
print("hi")
EOF
git add -A && git commit -q -m she
sed_inplace 's/python3/python2/' she.py
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify catches a shebang edit" "[ $rc -eq 1 ]"
git checkout -q she.py

# PHP hash comments are comments; cleaning one passes.
cat > w.php <<'EOF'
<?php
# remove the temp rows
purge();
EOF
git add -A && git commit -q -m php
cat > w.php <<'EOF'
<?php
purge();
EOF
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify passes a PHP hash-comment removal" "[ $rc -eq 0 ]"
git checkout -q w.php

# Python allows a comment with no space before the #.
cat > tight.py <<'EOF'
x=1# legacy default
EOF
git add -A && git commit -q -m tight
cat > tight.py <<'EOF'
x=1
EOF
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify passes removing a no-space python comment" "[ $rc -eq 0 ]"
git checkout -q tight.py

# Running from a subdirectory must not misread files as new.
mkdir -p sub && cat > sub/deep.js <<'EOF'
// note
const a = 1;
EOF
git add -A && git commit -q -m sub
sed_inplace 's/a = 1/a = 2/' sub/deep.js
out=$(cd sub && node "$S/verify.mjs" deep.js 2>&1); rc=$?
assert "verify works from a subdirectory" "[ $rc -eq 1 ]"
git checkout -q sub/deep.js

# Verify names files it has no syntax for instead of silently passing them.
printf 'all:\n\techo hi\n' > Makefile
cat > ok.js <<'EOF'
// note
const b = 1;
EOF
git add -A && git commit -q -m mk
printf 'all:\n\techo BYE\n' > Makefile
cat > ok.js <<'EOF'
const b = 1;
EOF
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify still passes the checkable file" "[ $rc -eq 0 ]"
assert_grep "verify names the unchecked file" "NOT checked.*Makefile" "$out"
git checkout -q Makefile ok.js

# Shell: `#` inside ${x#y} is not a comment.
cat > tool.sh <<'EOF'
#!/usr/bin/env bash
# strip the prefix
rel=${path#/opt/}
echo "$rel"
EOF
git add -A && git commit -q -m sh
cat > tool.sh <<'EOF'
#!/usr/bin/env bash
rel=${path#/usr/}
echo "$rel"
EOF
out=$(node "$S/verify.mjs" 2>&1); rc=$?
assert "verify catches a change inside a shell expansion" "[ $rc -eq 1 ]"
git checkout -q tool.sh

# --- scan: detectors --------------------------------------------------------

cat > fixture.ts <<'EOF'
// eslint-disable-next-line no-console
console.log("keep me");

// I've added a mutex here as you asked
const lock = new Mutex();

// Refactored this to use a Map instead of an array scan
const index = new Map();

// const old = users.filter(u => u.active);

// Trailing slash required; the CDN 404s without it.
const base = "https://cdn.example.com/";

// TODO(proj-ftp.3): wire this to the installer
function pending() {}

// Get user name
function getUserName() {}

function handle(req) {
  // This block takes the incoming request and then validates every single one
  // of the fields on it before it hands the whole thing off to the persistence
  // layer for storage in the database.
  persist(validate(req));
}

// Defaults (override before calling anything)
const timeout = 30;
EOF

out=$(node "$S/scan.mjs" --tracker-prefix proj fixture.ts 2>&1)
assert_grep "scan flags an agent reference" "agent-reference" "$out"
assert_grep "scan flags edit narration" "edit-history" "$out"
assert_grep "scan flags commented-out code" "commented-code" "$out"
assert_grep "scan flags a tracker id" "tracker-reference" "$out"
assert_grep "scan flags a name restatement" "restates-name" "$out"
assert_grep "scan flags a comment block" "comment-block" "$out"
assert_not_grep "scan leaves the eslint directive alone" "no-console" "$out"
assert_not_grep "scan leaves a real constraint alone" "CDN 404s" "$out"
assert_not_grep "scan reads prose with parentheses as prose" "commented-code" "$(node "$S/scan.mjs" clean.ts 2>&1; node "$S/scan.mjs" fixture.ts 2>&1 | grep Defaults)"

# A long comment documenting a declaration, or heading a file, is doing its job.
cat > documented.sh <<'EOF'
#!/usr/bin/env bash
# Renders collected rows as Markdown tables. One table per stream, the current
# checkout first, then a summary. Callers pass JSON on stdin, and an empty
# array renders the empty-state line rather than an empty table.

# Resolves a branch name to a usable git ref. Prints HEAD when the branch is
# the current checkout. Fails when the name resolves to nothing, because the
# caller can report that better than this function can.
resolve_ref() {
  echo "$1"
}

run() {
  # This inner block explains at length something that the reader could have
  # worked out from four lines of very ordinary shell code sitting right below
  # it, which is exactly the shape the rule is meant to catch.
  echo hello
}
EOF
out=$(node "$S/scan.mjs" documented.sh 2>&1)
assert_not_grep "scan exempts a file header" "Renders collected rows" "$out"
assert_not_grep "scan exempts a comment documenting a declaration" "Resolves a branch" "$out"
assert_grep "scan still flags a block inside a body" "comment-block" "$out"

# Rustdoc (///, //!) states a contract: rung 2, never an ordinary comment
# block. A //// divider is not documentation and stays subject to the rule.
cat > doc.rs <<'EOF'
/// Expands to the boilerplate impls, at some length across multiple
/// lines, so a detector that reads rustdoc as an ordinary comment
/// block would flag it even though it documents the macro below.
macro_rules! boilerplate {
    () => {};
}

/// Parses a config file into a Config. Returns an error when the file
/// is missing or malformed, because the caller decides whether a
/// default configuration is an acceptable substitute.
#[derive(Debug)]
pub struct ConfigParser {}

mod tests {
    //! Verifies the parser against the fixtures directory, spanning
    //! enough lines that the block detector would fire if inner docs
    //! were judged as ordinary commentary rather than documentation.
    use super::*;
}

fn after() {
    do_thing();
    //// --------------------
    //// A slash divider is not documentation and reads as an ordinary
    //// comment block when it rambles on for this many lines in a body.
    do_more();
}
EOF
out=$(node "$S/scan.mjs" doc.rs 2>&1)
assert_not_grep "scan exempts /// rustdoc above a macro" "boilerplate impls" "$out"
assert_not_grep "scan exempts /// rustdoc above an attribute" "Parses a config file" "$out"
assert_not_grep "scan exempts //! inner docs" "fixtures directory" "$out"
assert_grep "scan judges a //// divider as an ordinary comment" "slash divider" "$out"

cat > label.sh <<'EOF'
#!/usr/bin/env bash
list() {
  # changed files (whole range)
  git diff --name-only
}
EOF
out=$(node "$S/scan.mjs" label.sh 2>&1)
assert_not_grep "scan reads a noun-phrase label as a label" "edit-history" "$out"

out=$(node "$S/scan.mjs" --json --tracker-prefix proj fixture.ts 2>&1)
assert_grep "scan emits json" '"rule":' "$out"

node "$S/scan.mjs" --ci --tracker-prefix proj fixture.ts >/dev/null 2>&1
assert "scan --ci fails on a high-confidence hit" "[ $? -eq 1 ]"

cat > clean.ts <<'EOF'
// Lock: concurrent writers corrupt the cache.
const lock = new Mutex();
EOF
node "$S/scan.mjs" --ci clean.ts >/dev/null 2>&1
assert "scan --ci passes a clean file" "[ $? -eq 0 ]"

# A directive word buried in prose is prose; a directive is at the top.
cat > prose.ts <<'EOF'
// I've painted the button black as you asked
const btn = paint();

// width = height in square mode
const sq = resize();
EOF
out=$(node "$S/scan.mjs" prose.ts 2>&1)
assert_grep "scan flags an agent reference despite a formatter's name" "agent-reference" "$out"
assert_not_grep "scan reads a prose assignment as prose" "commented-code" "$out"

# A URL keeps a tracker id resolvable, so it is not a finding.
cat > linked.ts <<'EOF'
// Upstream panics on empty input: https://github.com/foo/bar/issues/123
const guard = true;
EOF
out=$(node "$S/scan.mjs" --tracker-prefix proj linked.ts 2>&1)
assert_not_grep "scan keeps a linked reference" "tracker-reference" "$out"

# --- scope ------------------------------------------------------------------

mkdir -p node_modules/pkg src
echo "// junk" > node_modules/pkg/index.js
echo "const a = 1;" > src/real.js
printf '// Code generated by tool. DO NOT EDIT.\nconst b = 2;\n' > src/gen.js
echo "binary" > src/data.bin

out=$(bash "$S/scope.sh" --all 2>&1)
assert_grep "scope includes a source file" "src/real.js" "$out"
assert_not_grep "scope excludes node_modules" "node_modules" "$out"
assert_not_grep "scope excludes generated files" "src/gen.js" "$out"
assert_not_grep "scope excludes unknown extensions" "data.bin" "$out"

out=$(bash "$S/scope.sh" src 2>&1)
assert_grep "scope accepts a directory" "src/real.js" "$out"

git add -A && git commit -q -m fixtures
echo "const c = 3;" >> src/real.js
out=$(bash "$S/scope.sh" 2>&1)
assert_grep "scope defaults to changed files" "src/real.js" "$out"
git checkout -q src/real.js

# --- branch scope -----------------------------------------------------------
#
# A branch must own the lines it changed and nothing else. The case that gets
# this wrong is a base that moved: diffing against the base ref instead of the
# fork point reads the base's later commits backwards, so a comment main
# deleted and the branch merely kept looks like the branch's work.

BR="$TMP/branchcase"
mkdir -p "$BR" && (
  cd "$BR" || exit 1
  git init -q -b main
  git config user.name "Selftest Bot"
  git config user.email "selftest@example.com"

  printf '// Loop through the users, as requested by Claude\nconst a = 1;\n' > kept.js
  printf 'const u = 1;\n' > untouched.js
  git add -A && git commit -q -m init

  git checkout -q -b feat
  # main cleans that comment up after the fork point
  git checkout -q main
  printf 'const a = 1;\n' > kept.js
  git add -A && git commit -q -m "main cleans"
  # the branch leaves it alone and adds its own work
  git checkout -q feat
  printf '// TODO(ACME-99): branch owns this\nconst n = 2;\n' > added.js
  git add -A && git commit -q -m "branch work"
  printf 'const w = 3; // I added this line for you\n' >> added.js
) || bad "branch fixture setup"

cd "$BR" || exit 1

out=$(bash "$S/scope.sh" --branch --base main 2>&1)
assert_grep "branch scope includes a file the branch added" "added.js" "$out"
assert_not_grep "branch scope excludes untouched files" "untouched.js" "$out"

base=$(bash "$S/scope.sh" --print-base --base main 2>&1)
assert "print-base resolves the fork point" "[ \"$base\" = \"$(git merge-base main HEAD)\" ]"

out=$(bash "$S/scope.sh" --branch --base main | tr '\n' '\0' \
  | xargs -0 -r node "$S/scan.mjs" --diff-only --base "$base" 2>&1)
assert_grep "branch scan finds the branch's own comment" "ACME-99" "$out"
assert_grep "branch scan finds uncommitted branch work" "I added this line" "$out"
assert_not_grep "branch scan ignores a comment only the base removed" "as requested by Claude" "$out"

# The same scan against the base ref is what the fork point exists to prevent.
# It only bites once the file re-enters scope with uncommitted work of its own,
# which is exactly the state below.
printf 'const later = 4;\n' >> kept.js
out=$(bash "$S/scope.sh" --branch --base main | tr '\n' '\0' \
  | xargs -0 -r node "$S/scan.mjs" --diff-only --base main 2>&1)
assert_grep "scanning from the base ref misattributes it (why --print-base exists)" \
  "as requested by Claude" "$out"
out=$(bash "$S/scope.sh" --branch --base main | tr '\n' '\0' \
  | xargs -0 -r node "$S/scan.mjs" --diff-only --base "$base" 2>&1)
assert_not_grep "the fork point does not misattribute it" "as requested by Claude" "$out"
git checkout -q kept.js

# A pushed branch tracks origin/<itself>. Taking that as the base would resolve
# to HEAD and quietly shrink a branch scope to the uncommitted files only.
git init -q --bare "$TMP/branch-remote.git"
git remote add origin "$TMP/branch-remote.git"
git push -q origin main 2>/dev/null
git push -q -u origin feat 2>/dev/null
up=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
assert "the branch tracks its own counterpart" "[ \"$up\" = 'origin/feat' ]"
pushed_base=$(bash "$S/scope.sh" --print-base 2>&1)
assert "a pushed branch does not take itself as its base" \
  "[ \"$pushed_base\" = \"$(git merge-base main HEAD)\" ]"
out=$(bash "$S/scope.sh" --branch 2>&1)
assert_grep "branch scope survives being pushed" "added.js" "$out"

# An upstream naming a different branch is a deliberate base and is kept.
git branch -q --set-upstream-to=origin/main feat 2>/dev/null
assert "an upstream on another branch is honoured" \
  "[ \"$(bash "$S/scope.sh" --print-base 2>&1)\" = \"$(git merge-base origin/main HEAD)\" ]"

# Standing on the default branch with unpushed commits. Skipping the
# self-tracking upstream must not fall through to the LOCAL main, which is HEAD
# — that collapses the scope just as silently. origin/HEAD is unset here, which
# is the state of every repo made by git init + git remote add.
git checkout -q main
git push -q -u origin main 2>/dev/null
printf '// I refactored this per your request - Claude\nconst d = 1;\n' > ondefault.js
git add -A && git commit -q -m "unpushed work on main"
assert "origin/HEAD is unset for this case" \
  "! git symbolic-ref --quiet refs/remotes/origin/HEAD >/dev/null 2>&1"
def_base=$(bash "$S/scope.sh" --print-base 2>&1)
assert "the default branch does not take itself as its base" \
  "[ \"$def_base\" != \"$(git rev-parse HEAD)\" ]"
assert "the default branch falls through to its remote counterpart" \
  "[ \"$def_base\" = \"$(git merge-base origin/main HEAD)\" ]"
out=$(bash "$S/scope.sh" --branch 2>&1)
assert_grep "unpushed work on the default branch is in scope" "ondefault.js" "$out"
git checkout -q feat

cd "$TMP" || exit 1

# --- install-guidance -------------------------------------------------------

printf '# Agent Instructions\n\nBe careful.\n' > CLAUDE.md
out=$(bash "$S/install-guidance.sh" 2>&1)
assert_grep "install dry-runs by default" "would append" "$out"
assert_not_grep "install writes nothing on a dry run" "BEGIN clean-comments" "$(cat CLAUDE.md)"

out=$(bash "$S/install-guidance.sh" --write 2>&1)
assert_grep "install appends the block" "appended" "$out"
assert_grep "install wrote the marker" "BEGIN clean-comments" "$(cat CLAUDE.md)"
assert_grep "install wrote the rules" "Say why, not what" "$(cat CLAUDE.md)"
assert_grep "install kept the existing content" "Be careful" "$(cat CLAUDE.md)"

out=$(bash "$S/install-guidance.sh" --write 2>&1)
assert_grep "install is idempotent" "already current" "$out"
count=$(grep -c "BEGIN clean-comments" CLAUDE.md)
assert "install did not duplicate the block" "[ $count -eq 1 ]"

printf 'changed\n' >> CLAUDE.md
sed -i.bak 's/Say why, not what./Say why./' CLAUDE.md && rm -f CLAUDE.md.bak
out=$(bash "$S/install-guidance.sh" --write 2>&1)
assert_grep "install updates a stale block" "updated" "$out"
assert_grep "install restored the text" "Say why, not what" "$(cat CLAUDE.md)"
assert_grep "install kept trailing content" "changed" "$(cat CLAUDE.md)"

out=$(bash "$S/install-guidance.sh" --list 2>&1)
assert_grep "install lists targets" "CLAUDE.md" "$out"

# --- doc snippets parse -----------------------------------------------------
#
# The CI recipe and the pre-push hook are pasted whole by readers and are
# exercised by nothing else, so a quoting slip in them fails at the reader's
# shell rather than here.

if out=$(cd "$CORE_DIR" && python3 tests/check-doc-snippets.py 2>&1); then
  ok "every doc snippet parses"
else
  bad "a doc snippet does not parse"
  printf '%s\n' "$out"
fi

# --- results ----------------------------------------------------------------

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
