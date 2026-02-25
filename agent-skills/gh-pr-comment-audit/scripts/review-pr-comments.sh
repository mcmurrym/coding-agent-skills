#!/usr/bin/env bash
set -euo pipefail

JSON_ONLY=0
PR_OWNER=""
PR_REPO=""
PR_NUMBER=""

usage() {
  cat <<'USAGE'
Usage:
  review-pr-comments.sh fetch <pr-url-or-ref> [--json-only]
  review-pr-comments.sh resolve <pr-url-or-ref> \
    --thread-id <thread_id> [--thread-id <thread_id> ...] [--json-only]

Input examples:
  https://github.com/<owner>/<repo>/pull/<number>
  <owner>/<repo>#<number>
  <owner>/<repo>/<number>
USAGE
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

parse_pr_ref() {
  local input="$1"
  local tail

  PR_OWNER=""
  PR_REPO=""
  PR_NUMBER=""

  if [[ "$input" == https://github.com/* || "$input" == http://github.com/* ]]; then
    local path="${input#https://github.com/}"
    path="${path#http://github.com/}"

    if [[ "$path" == */pull/* ]]; then
      PR_OWNER="${path%%/*}"
      tail="${path#*/}"      # repo/pull/123
      PR_REPO="${tail%%/*}"
      tail="${tail#*/}"      # pull/123
      PR_NUMBER="${tail#pull/}"
      PR_NUMBER="${PR_NUMBER%%/*}"
    else
      echo "Could not parse pull request URL. Expected /pull/<number>: $input" >&2
      exit 1
    fi
    return
  fi

  if [[ "$input" == */*#* ]]; then
    PR_OWNER="${input%%/*}"
    tail="${input#*/}"
    PR_REPO="${tail%%#*}"
    PR_NUMBER="${tail##*#}"
    return
  fi

  if [[ "$input" == */*/* ]]; then
    PR_OWNER="${input%%/*}"
    tail="${input#*/}"
    PR_REPO="${tail%%/*}"
    PR_NUMBER="${tail#*/}"
    return
  fi

  echo "Could not parse pull request reference: $input" >&2
  exit 1
}

fetch_query() {
  cat <<'GRAPHQL'
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100, states: [UNRESOLVED]) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          startLine
          viewerCanResolve
          comments(first: 50) {
            nodes {
              id
              body
              author { login }
              createdAt
              path
              line
              originalLine
              originalCommit { oid }
              diffHunk
              url
            }
          }
        }
      }
    }
  }
}
GRAPHQL
}

fetch_query_fallback() {
  cat <<'GRAPHQL'
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          startLine
          viewerCanResolve
          comments(first: 50) {
            nodes {
              id
              body
              author { login }
              createdAt
              path
              line
              originalLine
              originalCommit { oid }
              diffHunk
              url
            }
          }
        }
      }
    }
  }
}
GRAPHQL
}

fetch_threads() {
  local payload

  if ! payload="$(gh api graphql -f query="$(fetch_query)" -f owner="$PR_OWNER" -f repo="$PR_REPO" -f number="$PR_NUMBER")"; then
    payload="$(gh api graphql -f query="$(fetch_query_fallback)" -f owner="$PR_OWNER" -f repo="$PR_REPO" -f number="$PR_NUMBER")"
  fi

  if [[ "$JSON_ONLY" -eq 1 ]] || ! command -v jq >/dev/null 2>&1; then
    echo "$payload"
    return
  fi

  echo "PR: https://github.com/$PR_OWNER/$PR_REPO/pull/$PR_NUMBER"
  echo "---"
  echo "$payload" | jq -r '
    .data.repository.pullRequest.reviewThreads.nodes[]
    | select(.isResolved == false)
    | "THREAD:\(.id)"
    , "path: \(.path // "")"
    , "line: \(.line // .startLine // "")"
    , "outdated: \(.isOutdated)"
    , "can_resolve: \(.viewerCanResolve)"
    , "COMMENTS:"
    , (.comments.nodes | map("  - id=\(.id) author=\(.author.login // "") commit=\(.originalCommit.oid // "")")[])
    , "---"
  '
}

resolve_threads() {
  local thread_ids=("$@")
  local thread_id

  for thread_id in "${thread_ids[@]}"; do
    local response
    response="$(gh api graphql -f query='mutation($threadId: ID!){resolveReviewThread(input:{threadId:$threadId, clientMutationId:"gh-pr-comment-audit"}){thread{id isResolved} clientMutationId}}' -f threadId="$thread_id")"

    if [[ "$JSON_ONLY" -eq 1 ]]; then
      echo "$response"
    else
      echo "Resolved thread: $thread_id"
    fi
  done
}

parse_fetch_cmd() {
  local ref=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json-only)
        JSON_ONLY=1
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      --*)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
      *)
        if [[ -z "$ref" ]]; then
          ref="$1"
        else
          echo "Unexpected extra argument: $1" >&2
          exit 1
        fi
        ;;
    esac
    shift
  done

  if [[ -z "$ref" ]]; then
    echo "fetch requires <pr-url-or-ref>" >&2
    exit 1
  fi

  parse_pr_ref "$ref"
  fetch_threads
}

parse_resolve_cmd() {
  local ref=""
  local thread_ids=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --thread-id)
        thread_ids+=("${2:-}")
        shift
        ;;
      --json-only)
        JSON_ONLY=1
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      --*)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
      *)
        if [[ -z "$ref" ]]; then
          ref="$1"
        else
          echo "Unexpected extra argument: $1" >&2
          exit 1
        fi
        ;;
    esac
    shift
  done

  if [[ -z "$ref" || ${#thread_ids[@]} -eq 0 ]]; then
    echo "resolve requires <pr-url-or-ref> and at least one --thread-id" >&2
    exit 1
  fi

  parse_pr_ref "$ref"
  resolve_threads "${thread_ids[@]}"
}

main() {
  require_cmd gh

  local cmd="${1:-}"
  if [[ -z "$cmd" ]]; then
    usage
    exit 1
  fi
  shift

  case "$cmd" in
    fetch)
      parse_fetch_cmd "$@"
      ;;
    resolve)
      parse_resolve_cmd "$@"
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "Unknown command: $cmd" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
