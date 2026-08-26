#!/usr/bin/env bash
# decision-trail: migrate a repo that still carries the pre-rename .logic/ runtime.
#
# The skill was called "logic" until it was renamed to "decision-trail". Repos
# that enabled it before the rename have a committed .logic/ tree, a
# core.hooksPath pointing into it, and bd rows labeled logic:<slug>. This moves
# all of that to the new names. It does not regenerate the runtime — the caller
# (install-hooks.sh) does that immediately afterwards.
#
# Usage: migrate-legacy.sh [--check|--relabel]
#   --check     report whether a legacy runtime is present; change nothing
#   --relabel   rewrite stale bd labels only, leaving the directory alone.
#               Exits non-zero unless the trail is provably clean afterwards.
#               This is the recovery path once the directory has moved: the
#               full migration exits early then, so on its own it could never
#               finish a relabel that a short listing or a failed `bd update`
#               had left partial.
#
# Exits 0 when there is nothing to migrate, so it is safe to call every time.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib.sh"

mode="migrate"
case "${1:-}" in
  "")        ;;
  --check)   mode="check" ;;
  --relabel) mode="relabel" ;;
  *) echo "decision-trail: unknown option '$1' (expected --check or --relabel)" >&2; exit 2 ;;
esac

ROOT="$(dt_repo_root)" || { echo "decision-trail: not inside a git repo" >&2; exit 1; }
[ -n "$ROOT" ] || { echo "decision-trail: not inside a git repo" >&2; exit 1; }
LEGACY="$ROOT/.logic"
NEW="$ROOT/.decision-trail"

# --- stale bd labels -------------------------------------------------------
#
# Rows written before the rename carry logic:<slug> / logic-stub. The renamed
# collector queries decision-trail:<slug> and nothing else, so every label left
# behind is a decision that has silently dropped out of the trail. That is the
# worst failure this tool has, so the code below is written to be loud about
# partial work rather than to report a tidy count.

relabelled=0; relabel_failed=0; relabel_left=0; relabel_unverified=0; relabel_notes=""

add_note() { relabel_notes="${relabel_notes}${relabel_notes:+
}$1"; }

# Does the config ask for the beads backend anywhere? If not, there are no bd
# rows to lose: a TSV trail's rows moved with the directory.
wants_beads() {
  [ "$(dt_config_get '.storage' 'beads')" = "beads" ] && return 0
  [ -n "$(dt_config_get '([(.storageOverrides // {}) | to_entries[] | .value] | index("beads"))' '')" ]
}

# "<id>\t<label>" on stdout for every listed row still carrying a legacy label.
legacy_labelled() {
  jq -r '.[]? | . as $i | (($i.labels // [])[]
    | select(startswith("logic:") or . == "logic-stub")
    | "\($i.id)\t\(.)")' 2>/dev/null
}

relabel_bd_rows() {
  relabelled=0; relabel_failed=0; relabel_left=0; relabel_unverified=0

  if ! dt_bd_ok || ! dt_have jq; then
    if wants_beads; then
      relabel_unverified=1
      add_note "this trail uses the beads backend, but bd or jq is unavailable or too old here, so no bd labels were rewritten. Those rows keep their logic:* labels and the trail will not show them. Re-run 'migrate-legacy.sh --relabel' somewhere bd works."
    fi
    return 0
  fi

  # bd list caps its results at 50 by default ("-n, --limit int ... use 0 for
  # unlimited"), and --all lifts only the closed-issue filter, not the cap.
  # Without --limit 0 a trail with more beads than that relabels a prefix and
  # reports success. Probe the flag rather than assuming it, so that adding it
  # cannot turn an older bd's partial migration into no migration at all.
  local -a list_args=(--all --json --limit 0)
  if ! bd list "${list_args[@]}" >/dev/null 2>&1; then
    list_args=(--all --json --limit 1000000)
  fi
  if ! bd list "${list_args[@]}" >/dev/null 2>&1; then
    # No way to lift the cap. Relabel what this bd will show and say plainly
    # that the result cannot be verified — the re-query below reads the same
    # capped window, so once its rows are clean it would report "none left"
    # whether or not any exist beyond it. Claiming success there is the exact
    # silent loss this whole function exists to prevent.
    list_args=(--all --json)
    relabel_unverified=1
    add_note "this bd rejects 'bd list --limit', so the row listing is capped at its default (50) and completeness cannot be checked. Rows beyond the cap keep their logic:* labels and stay out of the trail. Upgrade bd until 'bd list --limit 0' works, then re-run 'migrate-legacy.sh --relabel'."
  fi

  local id old_label new_label
  while IFS=$'\t' read -r id old_label; do
    [ -n "$id" ] || continue
    new_label="decision-trail:${old_label#logic:}"
    [ "$old_label" = "logic-stub" ] && new_label="decision-trail-stub"
    if bd update "$id" --add-label "$new_label" --remove-label "$old_label" >/dev/null 2>&1; then
      relabelled=$((relabelled + 1))
    else
      relabel_failed=$((relabel_failed + 1))
    fi
  done <<EOF
$(bd list "${list_args[@]}" 2>/dev/null | legacy_labelled)
EOF

  # Re-query rather than trust the tally above. A `bd update` that failed, or a
  # listing that came back short, must not be able to look like a clean run.
  relabel_left=$(bd list "${list_args[@]}" 2>/dev/null | legacy_labelled | grep -c .)
  [ -n "$relabel_left" ] || relabel_left=0
  if [ "$relabel_left" -gt 0 ]; then
    add_note "${relabel_left} bd row(s) still carry a logic:* label after the rewrite (${relabel_failed} update(s) failed). The collector does not query those labels, so those decisions are missing from the trail. Re-run 'migrate-legacy.sh --relabel'."
  fi
}

# Warnings go to stdout for whoever ran this, and to WARNINGS for whoever reads
# the trail later and wonders where the rows went.
emit_notes() {
  [ -n "$relabel_notes" ] || return 0
  local n
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    printf '  WARNING: %s\n' "$n"
    dt_record_note "decision-trail: $n"
  done <<EOF
$relabel_notes
EOF
}

relabel_summary() {
  local left="${relabel_left} still legacy"
  [ "$relabel_unverified" -eq 1 ] && left="unknown how many are left — see the warning below"
  printf '  bd labels rewritten on %s row(s); %s update(s) failed, %s\n' \
    "$relabelled" "$relabel_failed" "$left"
}

# --- --relabel: bd rows only ----------------------------------------------
if [ "$mode" = "relabel" ]; then
  if [ ! -f "$(dt_config_path)" ]; then
    echo "decision-trail: no runtime in this repo — nothing to relabel." >&2
    exit 1
  fi
  relabel_bd_rows
  echo "decision-trail: relabelled pre-rename bd rows."
  relabel_summary
  emit_notes
  # Non-zero unless the trail is provably clean: "I could not check" is not
  # the same answer as "nothing is left", and a caller must not read it as one.
  [ "$relabel_left" -eq 0 ] && [ "$relabel_unverified" -eq 0 ]
  exit $?
fi

# --- detect ----------------------------------------------------------------
# A bare directory is not a runtime; config.json is what makes it one.
if [ ! -f "$LEGACY/config.json" ]; then
  [ "$mode" = "check" ] && exit 1
  exit 0
fi

if [ "$mode" = "check" ]; then
  echo "legacy"
  exit 0
fi

# Both present means someone has already migrated, or started to. Merging two
# trails is a judgement call about which config wins, so refuse and say so.
if [ -e "$NEW" ]; then
  cat >&2 <<MSG
decision-trail: both .logic/ and .decision-trail/ exist. Refusing to guess.
  .logic/ is the pre-rename runtime; .decision-trail/ is the current one.
  Keep the trail you want, delete the other, then re-run. The rows are in
  .logic/audit/ and .decision-trail/audit/ (or in bd, if that is the backend).
MSG
  exit 1
fi

mv "$LEGACY" "$NEW" || { echo "decision-trail: could not move .logic/ to .decision-trail/" >&2; exit 1; }

# The old engine and its callers are dead names; install-hooks.sh writes the
# new ones next. Leaving these behind would give hooks two engines to source.
rm -f "$NEW/runtime/logic.sh"

# Point the hook path at the new tree, but only if it pointed at the old one.
# A foreign hooksPath is the user's, and install-hooks.sh warns about it.
current_hp="$(git -C "$ROOT" config --local --get core.hooksPath 2>/dev/null || true)"
if [ "$current_hp" = ".logic/githooks" ]; then
  git -C "$ROOT" config core.hooksPath .decision-trail/githooks
  hp_note="core.hooksPath moved to .decision-trail/githooks"
else
  hp_note="core.hooksPath left as '${current_hp:-unset}' — not ours to move"
fi

# Relabel bd rows. The TSV fallback needs nothing: those files moved with the
# directory. Stale labels are not fatal to the move — the directory is already
# in its new home and install-hooks.sh must still finish — so this reports
# rather than aborts, and --relabel finishes the job afterwards.
relabel_bd_rows

dt_record_note "decision-trail: migrated this repo's .logic/ runtime to .decision-trail/. Commit the move so hooks and config travel with the branch."

cat <<MSG
decision-trail: migrated the pre-rename runtime.
  .logic/ -> .decision-trail/
  ${hp_note}
MSG
relabel_summary
emit_notes
cat <<MSG

Commit the move, or hooks break for everyone else on this branch:
  git add -A .logic .decision-trail && git commit -m "chore: rename logic runtime to decision-trail"
MSG
