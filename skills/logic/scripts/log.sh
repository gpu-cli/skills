#!/usr/bin/env bash
# logic: log or enrich a decision row.
#
# Log a new row (used by /logic track and by agents at decision points):
#   log.sh --decision "..." [--why "..."] [--phase "..."] [--evidence "..."] \
#          [--result "..."] [--confidence high|medium|low|unknown] \
#          [--actor "..."] [--kind manual|agent] [--sha <sha>]
#   log.sh "<decision text>"          # positional; " because " splits decision/why
#
# Enrich an existing stub with its why (used at the enrichment gate):
#   log.sh --enrich <bead-id|sha> --why "..." [--result "..."] [--confidence ...]
#
# Prints the row id (bead id or tsv path) it wrote, or the enriched id.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib.sh"

decision="" why="" phase="" evidence="" result="" confidence="unknown" actor="" kind="manual" sha="" enrich=""
while [ $# -gt 0 ]; do
  case "$1" in
    --decision) decision="$2"; shift 2 ;;
    --why) why="$2"; shift 2 ;;
    --phase) phase="$2"; shift 2 ;;
    --evidence) evidence="$2"; shift 2 ;;
    --result) result="$2"; shift 2 ;;
    --confidence) confidence="$2"; shift 2 ;;
    --actor) actor="$2"; shift 2 ;;
    --kind) kind="$2"; shift 2 ;;
    --sha) sha="$2"; shift 2 ;;
    --enrich) enrich="$2"; shift 2 ;;
    --*) echo "unknown flag: $1" >&2; exit 1 ;;
    *) decision="$1"; shift ;;
  esac
done

case "$confidence" in
  high|medium|low|unknown) ;;
  *) echo "logic: invalid confidence '$confidence' (use high, medium, low, or unknown)" >&2; exit 1 ;;
esac

[ -z "$actor" ] && actor="$(logic_actor)"

# Refuse to log when tracking is off, unless explicitly forced. This keeps
# stray rows out of untracked branches.
read -r state logical _storage <<EOF
$(logic_effective_state)
EOF
if [ "$state" != "on" ] && [ -z "${LOGIC_FORCE:-}" ]; then
  echo "logic: tracking is OFF for this branch; not logging. Enable with /logic toggle on (or set LOGIC_FORCE=1)." >&2
  exit 2
fi

# Enrichment path.
if [ -n "$enrich" ]; then
  [ -z "$why" ] && { echo "logic: --enrich requires --why" >&2; exit 1; }
  logic_warn_stderr
  # logic_enrich accepts a bead id or a SHA and handles both backends: beads
  # updates in place, TSV appends a superseding row.
  out=$(logic_enrich "$enrich" "$why" "$result" "$confidence") || {
    echo "logic: could not enrich '$enrich' — no matching row found on branch '$logical'." >&2
    exit 1
  }
  printf 'enriched %s\n' "$enrich"
  printf '  why=%s\n' "$why"
  printf '  confidence=%s\n' "$confidence"
  [ -n "$out" ] && printf '  record=%s\n' "$out"
  exit 0
fi

# Positional "X because Y" convenience split.
if [ -n "$decision" ] && [ -z "$why" ]; then
  case "$decision" in
    *" because "*)
      why="${decision#* because }"
      decision="${decision% because *}"
      ;;
  esac
fi

[ -z "$decision" ] && { echo "logic: nothing to log (need --decision or a positional decision)" >&2; exit 1; }
[ "$kind" = "manual" ] && [ -z "$actor" ] && actor="user"

id=$(logic_log_row "$kind" "$actor" "$phase" "$decision" "$why" "$evidence" "$result" "$sha" "$confidence")
rc=$?
if [ $rc -eq 0 ] && [ -n "$id" ]; then
  printf 'logged %s\n' "$id"
  printf '  actor=%s branch=%s confidence=%s decision=%s\n' "$actor" "$logical" "$confidence" "$decision"
  [ -n "$why" ] && printf '  why=%s\n' "$why"
else
  echo "logic: failed to log row" >&2; exit 1
fi
