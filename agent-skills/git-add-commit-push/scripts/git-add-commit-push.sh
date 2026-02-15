#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  git-add-commit-push.sh [--dry-run] [--no-push] [-r origin] [-b branch] [-m "message"]

Options:
  -m, --message  Commit message (optional, default: auto-generate)
  --no-push      Skip pushing to remote
  -r, --remote   Remote name (default: origin)
  -b, --branch   Branch name (default: current branch)
  --dry-run      Print actions without executing
  -h, --help     Show help
EOF
}

message=""
remote="origin"
branch=""
push=1
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--message)
      message="${2:-}"
      shift 2
      ;;
    --no-push)
      push=0
      shift
      ;;
    -r|--remote)
      remote="${2:-}"
      shift 2
      ;;
    -b|--branch)
      branch="${2:-}"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$(git status --porcelain)" ]]; then
  echo "No changes to commit." >&2
  exit 1
fi

current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$current_branch" == "HEAD" ]]; then
  echo "Detached HEAD; cannot determine current branch." >&2
  exit 1
fi

if [[ -z "$branch" ]]; then
  branch="$current_branch"
fi

generate_message() {
  local changed files_count top_path summary
  changed="$(git diff --cached --name-status)"
  if [[ -z "$changed" ]]; then
    changed="$(git diff --name-status)"
  fi
  files_count="$(echo "$changed" | awk 'NF' | wc -l | tr -d ' ')"
  top_path="$(echo "$changed" | awk '{print $2}' | head -n 1)"

  if [[ "$files_count" -eq 1 ]]; then
    summary="$(basename "$top_path")"
  else
    summary="$(dirname "$top_path")"
  fi

  if [[ "$summary" == "." || -z "$summary" ]]; then
    summary="repo"
  fi

  echo "chore: update $summary"
}

has_env_files() {
  git diff --cached --name-only | grep -E '(^|/)\.env(\..*)?$' >/dev/null 2>&1
}

if [[ "$dry_run" -eq 1 ]]; then
  echo "Dry run:"
  echo "  git add -A"
  if [[ -z "$message" ]]; then
    echo "  git commit -m \"$(generate_message)\""
  else
    echo "  git commit -m \"$message\""
  fi
  if [[ "$push" -eq 1 ]]; then
    echo "  git push \"$remote\" \"$branch\""
  else
    echo "  (skip push)"
  fi
  exit 0
fi

git add -A

if has_env_files; then
  echo "Refusing to commit .env files. Remove them from staging and try again." >&2
  exit 1
fi

if [[ -z "$message" ]]; then
  message="$(generate_message)"
fi

git commit -m "$message"

if [[ "$push" -eq 1 ]]; then
  git push "$remote" "$branch"
fi
