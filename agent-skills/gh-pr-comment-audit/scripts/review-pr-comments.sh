#!/usr/bin/env bash
set -euo pipefail

JSON_ONLY=0
PR_OWNER=""
PR_REPO=""
PR_NUMBER=""
TARGET_DISCUSSION=""
TARGET_THREAD_ID=""
NEXT_UNRESOLVED=0

usage() {
  cat <<'USAGE'
Usage:
  review-pr-comments.sh fetch <pr-url-or-ref> [--discussion <discussion-id-or-url>] [--thread-id <thread_id>] [--next-unresolved] [--json-only]
  review-pr-comments.sh resolve <pr-url-or-ref> \
    --thread-id <thread_id> [--thread-id <thread_id> ...] [--json-only]

Input examples:
  https://github.com/<owner>/<repo>/pull/<number>
  https://github.com/<owner>/<repo>/pull/<number>#discussion_r123456789
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

    if [[ "$path" == *#* ]]; then
      local fragment="${path#*#}"
      path="${path%%#*}"
      if [[ -z "$TARGET_DISCUSSION" && "$fragment" == discussion_* ]]; then
        TARGET_DISCUSSION="$fragment"
      fi
    fi

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

selector_count() {
  local count=0
  [[ -n "$TARGET_DISCUSSION" ]] && count=$((count + 1))
  [[ -n "$TARGET_THREAD_ID" ]] && count=$((count + 1))
  [[ "$NEXT_UNRESOLVED" -eq 1 ]] && count=$((count + 1))
  echo "$count"
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
  local selectors

  if ! payload="$(gh api graphql -f query="$(fetch_query)" -f owner="$PR_OWNER" -f repo="$PR_REPO" -F number="$PR_NUMBER" 2>/dev/null)"; then
    payload="$(gh api graphql -f query="$(fetch_query_fallback)" -f owner="$PR_OWNER" -f repo="$PR_REPO" -F number="$PR_NUMBER")"
  fi

  selectors="$(selector_count)"

  if [[ "$selectors" -gt 0 ]]; then
    require_cmd jq
    payload="$(filter_selected_threads "$payload")"
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
    | . as $thread
    | "THREAD:\($thread.id)"
    , (if $thread.selectedComment then "selected_comment: \($thread.selectedComment.id)" else empty end)
    , "path: \($thread.path // "")"
    , "line: \($thread.line // $thread.startLine // "")"
    , "outdated: \($thread.isOutdated)"
    , "can_resolve: \($thread.viewerCanResolve)"
    , "COMMENTS:"
    , ($thread.comments.nodes[] | "  - \((if .id == ($thread.selectedComment.id // null) then "TARGET " else "" end))id=\(.id) author=\(.author.login // "") commit=\(.originalCommit.oid // "") url=\(.url // "")", "    body: \(.body // "" | gsub("\n"; "\n    "))")
    , "---"
  '
}

filter_selected_threads() {
  local payload="$1"

  if [[ -n "$TARGET_THREAD_ID" ]]; then
    jq --arg thread_id "$TARGET_THREAD_ID" '
      .data.repository.pullRequest.reviewThreads.nodes |=
        (map(select(.isResolved == false and .id == $thread_id)) | if length == 0 then error("No unresolved review thread matched thread id: " + $thread_id) else . end)
    ' <<<"$payload"
    return
  fi

  if [[ -n "$TARGET_DISCUSSION" ]]; then
    jq --arg discussion "$TARGET_DISCUSSION" '
      def normalized_discussion:
        ($discussion | tostring | sub("^#"; ""));
      def matches_discussion:
        (.id == $discussion)
        or ((.url // "") | contains($discussion))
        or ((.url // "") | contains(normalized_discussion))
        or (((.url // "") | split("#")[-1]) == normalized_discussion);

      .data.repository.pullRequest.reviewThreads.nodes |=
        ([
          .[]
          | select(.isResolved == false)
          | (.comments.nodes[] | select(matches_discussion)) as $selected
          | . + {selectedComment: $selected}
        ] | if length == 0 then error("No unresolved review comment matched discussion selector: " + $discussion) else . end)
    ' <<<"$payload"
    return
  fi

  if [[ "$NEXT_UNRESOLVED" -eq 1 ]]; then
    jq '
      def actionable_comments:
        if (.comments.nodes | length) > 1 then .comments.nodes[1:] else .comments.nodes end;

      .data.repository.pullRequest.reviewThreads.nodes |=
        ([
          .[]
          | select(.isResolved == false)
          | . as $thread
          | (actionable_comments[]? | {thread: $thread, selected: .})
        ]
        | sort_by(.selected.createdAt // "")
        | if length == 0 then error("No unresolved review comments found") else [.[0].thread + {selectedComment: .[0].selected}] end)
    ' <<<"$payload"
    return
  fi

  echo "$payload"
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
      --discussion)
        TARGET_DISCUSSION="${2:-}"
        if [[ -z "$TARGET_DISCUSSION" ]]; then
          echo "--discussion requires a discussion id, anchor, or URL" >&2
          exit 1
        fi
        shift
        ;;
      --thread-id)
        TARGET_THREAD_ID="${2:-}"
        if [[ -z "$TARGET_THREAD_ID" ]]; then
          echo "--thread-id requires a thread id" >&2
          exit 1
        fi
        shift
        ;;
      --next-unresolved|next-unresolved)
        NEXT_UNRESOLVED=1
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

  if [[ "$(selector_count)" -gt 1 ]]; then
    echo "fetch accepts only one selector: --discussion, --thread-id, or --next-unresolved" >&2
    exit 1
  fi

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
