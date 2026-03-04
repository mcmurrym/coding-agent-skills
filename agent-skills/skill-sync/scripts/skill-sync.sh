#!/usr/bin/env bash
# skill-sync.sh — Install, update, harvest, remove, and status skills in project repos
#
# Usage: skill-sync.sh <command> [skill] [--all]
#
# Commands:
#   install <skill>    Copy skill from private repo into project
#   update  <skill>    Pull newer version from private repo
#   update  --all      Update all installed skills
#   harvest <skill>    Pull project changes back to private repo
#   remove  <skill>    Remove skill from project
#   status             Show installed skills and sync state

set -euo pipefail

# --- Config ---
PRIVATE_REPO="$HOME/coding-agent-skills"
PRIVATE_SKILLS="$PRIVATE_REPO/agent-skills"
SHARED_DIR=".shared/skills"
MANIFEST=".shared/skills-manifest.json"
AGENT_DIRS=(".claude/skills" ".agents/skills" ".gemini/skills")

# --- Helpers ---
die() { echo "error: $*" >&2; exit 1; }

require_jq() {
  command -v jq >/dev/null 2>&1 || die "jq is required but not installed"
}

require_private_repo() {
  [ -d "$PRIVATE_REPO/.git" ] || die "Private repo not found at $PRIVATE_REPO"
}

require_project_repo() {
  git rev-parse --git-dir >/dev/null 2>&1 || die "Not in a git repository"
  local project_root
  project_root="$(git rev-parse --show-toplevel)"
  local private_root
  private_root="$(cd "$PRIVATE_REPO" && git rev-parse --show-toplevel)"
  [ "$project_root" != "$private_root" ] || die "Cannot install skills into the private skills repo itself"
}

skill_exists_in_private() {
  local skill="$1"
  [ -d "$PRIVATE_SKILLS/$skill" ] || die "Skill '$skill' not found in private repo at $PRIVATE_SKILLS/$skill"
}

get_private_commit() {
  git -C "$PRIVATE_REPO" rev-parse --short HEAD
}

now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

read_manifest() {
  if [ -f "$MANIFEST" ]; then
    cat "$MANIFEST"
  else
    echo '{"source":"coding-agent-skills","skills":{}}'
  fi
}

write_manifest() {
  local content="$1"
  mkdir -p "$(dirname "$MANIFEST")"
  echo "$content" | jq . > "$MANIFEST"
}

get_manifest_commit() {
  local skill="$1"
  read_manifest | jq -r ".skills[\"$skill\"].sourceCommit // empty"
}

# --- Parse arguments ---
COMMAND="${1:-}"
SKILL="${2:-}"

[ -n "$COMMAND" ] || die "Usage: skill-sync.sh <command> [skill] [--all]"

require_jq

# --- Commands ---

cmd_install() {
  local skill="$1"

  # Validate
  require_private_repo
  require_project_repo
  skill_exists_in_private "$skill"

  # Check if already installed
  local existing_commit
  existing_commit="$(get_manifest_commit "$skill")"
  if [ -n "$existing_commit" ]; then
    die "Skill '$skill' is already installed (commit $existing_commit). Use 'update' instead."
  fi

  # Get current private repo commit
  local commit
  commit="$(get_private_commit)"

  # Copy the skill directory into .shared/skills/<skill>/
  mkdir -p "$SHARED_DIR/$skill"
  cp -R "$PRIVATE_SKILLS/$skill/." "$SHARED_DIR/$skill/"

  # Create relative symlinks in each agent dir
  for agent_dir in "${AGENT_DIRS[@]}"; do
    mkdir -p "$agent_dir"
    local rel_path
    rel_path="$(python3 -c "import os.path; print(os.path.relpath('$SHARED_DIR/$skill', '$agent_dir'))")"
    ln -sfn "$rel_path" "$agent_dir/$skill"
  done

  # Update the manifest
  local now
  now="$(now_iso)"
  local manifest
  manifest="$(read_manifest)"
  manifest="$(echo "$manifest" | jq --arg skill "$skill" \
    --arg commit "$commit" \
    --arg now "$now" \
    '.skills[$skill] = {sourceCommit: $commit, installedAt: $now, updatedAt: $now}')"
  write_manifest "$manifest"

  echo "Installed skill '$skill' from commit $commit"
  echo "  Shared:   $SHARED_DIR/$skill/"
  for agent_dir in "${AGENT_DIRS[@]}"; do
    echo "  Symlink:  $agent_dir/$skill -> $(readlink "$agent_dir/$skill")"
  done
  echo "  Manifest: $MANIFEST"
}

# --- Dispatch ---
case "$COMMAND" in
  install)
    [ -n "$SKILL" ] || die "Usage: skill-sync.sh install <skill>"
    cmd_install "$SKILL"
    ;;
  update|harvest|remove|status)
    die "Command '$COMMAND' not yet implemented"
    ;;
  *)
    die "Unknown command: $COMMAND. Expected: install, update, harvest, remove, status"
    ;;
esac
