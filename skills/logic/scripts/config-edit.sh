#!/usr/bin/env bash
# logic: read and edit .logic/config.json.
#
# Usage:
#   config-edit.sh init                     # create .logic/config.json if absent
#   config-edit.sh get <jq-filter>          # e.g. get '.default'
#   config-edit.sh set <key> <value>        # top-level scalar, e.g. set storage tsv
#   config-edit.sh set-branch <branch> <on|off>
#   config-edit.sh set-storage <branch> <beads|tsv>
#   config-edit.sh path                     # print config path
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib.sh"

command -v jq >/dev/null 2>&1 || { echo "logic: jq is required to edit config" >&2; exit 1; }

CFG="$(logic_config_path)"
DIR="$(logic_dir)"

default_config() {
  cat <<'JSON'
{
  "version": 1,
  "default": "off",
  "branches": {},
  "storage": "beads",
  "storageOverrides": {}
}
JSON
}

ensure() {
  mkdir -p "$DIR" 2>/dev/null
  [ -f "$CFG" ] || default_config >"$CFG"
}

write() { # write stdin as the new config atomically
  local tmp="${CFG}.tmp.$$"
  cat >"$tmp" && mv -f "$tmp" "$CFG"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  init) ensure; echo "$CFG" ;;
  path) echo "$CFG" ;;
  get)
    [ -f "$CFG" ] || { echo ""; exit 0; }
    jq -r "${1:-.} // empty" "$CFG" ;;
  set)
    ensure; key="$1"; val="$2"
    jq --arg k "$key" --arg v "$val" '.[$k]=$v' "$CFG" | write
    jq -r --arg k "$key" '.[$k]' "$CFG" ;;
  set-branch)
    ensure; br="$1"; st="$2"
    case "$st" in on|off) ;; *) echo "state must be on|off" >&2; exit 1 ;; esac
    jq --arg b "$br" --arg s "$st" '.branches[$b]=$s' "$CFG" | write
    echo "branches[$br]=$st" ;;
  set-storage)
    ensure; br="$1"; sto="$2"
    case "$sto" in beads|tsv) ;; *) echo "storage must be beads|tsv" >&2; exit 1 ;; esac
    jq --arg b "$br" --arg s "$sto" '.storageOverrides[$b]=$s' "$CFG" | write
    echo "storageOverrides[$br]=$sto" ;;
  *)
    echo "usage: config-edit.sh {init|path|get <filter>|set <k> <v>|set-branch <b> <on|off>|set-storage <b> <beads|tsv>}" >&2
    exit 1 ;;
esac
