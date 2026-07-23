#!/usr/bin/env bash
# logic-core engine library.
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
  case "$1" in
    $2) return 0 ;;
    *) return 1 ;;
  esac
}

# Resolve tracking for the current checkout.
# Prints three space-separated fields: STATE LOGICAL_BRANCH STORAGE
#   STATE          on | off
#   LOGICAL_BRANCH the branch rows are scoped to (the matched config key, or HEAD's branch)
#   STORAGE        beads | tsv
# Precedence: exact branch key > glob key > enabled-ancestor > default.
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
      # 3. enabled-ancestor (a derived worktree branch forked from an enabled branch)
      if [ -z "$matched" ]; then
        local anc
        while IFS= read -r anc; do
          [ -z "$anc" ] && continue
          # skip globs here; only concrete branch refs can be ancestors
          case "$anc" in *'*'*|*'?'*) continue ;; esac
          if git rev-parse --verify --quiet "$anc" >/dev/null 2>&1 \
             && git merge-base --is-ancestor "$anc" HEAD 2>/dev/null; then
            state="on"; logical="$anc"; break
          fi
        done < <(printf '%s' "$raw" | jq -r '.branches // {} | to_entries[] | select(.value=="on") | .key' 2>/dev/null)
      fi
    fi
    # storage override keyed on the logical branch
    local ov; ov=$(printf '%s' "$raw" | jq -r --arg b "$logical" '.storageOverrides[$b] // empty' 2>/dev/null)
    [ -n "$ov" ] && storage="$ov"
  fi

  # beads storage silently falls back to tsv when bd is unavailable
  if [ "$storage" = "beads" ] && ! logic_have bd; then storage="tsv"; fi
  printf '%s %s %s' "$state" "$logical" "$storage"
}

logic_is_tracked() {
  local s; s=$(logic_effective_state); [ "${s%% *}" = "on" ]
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

LOGIC_TSV_HEADER='ts	actor	phase	decision	why	evidence	result	kind	sha	worktree'

# logic_log_row <kind> <actor> <phase> <decision> <why> <evidence> <result> <sha>
# kind: stub|manual|agent. Routes to beads or TSV per effective storage.
# Prints the created row id (bead id, or the tsv path) on success.
logic_log_row() {
  local kind="$1" actor="$2" phase="$3" decision="$4" why="$5" evidence="$6" result="$7" sha="$8"
  local es logical storage
  es=$(logic_effective_state); logical=$(printf '%s' "$es" | awk '{print $2}'); storage=$(printf '%s' "$es" | awk '{print $3}')
  local slug; slug=$(logic_slug "$logical")
  local wt; wt=$(logic_repo_root)
  local ts; ts=$(logic_now)

  if [ "$storage" = "beads" ] && logic_have bd; then
    local labels="logic:${slug}"
    [ -z "$why" ] && labels="${labels},logic-stub"
    local meta
    if logic_have jq; then
      meta=$(jq -nc \
        --arg actor "$actor" --arg phase "$phase" --arg evidence "$evidence" \
        --arg result "$result" --arg branch "$logical" --arg wt "$wt" \
        --arg sha "$sha" --arg kind "$kind" --arg ts "$ts" \
        '{actor:$actor,phase:$phase,evidence:$evidence,result:$result,branch:$branch,worktree:$wt,sha:$sha,kind:$kind,ts:$ts}')
    else
      meta="{\"actor\":\"$actor\",\"kind\":\"$kind\",\"sha\":\"$sha\",\"branch\":\"$logical\"}"
    fi
    local id
    id=$(bd create --type=decision --priority=3 --silent \
      --title="$decision" \
      --description="${why:-"(pending why)"}" \
      --labels="$labels" \
      --metadata="$meta" 2>/dev/null)
    if [ -n "$id" ]; then
      bd close "$id" >/dev/null 2>&1
      printf '%s' "$id"
      return 0
    fi
    return 1
  fi

  # TSV backend: one file per writer under .logic/audit/<slug>/<actor>.tsv
  local dir; dir="$(logic_dir)/audit/${slug}"
  mkdir -p "$dir" 2>/dev/null
  local file="${dir}/$(logic_slug "$actor").tsv"
  if [ ! -f "$file" ]; then printf '%s\n' "$LOGIC_TSV_HEADER" >"$file"; fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
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
    >>"$file"
  printf '%s' "$file"
}

# Does a stub already exist for this commit SHA on the current logical branch?
# Prints the bead id if found (beads backend only).
logic_find_stub_by_sha() {
  local sha="$1"
  local es logical slug; es=$(logic_effective_state)
  logical=$(printf '%s' "$es" | awk '{print $2}'); slug=$(logic_slug "$logical")
  logic_have bd || return 1
  logic_have jq || return 1
  bd query "label=logic:${slug}" --all --json 2>/dev/null \
    | jq -r --arg s "$sha" '.[] | select((.metadata.sha // "")==$s) | .id' 2>/dev/null \
    | head -1
}

# Enrich a stub: set its why (description) and drop the logic-stub label.
# logic_enrich <bead-id> <why> [result]
logic_enrich() {
  local id="$1" why="$2" result="${3:-}"
  logic_have bd || return 1
  bd update "$id" --description "$why" >/dev/null 2>&1
  bd label remove "$id" logic-stub >/dev/null 2>&1
  if [ -n "$result" ] && logic_have jq; then
    local cur; cur=$(bd show "$id" --json 2>/dev/null | jq -c '.metadata // {}' 2>/dev/null)
    [ -z "$cur" ] && cur='{}'
    local newmeta; newmeta=$(printf '%s' "$cur" | jq -c --arg r "$result" '.result=$r' 2>/dev/null)
    [ -n "$newmeta" ] && bd update "$id" --metadata "$newmeta" >/dev/null 2>&1
  fi
}
