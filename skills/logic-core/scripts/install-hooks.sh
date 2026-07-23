#!/usr/bin/env bash
# logic-core: materialize the committed .logic/ runtime and wire git hooks.
#
# Copies the engine, the git post-commit hook, and the Claude Code hook scripts
# into .logic/ (committed, so they survive git worktrees where the skill itself
# is absent), sets core.hooksPath, and prints the Claude Code settings snippet.
# Idempotent: safe to re-run to refresh the runtime after a skill update.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(dirname "$SCRIPT_DIR")"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib.sh"

ROOT="$(logic_repo_root)" || { echo "logic: not inside a git repo" >&2; exit 1; }
LDIR="$ROOT/.logic"

mkdir -p "$LDIR/runtime" "$LDIR/githooks" "$LDIR/hooks" "$LDIR/audit"

# 1. config.json (create default if missing; never clobber existing config)
if [ ! -f "$LDIR/config.json" ]; then
  "$SCRIPT_DIR/config-edit.sh" init >/dev/null
fi

# 2. engine + hooks (always refreshed from the skill source)
cp -f "$SCRIPT_DIR/lib.sh"              "$LDIR/runtime/logic.sh"
cp -f "$CORE_DIR/githooks/post-commit" "$LDIR/githooks/post-commit"
cp -f "$CORE_DIR/hooks/session-start.sh" "$LDIR/hooks/session-start.sh"
cp -f "$CORE_DIR/hooks/stop-gate.sh"     "$LDIR/hooks/stop-gate.sh"
chmod +x "$LDIR/githooks/post-commit" "$LDIR/hooks/"*.sh 2>/dev/null

# 3. .logic/.gitignore — commit config + runtime + hooks; keep local TSV out of git
cat >"$LDIR/.gitignore" <<'GI'
# TSV fallback logs are local by default; commit intentionally if you want a
# shared trail visible in the PR.
audit/
GI

# 4. wire core.hooksPath (do not clobber a pre-existing, foreign hooksPath)
current_hp="$(git -C "$ROOT" config --local --get core.hooksPath 2>/dev/null || true)"
if [ -z "$current_hp" ] || [ "$current_hp" = ".logic/githooks" ]; then
  git -C "$ROOT" config core.hooksPath .logic/githooks
  hp_status="core.hooksPath set to .logic/githooks"
else
  hp_status="WARNING: core.hooksPath is already '$current_hp'. Not overwriting. Add this line to that hook's post-commit so capture still runs:
    \"\$(git rev-parse --show-toplevel)/.logic/githooks/post-commit\""
fi

# 5. backend availability
if command -v bd >/dev/null 2>&1; then
  backend="beads (bd found)"
else
  backend="TSV fallback (bd not on PATH — rows go to .logic/audit/)"
fi

cat <<EOF
logic runtime installed under .logic/
  - runtime/logic.sh   (engine)
  - githooks/post-commit
  - hooks/session-start.sh, hooks/stop-gate.sh
  - config.json
  ${hp_status}
  backend: ${backend}

Commit .logic/ so hooks and config travel with the branch (and into worktrees):
  git add .logic && git commit -m "chore: enable decision-trail tracking"

Optional Layer-2 enrichment gate — add to .claude/settings.json:
{
  "hooks": {
    "SessionStart": [ { "hooks": [ { "type": "command", "command": "bash .logic/hooks/session-start.sh" } ] } ],
    "Stop":         [ { "hooks": [ { "type": "command", "command": "bash .logic/hooks/stop-gate.sh"     } ] } ]
  }
}
EOF
