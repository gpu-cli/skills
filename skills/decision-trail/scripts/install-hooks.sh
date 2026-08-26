#!/usr/bin/env bash
# decision-trail: materialize the committed .decision-trail/ runtime and wire git hooks.
#
# Copies the engine, the git post-commit hook, and the Claude Code hook scripts
# into .decision-trail/ (committed, so they survive git worktrees where the skill itself
# is absent), sets core.hooksPath, and prints the Claude Code settings snippet.
# Idempotent: safe to re-run to refresh the runtime after a skill update.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(dirname "$SCRIPT_DIR")"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib.sh"

ROOT="$(dt_repo_root)" || { echo "decision-trail: not inside a git repo" >&2; exit 1; }

# A repo enabled before the rename carries .logic/. Move it first, so the
# materialization below refreshes the migrated tree instead of creating a
# second one beside it.
"$SCRIPT_DIR/migrate-legacy.sh" || exit 1

LDIR="$ROOT/.decision-trail"

mkdir -p "$LDIR/runtime" "$LDIR/githooks" "$LDIR/hooks" "$LDIR/audit"

# 1. config.json (create default if missing; never clobber existing config)
if [ ! -f "$LDIR/config.json" ]; then
  "$SCRIPT_DIR/config-edit.sh" init >/dev/null
fi

# 2. engine + hooks (always refreshed from the skill source)
cp -f "$SCRIPT_DIR/lib.sh"              "$LDIR/runtime/decision-trail.sh"
cp -f "$CORE_DIR/githooks/post-commit" "$LDIR/githooks/post-commit"
cp -f "$CORE_DIR/hooks/session-start.sh" "$LDIR/hooks/session-start.sh"
cp -f "$CORE_DIR/hooks/stop-gate.sh"     "$LDIR/hooks/stop-gate.sh"
chmod +x "$LDIR/githooks/post-commit" "$LDIR/hooks/"*.sh 2>/dev/null

# 3. .decision-trail/.gitignore — commit config + runtime + hooks; keep local TSV out of git
cat >"$LDIR/.gitignore" <<'GI'
# TSV fallback logs are local by default; commit intentionally if you want a
# shared trail visible in the PR.
audit/
# Machine-local: probed bd capability cache and one-shot warning spool.
.bd-capability
WARNINGS
GI

# 4. wire core.hooksPath (do not clobber a pre-existing, foreign hooksPath)
current_hp="$(git -C "$ROOT" config --local --get core.hooksPath 2>/dev/null || true)"
if [ -z "$current_hp" ] || [ "$current_hp" = ".decision-trail/githooks" ]; then
  git -C "$ROOT" config core.hooksPath .decision-trail/githooks
  hp_status="core.hooksPath set to .decision-trail/githooks"
else
  hp_status="WARNING: core.hooksPath is already '$current_hp'. Not overwriting. Add this line to that hook's post-commit so capture still runs:
    \"\$(git rev-parse --show-toplevel)/.decision-trail/githooks/post-commit\""
fi

# 5. backend availability — probe the actual API, not just the binary's presence
cap="$(dt_bd_capability)"
case "$cap" in
  ok)
    backend="beads — $(command -v bd)" ;;
  missing)
    backend="TSV fallback — bd is not on PATH; rows go to .decision-trail/audit/" ;;
  *)
    backend="TSV fallback — the bd on PATH ($(command -v bd 2>/dev/null)) lacks the API this suite needs (bd query, --metadata, decision type).
    If bd works in your interactive shell, you likely have more than one install and a login shell — which is what git hooks get — resolves the older one." ;;
esac

cat <<EOF
decision-trail runtime installed under .decision-trail/
  - runtime/decision-trail.sh   (engine)
  - githooks/post-commit
  - hooks/session-start.sh, hooks/stop-gate.sh
  - config.json
  ${hp_status}
  backend: ${backend}

Commit .decision-trail/ so hooks and config travel with the branch (and into worktrees):
  git add .decision-trail && git commit -m "chore: enable decision-trail tracking"

Optional Layer-2 enrichment gate — add to .claude/settings.json:
{
  "hooks": {
    "SessionStart": [ { "hooks": [ { "type": "command", "command": "bash .decision-trail/hooks/session-start.sh" } ] } ],
    "Stop":         [ { "hooks": [ { "type": "command", "command": "bash .decision-trail/hooks/stop-gate.sh"     } ] } ]
  }
}
EOF
