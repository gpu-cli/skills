#!/usr/bin/env bash
# logic engine library.
#
# Sourced by every logic helper (interactive skill scripts) and, in its
# materialized form at .logic/runtime/logic.sh, by the git post-commit hook and
# the Claude Code session hooks. It must stay self-contained: no dependency on
# any other file in the skill, so the materialized copy works standalone inside
# a git worktree where the skill itself is absent.
#
# Requires: git. Uses jq and bd when available; degrades to a TSV backend
# otherwise. Sourcing this file has no side effects — it only defines functions.

# --- basics ---------------------------------------------------------------

logic_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null
}

logic_dir() {
  local root; root=$(logic_repo_root) || return 1
  [ -z "$root" ] && return 1
  printf '%s/.logic' "$root"
}

logic_config_path() {
  printf '%s/config.json' "$(logic_dir)"
}

logic_have() { command -v "$1" >/dev/null 2>&1; }

logic_current_branch() {
  # Branch name, or short SHA when detached.
  local b
  b=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) && { printf '%s' "$b"; return; }
  git rev-parse --short HEAD 2>/dev/null
}

logic_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Lowercase, collapse everything that is not [a-z0-9._-] to a single dash.
logic_slug() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//'
}

logic_actor() {
  if [ -n "${LOGIC_ACTOR:-}" ]; then printf '%s' "$LOGIC_ACTOR"; return; fi
  if [ -n "${BEADS_ACTOR:-}" ]; then printf '%s' "$BEADS_ACTOR"; return; fi
  local n; n=$(git config user.name 2>/dev/null)
  if [ -n "$n" ]; then printf '%s' "$n"; return; fi
  printf 'unknown'
}

# --- git ref helpers ------------------------------------------------------

# The repo's mainline ref, for range and merged-ness questions.
logic_default_base() {
  local r
  for r in origin/main main origin/master master; do
    if git rev-parse --verify -q "$r" >/dev/null 2>&1; then printf '%s' "$r"; return 0; fi
  done
  return 1
}

# Resolve a branch name to a usable git ref. Prints HEAD when the branch is the
# current checkout (or unspecified). Fails when the name resolves to nothing —
# callers must not silently fall back to HEAD, or they audit the wrong branch.
logic_resolve_ref() {
  local b="${1:-}"
  if [ -z "$b" ] || [ "$b" = "$(logic_current_branch)" ]; then printf 'HEAD'; return 0; fi
  if git rev-parse --verify -q "refs/heads/$b" >/dev/null 2>&1; then printf '%s' "$b"; return 0; fi
  if git rev-parse --verify -q "refs/remotes/origin/$b" >/dev/null 2>&1; then printf 'origin/%s' "$b"; return 0; fi
  if git rev-parse --verify -q "$b" >/dev/null 2>&1; then printf '%s' "$b"; return 0; fi
  return 1
}

# --- bd capability --------------------------------------------------------

# More than one bd can be installed, and a login shell (which is what git hooks
# and GUI-launched tools get) may resolve a different binary than an interactive
# shell. Older builds have no `bd query`, no `--metadata`, and no `decision`
# type, so writes would fail silently. Probe once and cache per binary+version.
# Prints: ok | incompatible | missing
logic_bd_capability() {
  logic_have bd || { printf 'missing'; return 0; }
  local dir cache key ver ck cv verdict
  dir="$(logic_dir 2>/dev/null)"
  ver="$(bd --version 2>/dev/null | head -1)"
  [ -z "$ver" ] && ver="$(bd version 2>/dev/null | head -1)"
  key="$(command -v bd)|${ver}"
  if [ -n "$dir" ] && [ -f "${dir}/.bd-capability" ]; then
    cache="${dir}/.bd-capability"
    ck=$(sed -n '1p' "$cache" 2>/dev/null)
    cv=$(sed -n '2p' "$cache" 2>/dev/null)
    if [ "$ck" = "$key" ] && [ -n "$cv" ]; then printf '%s' "$cv"; return 0; fi
  fi
  verdict="ok"
  bd query --help >/dev/null 2>&1 || verdict="incompatible"
  if [ "$verdict" = "ok" ]; then
    bd create --help 2>&1 | grep -q -- '--metadata' || verdict="incompatible"
  fi
  if [ "$verdict" = "ok" ]; then
    bd create --help 2>&1 | grep -q 'decision' || verdict="incompatible"
  fi
  if [ -n "$dir" ]; then
    mkdir -p "$dir" 2>/dev/null
    printf '%s\n%s\n' "$key" "$verdict" >"${dir}/.bd-capability" 2>/dev/null
  fi
  printf '%s' "$verdict"
}

logic_bd_ok() { [ "$(logic_bd_capability)" = "ok" ]; }

# --- config ---------------------------------------------------------------

# Read config.json; prints "{}" if missing or jq unavailable.
logic_config_raw() {
  local p; p=$(logic_config_path)
  if [ -f "$p" ] && logic_have jq; then cat "$p"; else printf '{}'; fi
}

logic_config_get() {
  # logic_config_get <jq-filter> [default]
  local filter="$1" def="${2:-}"
  if ! logic_have jq; then printf '%s' "$def"; return; fi
  local v; v=$(logic_config_raw | jq -r "$filter // empty" 2>/dev/null)
  if [ -z "$v" ]; then printf '%s' "$def"; else printf '%s' "$v"; fi
}

# Glob match: does branch $1 match config key pattern $2 (supports * and ?).
logic_glob_match() {
  # shellcheck disable=SC2254 # Config keys intentionally act as glob patterns.
  case "$1" in
    $2) return 0 ;;
    *) return 1 ;;
  esac
}

# The backend the config asks for (before any capability downgrade).
logic_configured_storage() {
  local logical="${1:-}" s
  s=$(logic_config_get ".storageOverrides[\"$logical\"]" "")
  [ -z "$s" ] && s=$(logic_config_get '.storage' 'beads')
  printf '%s' "$s"
}

# Resolve tracking for the current checkout.
# Prints three space-separated fields: STATE LOGICAL_BRANCH STORAGE
#   STATE          on | off
#   LOGICAL_BRANCH the branch rows are scoped to (the matched config key, or HEAD's branch)
#   STORAGE        beads | tsv  (effective, after capability downgrade)
# Precedence: exact branch key > glob key > enabled unmerged ancestor > default.
logic_effective_state() {
  local branch; branch=$(logic_current_branch)
  local default storage state logical
  default=$(logic_config_get '.default' 'off')
  storage=$(logic_config_get '.storage' 'beads')
  state="$default"; logical="$branch"

  if logic_have jq && [ -f "$(logic_config_path)" ]; then
    local raw; raw=$(logic_config_raw)
    # 1. exact match
    local exact; exact=$(printf '%s' "$raw" | jq -r --arg b "$branch" '.branches[$b] // empty' 2>/dev/null)
    if [ -n "$exact" ]; then
      state="$exact"; logical="$branch"
    else
      # 2. glob match over branch keys
      local matched="" key val
      while IFS=$'\t' read -r key val; do
        [ -z "$key" ] && continue
        if logic_glob_match "$branch" "$key"; then matched="$key"; state="$val"; logical="$key"; break; fi
      done < <(printf '%s' "$raw" | jq -r '.branches // {} | to_entries[] | "\(.key)\t\(.value)"' 2>/dev/null)
      # 3. enabled ancestor — a derived worktree branch forked from an enabled
      #    branch. A branch already merged into the mainline is history, not a
      #    live parent: inheriting from it would silently capture every later
      #    main commit under the old feature's trail.
      if [ -z "$matched" ]; then
        local anc dbase
        dbase="$(logic_default_base 2>/dev/null)"
        while IFS= read -r anc; do
          [ -z "$anc" ] && continue
          case "$anc" in *'*'*|*'?'*) continue ;; esac
          git rev-parse --verify --quiet "$anc" >/dev/null 2>&1 || continue
          if [ -n "$dbase" ] && git merge-base --is-ancestor "$anc" "$dbase" 2>/dev/null; then continue; fi
          if git merge-base --is-ancestor "$anc" HEAD 2>/dev/null; then
            state="on"; logical="$anc"; break
          fi
        done < <(printf '%s' "$raw" | jq -r '.branches // {} | to_entries[] | select(.value=="on") | .key' 2>/dev/null)
      fi
    fi
    # storage override keyed on the logical branch
    local ov; ov=$(printf '%s' "$raw" | jq -r --arg b "$logical" '.storageOverrides[$b] // empty' 2>/dev/null)
    [ -n "$ov" ] && storage="$ov"
  fi

  # beads falls back to tsv when bd is absent OR too old for the API we use
  if [ "$storage" = "beads" ] && ! logic_bd_ok; then storage="tsv"; fi
  printf '%s %s %s' "$state" "$logical" "$storage"
}

logic_is_tracked() {
  local s; s=$(logic_effective_state); [ "${s%% *}" = "on" ]
}

# --- warnings -------------------------------------------------------------
# A silent backend downgrade is the failure mode we most need to avoid, so a
# downgrade always leaves a trace: stderr for interactive callers, and a
# deduped .logic/WARNINGS file for hooks (surfaced by the SessionStart hook).

# Prints the reason the beads backend is unusable; returns 1 when it is fine.
logic_backend_note() {
  local cap; cap="$(logic_bd_capability)"
  case "$cap" in
    ok) return 1 ;;
    missing)
      printf 'logic: bd is not on PATH — decision rows are going to the TSV fallback at .logic/audit/.' ;;
    *)
      printf 'logic: the bd on PATH (%s) lacks the API this suite needs (bd query, --metadata, decision type) — rows are going to the TSV fallback at .logic/audit/. If bd works in your interactive shell, you likely have more than one install and a login shell resolves a different one.' \
        "$(command -v bd 2>/dev/null)" ;;
  esac
  return 0
}

# 0 when the config asked for beads but we are effectively on tsv.
logic_downgraded() {
  local es logical storage
  es=$(logic_effective_state)
  logical=$(printf '%s' "$es" | awk '{print $2}')
  storage=$(printf '%s' "$es" | awk '{print $3}')
  [ "$storage" = "tsv" ] || return 1
  [ "$(logic_configured_storage "$logical")" = "beads" ]
}

# Append a note to .logic/WARNINGS, deduped. Safe inside hooks.
logic_record_note() {
  local t="${1:-}" d f
  [ -z "$t" ] && return 0
  d="$(logic_dir 2>/dev/null)" || return 0
  [ -z "$d" ] && return 0
  mkdir -p "$d" 2>/dev/null
  f="$d/WARNINGS"
  if [ -f "$f" ] && grep -qF "$t" "$f" 2>/dev/null; then return 0; fi
  printf '%s\n' "$t" >>"$f" 2>/dev/null
  return 0
}

logic_record_warning() {
  logic_downgraded || return 0
  logic_record_note "$(logic_backend_note)"
}

# Interactive one-shot warning to stderr.
logic_warn_stderr() {
  logic_downgraded || return 0
  local t; t="$(logic_backend_note)"
  [ -n "$t" ] && printf '%s\n' "$t" >&2
  return 0
}

# --- cell hygiene ---------------------------------------------------------

# Strip tabs/newlines and guard spreadsheet formula-injection bytes.
logic_sanitize_cell() {
  local v="$1"
  v=$(printf '%s' "$v" | tr '\t\n\r' '   ')
  case "$v" in
    [=+@-]*) v="'$v" ;;
  esac
  printf '%s' "$v"
}

# --- logging a row --------------------------------------------------------

LOGIC_TSV_HEADER='ts	actor	phase	decision	why	evidence	result	kind	sha	worktree	confidence'

# Coarse by design: confidence is the actor's assessment, not a correctness score.
logic_normalize_confidence() {
  case "${1:-unknown}" in
    high|medium|low|unknown) printf '%s' "${1:-unknown}" ;;
    *) printf 'unknown' ;;
  esac
}

# _logic_log_beads <kind> <actor> <phase> <decision> <why> <evidence> <result> <sha> <confidence> <slug> <logical> <wt> <ts>
_logic_log_beads() {
  local kind="$1" actor="$2" phase="$3" decision="$4" why="$5" evidence="$6" result="$7" sha="$8"
  local confidence="$9" slug="${10}" logical="${11}" wt="${12}" ts="${13}"
  local labels="logic:${slug}"
  [ -z "$why" ] && labels="${labels},logic-stub"
  local meta id
  if logic_have jq; then
    meta=$(jq -nc \
      --arg actor "$actor" --arg phase "$phase" --arg evidence "$evidence" \
      --arg result "$result" --arg confidence "$confidence" \
      --arg branch "$logical" --arg wt "$wt" \
      --arg sha "$sha" --arg kind "$kind" --arg ts "$ts" \
      '{actor:$actor,phase:$phase,evidence:$evidence,result:$result,confidence:$confidence,branch:$branch,worktree:$wt,sha:$sha,kind:$kind,ts:$ts}')
  else
    meta="{\"actor\":\"$actor\",\"kind\":\"$kind\",\"sha\":\"$sha\",\"branch\":\"$logical\",\"confidence\":\"$confidence\"}"
  fi
  id=$(bd create --type=decision --priority=3 --silent \
    --title="$decision" \
    --description="${why:-"(pending why)"}" \
    --labels="$labels" \
    --metadata="$meta" 2>/dev/null)
  [ -z "$id" ] && return 1
  bd close "$id" >/dev/null 2>&1
  printf '%s' "$id"
}

# _logic_log_tsv <kind> <actor> <phase> <decision> <why> <evidence> <result> <sha> <confidence> <slug> <wt> <ts>
_logic_log_tsv() {
  local kind="$1" actor="$2" phase="$3" decision="$4" why="$5" evidence="$6" result="$7" sha="$8"
  local confidence="$9" slug="${10}" wt="${11}" ts="${12}"
  local dir; dir="$(logic_dir)/audit/${slug}"
  mkdir -p "$dir" 2>/dev/null
  local file
  file="${dir}/$(logic_slug "$actor").tsv"
  if [ ! -f "$file" ]; then printf '%s\n' "$LOGIC_TSV_HEADER" >"$file"; fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(logic_sanitize_cell "$ts")" \
    "$(logic_sanitize_cell "$actor")" \
    "$(logic_sanitize_cell "$phase")" \
    "$(logic_sanitize_cell "$decision")" \
    "$(logic_sanitize_cell "$why")" \
    "$(logic_sanitize_cell "$evidence")" \
    "$(logic_sanitize_cell "$result")" \
    "$(logic_sanitize_cell "$kind")" \
    "$(logic_sanitize_cell "$sha")" \
    "$(logic_sanitize_cell "$wt")" \
    "$(logic_sanitize_cell "$confidence")" \
    >>"$file"
  printf '%s' "$file"
}

# logic_log_row <kind> <actor> <phase> <decision> <why> <evidence> <result> <sha> [confidence]
# Routes to beads or TSV per effective storage. If a beads write fails for any
# reason, the row still lands — in TSV, in the same call — and a warning is
# recorded. Losing a row silently is never acceptable.
# Prints the created row id (bead id, or the tsv path).
logic_log_row() {
  local kind="$1" actor="$2" phase="$3" decision="$4" why="$5" evidence="$6" result="$7" sha="$8"
  local confidence; confidence=$(logic_normalize_confidence "${9:-unknown}")
  local es logical storage
  es=$(logic_effective_state)
  logical=$(printf '%s' "$es" | awk '{print $2}')
  storage=$(printf '%s' "$es" | awk '{print $3}')
  local slug; slug=$(logic_slug "$logical")
  local wt; wt=$(logic_repo_root)
  local ts; ts=$(logic_now)

  if [ "$storage" = "beads" ]; then
    local id
    id=$(_logic_log_beads "$kind" "$actor" "$phase" "$decision" "$why" "$evidence" "$result" "$sha" "$confidence" "$slug" "$logical" "$wt" "$ts")
    if [ -n "$id" ]; then printf '%s' "$id"; return 0; fi
    logic_record_note "logic: a bd write failed; that decision row went to the TSV fallback at .logic/audit/ instead."
  else
    logic_record_warning
  fi

  _logic_log_tsv "$kind" "$actor" "$phase" "$decision" "$why" "$evidence" "$result" "$sha" "$confidence" "$slug" "$wt" "$ts"
}

# --- finding and enriching stubs -----------------------------------------

# Does a stub already exist for this commit SHA on the current logical branch?
# Prints the bead id (beads) or the matching TSV line (tsv) if found.
logic_find_stub_by_sha() {
  local sha="$1"
  local es logical storage slug
  es=$(logic_effective_state)
  logical=$(printf '%s' "$es" | awk '{print $2}')
  storage=$(printf '%s' "$es" | awk '{print $3}')
  slug=$(logic_slug "$logical")

  if [ "$storage" = "beads" ] && logic_bd_ok && logic_have jq; then
    bd query "label=logic:${slug}" --all --json 2>/dev/null \
      | jq -r --arg s "$sha" '.[] | select((.metadata.sha // "")==$s) | .id' 2>/dev/null \
      | head -1
    return 0
  fi
  logic_tsv_row_for_sha "$sha" "$slug"
}

# Prints the first TSV row (any kind) recorded for a SHA, or fails.
logic_tsv_row_for_sha() {
  local sha="$1" slug="$2" d f line
  d="$(logic_dir)/audit/${slug}"
  [ -d "$d" ] || return 1
  for f in "$d"/*.tsv; do
    [ -f "$f" ] || continue
    line=$(awk -F'\t' -v s="$sha" 'NR>1 && $9==s {print; exit}' "$f")
    if [ -n "$line" ]; then printf '%s' "$line"; return 0; fi
  done
  return 1
}

# Enrich a stub with its why.
# beads: update the bead in place and drop the logic-stub label.
# tsv:   append a superseding row carrying the same sha and decision (the TSV
#        log is append-only; collect prefers the enriched row per sha+decision).
# logic_enrich <bead-id-or-sha> <why> [result] [confidence]
logic_enrich() {
  local ref="$1" why="$2" result="${3:-}" confidence="${4:-}"
  [ -n "$confidence" ] && confidence=$(logic_normalize_confidence "$confidence")
  local es logical storage slug
  es=$(logic_effective_state)
  logical=$(printf '%s' "$es" | awk '{print $2}')
  storage=$(printf '%s' "$es" | awk '{print $3}')
  slug=$(logic_slug "$logical")

  if [ "$storage" = "beads" ] && logic_bd_ok; then
    local id="$ref" resolved
    # allow enriching by SHA
    if logic_have jq; then
      resolved=$(bd query "label=logic:${slug}" --all --json 2>/dev/null \
        | jq -r --arg s "$ref" '.[] | select((.metadata.sha // "")==$s) | .id' 2>/dev/null | head -1)
      [ -n "$resolved" ] && id="$resolved"
    fi
    bd update "$id" --description "$why" >/dev/null 2>&1 || return 1
    bd label remove "$id" logic-stub >/dev/null 2>&1
    if { [ -n "$result" ] || [ -n "$confidence" ]; } && logic_have jq; then
      local cur newmeta
      cur=$(bd show "$id" --json 2>/dev/null | jq -c '.metadata // {}' 2>/dev/null)
      [ -z "$cur" ] && cur='{}'
      newmeta=$(printf '%s' "$cur" | jq -c --arg r "$result" --arg c "$confidence" '
        (if $r != "" then .result=$r else . end)
        | (if $c != "" then .confidence=$c else . end)' 2>/dev/null)
      [ -n "$newmeta" ] && bd update "$id" --metadata "$newmeta" >/dev/null 2>&1
    fi
    printf '%s' "$id"
    return 0
  fi

  # TSV supersede
  local line phase decision evidence actor existing_confidence
  line=$(logic_tsv_row_for_sha "$ref" "$slug") || return 1
  phase=$(printf '%s' "$line" | awk -F'\t' '{print $3}')
  decision=$(printf '%s' "$line" | awk -F'\t' '{print $4}')
  evidence=$(printf '%s' "$line" | awk -F'\t' '{print $6}')
  existing_confidence=$(printf '%s' "$line" | awk -F'\t' '{print $11}')
  [ -z "$confidence" ] && confidence="${existing_confidence:-unknown}"
  actor=$(logic_actor)
  _logic_log_tsv "enrich" "$actor" "$phase" "$decision" "$why" "$evidence" "$result" "$ref" "$confidence" \
    "$slug" "$(logic_repo_root)" "$(logic_now)"
}
