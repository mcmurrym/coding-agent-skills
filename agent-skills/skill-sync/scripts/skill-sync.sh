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
# Discover the private repo from the script's own location.
# Script lives at agent-skills/skill-sync/scripts/skill-sync.sh, so repo root is 3 levels up.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_candidate="$(cd "$SCRIPT_DIR/../../.." 2>/dev/null && pwd)"
if [ -d "$_candidate/.git" ] && [ -d "$_candidate/agent-skills" ]; then
  PRIVATE_REPO="$_candidate"
else
  PRIVATE_REPO="${CODING_AGENT_SKILLS_REPO:-$HOME/coding-agent-skills}"
fi
unset _candidate
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

cmd_status() {
  require_private_repo
  require_project_repo

  local manifest
  manifest="$(read_manifest)"

  local skills
  skills="$(echo "$manifest" | jq -r '.skills | keys[]')"

  if [ -z "$skills" ]; then
    echo "No skills installed in this project."
    return
  fi

  printf "%-20s %-12s %-12s %-15s %s\n" "Skill" "Installed" "Upstream" "Local Changes" "Status"
  printf "%-20s %-12s %-12s %-15s %s\n" "----" "---------" "--------" "-------------" "------"

  for skill in $skills; do
    local source_commit upstream_commit upstream_diff local_diff status_str

    source_commit="$(echo "$manifest" | jq -r ".skills[\"$skill\"].sourceCommit // empty")"
    upstream_commit="$(get_private_commit)"

    # Check upstream changes since installed commit
    upstream_diff="$(git -C "$PRIVATE_REPO" diff --stat "$source_commit..HEAD" -- "agent-skills/$skill/" 2>/dev/null || true)"

    # Check local changes by comparing installed files against original source
    local has_local_changes="no"
    if [ -d "$SHARED_DIR/$skill" ]; then
      local tmp_dir
      tmp_dir="$(mktemp -d)"
      # Extract the original version from the source commit
      git -C "$PRIVATE_REPO" archive "$source_commit" -- "agent-skills/$skill" 2>/dev/null | tar -x -C "$tmp_dir" 2>/dev/null || true
      if [ -d "$tmp_dir/agent-skills/$skill" ]; then
        local_diff="$(diff -rq "$tmp_dir/agent-skills/$skill" "$SHARED_DIR/$skill" 2>/dev/null || true)"
        if [ -n "$local_diff" ]; then
          has_local_changes="yes"
        fi
      fi
      rm -rf "$tmp_dir"
    fi

    # Determine status
    local has_upstream="no"
    if [ -n "$upstream_diff" ]; then
      has_upstream="yes"
    fi

    if [ ! -d "$SHARED_DIR/$skill" ]; then
      status_str="files missing"
    elif [ "$has_upstream" = "yes" ] && [ "$has_local_changes" = "yes" ]; then
      status_str="both changed"
    elif [ "$has_upstream" = "yes" ]; then
      status_str="update available"
    elif [ "$has_local_changes" = "yes" ]; then
      status_str="locally modified"
    else
      status_str="up to date"
    fi

    printf "%-20s %-12s %-12s %-15s %s\n" "$skill" "$source_commit" "$upstream_commit" "$has_local_changes" "$status_str"
  done
}

cmd_update() {
  local skill="$1"
  require_private_repo
  require_project_repo

  if [ "$skill" = "--all" ]; then
    local manifest
    manifest="$(read_manifest)"
    local skills
    skills="$(echo "$manifest" | jq -r '.skills | keys[]' 2>/dev/null)"
    if [ -z "$skills" ]; then
      echo "No skills installed to update."
      return
    fi
    for s in $skills; do
      cmd_update_single "$s"
    done
    return
  fi

  cmd_update_single "$skill"
}

cmd_update_single() {
  local skill="$1"
  skill_exists_in_private "$skill"

  local source_commit
  source_commit="$(get_manifest_commit "$skill")"
  [ -n "$source_commit" ] || die "Skill '$skill' is not installed. Use 'install' first."

  local current_commit
  current_commit="$(get_private_commit)"

  # Check upstream changes
  local upstream_diff
  upstream_diff="$(git -C "$PRIVATE_REPO" diff "$source_commit..$current_commit" -- "agent-skills/$skill/" 2>/dev/null)"

  if [ -z "$upstream_diff" ]; then
    echo "$skill: already up to date (at $source_commit)"
    return
  fi

  echo "=== Changes for $skill ($source_commit -> $current_commit) ==="
  git -C "$PRIVATE_REPO" diff --stat "$source_commit..$current_commit" -- "agent-skills/$skill/"
  echo ""
  git -C "$PRIVATE_REPO" diff "$source_commit..$current_commit" -- "agent-skills/$skill/"
  echo ""

  # Copy updated files
  rm -rf "$SHARED_DIR/$skill"
  mkdir -p "$SHARED_DIR/$skill"
  cp -R "$PRIVATE_SKILLS/$skill/." "$SHARED_DIR/$skill/"

  # Update manifest
  local timestamp
  timestamp="$(now_iso)"
  local manifest
  manifest="$(read_manifest)"
  manifest="$(echo "$manifest" | jq --arg s "$skill" --arg c "$current_commit" --arg t "$timestamp" \
    '.skills[$s].sourceCommit = $c | .skills[$s].updatedAt = $t')"
  write_manifest "$manifest"

  echo "Updated $skill to commit $current_commit"
}

cmd_harvest() {
  local skill="$1"
  require_private_repo
  require_project_repo

  local source_commit
  source_commit="$(get_manifest_commit "$skill")"
  [ -n "$source_commit" ] || die "Skill '$skill' is not installed. Nothing to harvest."

  [ -d "$SHARED_DIR/$skill" ] || die "Skill directory $SHARED_DIR/$skill not found"

  # Reconstruct what was originally installed
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  git -C "$PRIVATE_REPO" archive "$source_commit" -- "agent-skills/$skill" | tar -x -C "$tmp_dir" 2>/dev/null \
    || die "Could not retrieve original version at commit $source_commit"

  # Diff original vs project's current version
  local harvest_diff
  harvest_diff="$(diff -ru "$tmp_dir/agent-skills/$skill" "$SHARED_DIR/$skill" 2>/dev/null || true)"

  rm -rf "$tmp_dir"

  if [ -z "$harvest_diff" ]; then
    echo "$skill: no local modifications to harvest"
    return
  fi

  echo "=== Local changes to $skill (since install at $source_commit) ==="
  echo "$harvest_diff"
  echo ""

  # Copy project version back to private repo
  rm -rf "$PRIVATE_SKILLS/$skill"
  mkdir -p "$PRIVATE_SKILLS/$skill"
  cp -R "$SHARED_DIR/$skill/." "$PRIVATE_SKILLS/$skill/"

  echo "Harvested changes from project into private repo at $PRIVATE_SKILLS/$skill/"
  echo "Review and commit the changes in your private repo when ready."
}

cmd_remove() {
  local skill="$1"
  require_project_repo

  local source_commit
  source_commit="$(get_manifest_commit "$skill")"
  [ -n "$source_commit" ] || die "Skill '$skill' is not in the manifest. Nothing to remove."

  # Remove skill files
  if [ -d "$SHARED_DIR/$skill" ]; then
    rm -rf "$SHARED_DIR/$skill"
    echo "Removed $SHARED_DIR/$skill/"
  fi

  # Remove symlinks
  for agent_dir in "${AGENT_DIRS[@]}"; do
    if [ -L "$agent_dir/$skill" ]; then
      rm "$agent_dir/$skill"
      echo "Removed symlink $agent_dir/$skill"
    fi
    # Clean up empty agent skills directory
    if [ -d "$agent_dir" ] && [ -z "$(ls -A "$agent_dir" 2>/dev/null)" ]; then
      rmdir "$agent_dir"
      # Also clean parent dir if empty (e.g. .agents/ after removing .agents/skills/)
      local parent_dir
      parent_dir="$(dirname "$agent_dir")"
      if [ -d "$parent_dir" ] && [ -z "$(ls -A "$parent_dir" 2>/dev/null)" ]; then
        rmdir "$parent_dir"
      fi
    fi
  done

  # Update manifest
  local manifest
  manifest="$(read_manifest)"
  manifest="$(echo "$manifest" | jq --arg s "$skill" 'del(.skills[$s])')"

  # Check if any skills remain
  local remaining
  remaining="$(echo "$manifest" | jq '.skills | length')"
  if [ "$remaining" -eq 0 ]; then
    # Remove manifest and .shared directory
    rm -f "$MANIFEST"
    echo "Removed $MANIFEST"
    if [ -d "$SHARED_DIR" ] && [ -z "$(ls -A "$SHARED_DIR" 2>/dev/null)" ]; then
      rmdir "$SHARED_DIR"
    fi
    if [ -d ".shared" ] && [ -z "$(ls -A ".shared" 2>/dev/null)" ]; then
      rmdir ".shared"
    fi
  else
    write_manifest "$manifest"
    echo "Updated $MANIFEST"
  fi

  echo ""
  echo "Removed skill '$skill' from project"
}

# --- Dispatch ---
case "$COMMAND" in
  install)
    [ -n "$SKILL" ] || die "Usage: skill-sync.sh install <skill>"
    cmd_install "$SKILL"
    ;;
  status)
    cmd_status
    ;;
  update)
    [ -n "$SKILL" ] || die "Usage: skill-sync.sh update <skill> | --all"
    cmd_update "$SKILL"
    ;;
  harvest)
    [ -n "$SKILL" ] || die "Usage: skill-sync.sh harvest <skill>"
    cmd_harvest "$SKILL"
    ;;
  remove)
    [ -n "$SKILL" ] || die "Usage: skill-sync.sh remove <skill>"
    cmd_remove "$SKILL"
    ;;
  *)
    die "Unknown command: $COMMAND. Expected: install, update, harvest, remove, status"
    ;;
esac
