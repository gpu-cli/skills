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

# --- results ----------------------------------------------------------------

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
