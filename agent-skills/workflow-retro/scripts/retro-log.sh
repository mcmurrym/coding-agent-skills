#!/usr/bin/env bash
set -euo pipefail

# Resolve the .git directory (works in worktrees too)
GIT_DIR="$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir)"
LOG_FILE="$GIT_DIR/retro-log.json"

usage() {
  cat <<'USAGE'
Usage:
  retro-log.sh read                          Print current log (or empty JSON)
  retro-log.sh append --json '<entry>'       Append a JSON entry to the log
  retro-log.sh search --finding '<text>'     Search for similar past findings
USAGE
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

ensure_log() {
  if [[ ! -f "$LOG_FILE" ]]; then
    echo '{"entries":[]}' > "$LOG_FILE"
  fi
}

cmd_read() {
  ensure_log
  cat "$LOG_FILE"
}

cmd_append() {
  local entry_json=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) entry_json="$2"; shift ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
  done

  if [[ -z "$entry_json" ]]; then
    echo "append requires --json '<entry>'" >&2
    exit 1
  fi

  ensure_log

  # Validate the entry is valid JSON
  if ! echo "$entry_json" | jq empty 2>/dev/null; then
    echo "Invalid JSON entry" >&2
    exit 1
  fi

  # Append entry to the log
  local tmp
  tmp="$(mktemp)"
  jq --argjson new "$entry_json" '.entries += [$new]' "$LOG_FILE" > "$tmp"
  mv "$tmp" "$LOG_FILE"

  echo "Entry appended to $LOG_FILE"
}

cmd_search() {
  local finding=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --finding) finding="$2"; shift ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
  done

  if [[ -z "$finding" ]]; then
    echo "search requires --finding '<text>'" >&2
    exit 1
  fi

  ensure_log

  # Normalize: lowercase, strip punctuation, split into words
  local words
  words="$(echo "$finding" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' ' ' | xargs)"

  # Search entries where finding contains any of the key words
  # Returns matching entries with a simple word-overlap score
  local word
  local conditions=()

  for word in $words; do
    # Skip very short/common words
    if [[ ${#word} -le 2 ]]; then
      continue
    fi
    conditions+=("(.finding | ascii_downcase | contains(\"$word\"))")
  done

  if [[ ${#conditions[@]} -eq 0 ]]; then
    echo "[]"
    return
  fi

  # Match entries where at least half the significant words match
  local threshold=$(( (${#conditions[@]} + 1) / 2 ))
  local count_expr
  count_expr="$(printf "[%s] | map(if . then 1 else 0 end) | add" "$(IFS=,; echo "${conditions[*]}")")"

  jq --argjson threshold "$threshold" \
    "[.entries[] | . as \$e | ($count_expr) as \$score | select(\$score >= \$threshold) | . + {match_score: \$score}] | sort_by(-.match_score)" \
    "$LOG_FILE"
}

main() {
  require_cmd jq
  require_cmd git

  local cmd="${1:-}"
  if [[ -z "$cmd" ]]; then
    usage
    exit 1
  fi
  shift

  case "$cmd" in
    read) cmd_read ;;
    append) cmd_append "$@" ;;
    search) cmd_search "$@" ;;
    --help|-h) usage ;;
    *) echo "Unknown command: $cmd" >&2; usage; exit 1 ;;
  esac
}

main "$@"
