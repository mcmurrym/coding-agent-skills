# skill-sync Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a `/skill-sync` skill that installs, updates, harvests, removes, and reports status of skills from the private `coding-agent-skills` repo into project repos.

**Architecture:** A SKILL.md file defines the commands and dispatches to a bash script (`scripts/skill-sync.sh`) that handles all file operations. The script copies skill directories into `.shared/skills/` in project repos, creates symlinks for each agent platform, and tracks versions in `.shared/skills-manifest.json`.

**Tech Stack:** Bash, git, jq (for manifest JSON)

---

### Task 1: Create the SKILL.md

**Files:**
- Create: `agent-skills/skill-sync/SKILL.md`

**Step 1: Write the skill definition**

```markdown
---
name: skill-sync
description: Install, update, harvest, remove, and check status of skills from your private repo into project repos. Use when you want to share skills with a project, pull skill changes from a project, or check which skills are installed.
args: "<command> [skill] [--all]"
---

# Skill Sync

## Overview

Manage skills from your private repo (`coding-agent-skills`) in project repos. Skills are copied into `.shared/skills/` with symlinks for each agent platform. A manifest tracks versions for bidirectional sync.

## Arguments

- **command** (required): One of `install`, `update`, `harvest`, `remove`, `status`
- **skill** (required for install/update/harvest/remove): Name of the skill directory in `agent-skills/`
- **--all** (optional, update only): Update all skills listed in the manifest

## Commands

### install \<skill\>
Copy a skill from your private repo into the current project.
1. Verify skill exists in private repo at `agent-skills/<skill>/`.
2. Run the script: `skill-sync.sh install <skill>`
3. Report what was installed.

### update \<skill\> | --all
Pull newer version from private repo into project.
1. Run: `skill-sync.sh update <skill>` or `skill-sync.sh update --all`
2. Show the diff of what changed.
3. Report result.

### harvest \<skill\>
Diff project's version against last-synced and apply changes back to private repo.
1. Run: `skill-sync.sh harvest <skill>`
2. Review the diff shown.
3. If changes look good, confirm they were applied to the private repo.

### remove \<skill\>
Delete a skill from the project.
1. Run: `skill-sync.sh remove <skill>`
2. Report what was removed.

### status
Show all installed skills and their sync state.
1. Run: `skill-sync.sh status`
2. Display the table output.

## Script Location

The script lives at `scripts/skill-sync.sh` relative to this skill's directory.
Resolve the path from the skill directory:

```bash
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# or use known absolute path:
"/Users/mattmcmurry/coding-agent-skills/agent-skills/skill-sync/scripts/skill-sync.sh"
```

## Workflow

When invoked as `/skill-sync <command> [args]`, parse the command and arguments, then run the corresponding script command. Always show the script output to the user.
```

**Step 2: Commit**

```bash
git add agent-skills/skill-sync/SKILL.md
git commit -m "feat: add skill-sync SKILL.md definition"
```

---

### Task 2: Create the script — argument parsing and config

**Files:**
- Create: `agent-skills/skill-sync/scripts/skill-sync.sh`

**Step 1: Write the script skeleton with argument parsing and config resolution**

```bash
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
  # Make sure we're not inside the private repo itself
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
```

**Step 2: Make executable**

```bash
chmod +x agent-skills/skill-sync/scripts/skill-sync.sh
```

**Step 3: Commit**

```bash
git add agent-skills/skill-sync/scripts/skill-sync.sh
git commit -m "feat: add skill-sync script skeleton with arg parsing and helpers"
```

---

### Task 3: Implement the `install` command

**Files:**
- Modify: `agent-skills/skill-sync/scripts/skill-sync.sh`

**Step 1: Add the install function after the helpers section**

```bash
# --- Commands ---

cmd_install() {
  local skill="$1"
  require_private_repo
  require_project_repo
  skill_exists_in_private "$skill"

  # Check if already installed
  local existing_commit
  existing_commit="$(get_manifest_commit "$skill")"
  if [ -n "$existing_commit" ]; then
    die "Skill '$skill' is already installed (at commit $existing_commit). Use 'update' instead."
  fi

  local commit
  commit="$(get_private_commit)"
  local timestamp
  timestamp="$(now_iso)"

  # Copy skill files
  mkdir -p "$SHARED_DIR/$skill"
  cp -R "$PRIVATE_SKILLS/$skill/." "$SHARED_DIR/$skill/"
  echo "Copied $skill to $SHARED_DIR/$skill/"

  # Create symlinks for each agent platform
  for agent_dir in "${AGENT_DIRS[@]}"; do
    mkdir -p "$agent_dir"
    local rel_path
    rel_path="$(python3 -c "import os.path; print(os.path.relpath('$SHARED_DIR/$skill', '$agent_dir'))")"
    if [ -L "$agent_dir/$skill" ]; then
      rm "$agent_dir/$skill"
    fi
    ln -s "$rel_path" "$agent_dir/$skill"
    echo "Linked $agent_dir/$skill -> $rel_path"
  done

  # Update manifest
  local manifest
  manifest="$(read_manifest)"
  manifest="$(echo "$manifest" | jq --arg s "$skill" --arg c "$commit" --arg t "$timestamp" \
    '.skills[$s] = {"sourceCommit": $c, "installedAt": $t, "updatedAt": $t}')"
  write_manifest "$manifest"
  echo "Updated manifest: $skill at commit $commit"

  echo ""
  echo "Installed skill '$skill' from commit $commit"
}
```

**Step 2: Add the command dispatch at the bottom of the file**

```bash
# --- Dispatch ---
case "$COMMAND" in
  install)
    [ -n "$SKILL" ] || die "Usage: skill-sync.sh install <skill>"
    cmd_install "$SKILL"
    ;;
  *)
    die "Unknown command: $COMMAND. Expected: install, update, harvest, remove, status"
    ;;
esac
```

**Step 3: Test manually**

Create a temporary test project and run the install command:

```bash
mkdir -p /tmp/test-skill-sync && cd /tmp/test-skill-sync && git init
/Users/mattmcmurry/coding-agent-skills/agent-skills/skill-sync/scripts/skill-sync.sh install make-pr
```

Expected: Files copied to `.shared/skills/make-pr/`, symlinks in `.claude/skills/`, `.agents/skills/`, `.gemini/skills/`, manifest created.

```bash
cat .shared/skills-manifest.json
ls -la .claude/skills/make-pr
ls -la .shared/skills/make-pr/
```

**Step 4: Clean up test directory**

```bash
rm -rf /tmp/test-skill-sync
```

**Step 5: Commit**

```bash
git add agent-skills/skill-sync/scripts/skill-sync.sh
git commit -m "feat: implement skill-sync install command"
```

---

### Task 4: Implement the `status` command

**Files:**
- Modify: `agent-skills/skill-sync/scripts/skill-sync.sh`

**Step 1: Add the status function**

```bash
cmd_status() {
  require_private_repo
  require_project_repo

  local manifest
  manifest="$(read_manifest)"
  local skills
  skills="$(echo "$manifest" | jq -r '.skills | keys[]' 2>/dev/null)"

  if [ -z "$skills" ]; then
    echo "No skills installed in this project."
    return
  fi

  printf "%-20s %-12s %-12s %-15s %s\n" "Skill" "Installed" "Upstream" "Local Changes" "Status"
  printf "%-20s %-12s %-12s %-15s %s\n" "-----" "---------" "--------" "-------------" "------"

  while IFS= read -r skill; do
    local source_commit
    source_commit="$(echo "$manifest" | jq -r ".skills[\"$skill\"].sourceCommit")"

    # Check if upstream has changes
    local upstream_commit
    upstream_commit="$(get_private_commit)"
    local upstream_diff
    upstream_diff="$(git -C "$PRIVATE_REPO" diff --stat "$source_commit..HEAD" -- "agent-skills/$skill/" 2>/dev/null || echo "")"
    local upstream_changed="no"
    [ -z "$upstream_diff" ] || upstream_changed="yes"

    # Check if local has changes by diffing against the source commit version
    local local_changed="no"
    if [ -d "$SHARED_DIR/$skill" ]; then
      # Create temp dir with source commit version
      local tmp_dir
      tmp_dir="$(mktemp -d)"
      git -C "$PRIVATE_REPO" archive "$source_commit" -- "agent-skills/$skill" | tar -x -C "$tmp_dir" 2>/dev/null || true
      if [ -d "$tmp_dir/agent-skills/$skill" ]; then
        local local_diff
        local_diff="$(diff -rq "$tmp_dir/agent-skills/$skill" "$SHARED_DIR/$skill" 2>/dev/null || true)"
        [ -z "$local_diff" ] || local_changed="yes"
      fi
      rm -rf "$tmp_dir"
    else
      local_changed="missing"
    fi

    # Determine status
    local status="up to date"
    if [ "$upstream_changed" = "yes" ] && [ "$local_changed" = "yes" ]; then
      status="both changed"
    elif [ "$upstream_changed" = "yes" ]; then
      status="update available"
    elif [ "$local_changed" = "yes" ]; then
      status="locally modified"
    elif [ "$local_changed" = "missing" ]; then
      status="files missing"
    fi

    printf "%-20s %-12s %-12s %-15s %s\n" "$skill" "$source_commit" "$upstream_commit" "$local_changed" "$status"
  done <<< "$skills"
}
```

**Step 2: Add status to the dispatch case**

```bash
  status)
    cmd_status
    ;;
```

**Step 3: Test manually**

```bash
mkdir -p /tmp/test-skill-sync && cd /tmp/test-skill-sync && git init
/Users/mattmcmurry/coding-agent-skills/agent-skills/skill-sync/scripts/skill-sync.sh install make-pr
/Users/mattmcmurry/coding-agent-skills/agent-skills/skill-sync/scripts/skill-sync.sh status
```

Expected: Table showing `make-pr` as `up to date`.

**Step 4: Clean up and commit**

```bash
rm -rf /tmp/test-skill-sync
git add agent-skills/skill-sync/scripts/skill-sync.sh
git commit -m "feat: implement skill-sync status command"
```

---

### Task 5: Implement the `update` command

**Files:**
- Modify: `agent-skills/skill-sync/scripts/skill-sync.sh`

**Step 1: Add the update function**

```bash
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
    while IFS= read -r s; do
      cmd_update_single "$s"
    done <<< "$skills"
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

  # Check if there are upstream changes
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
```

**Step 2: Add update to the dispatch case**

```bash
  update)
    [ -n "$SKILL" ] || die "Usage: skill-sync.sh update <skill> | --all"
    cmd_update "$SKILL"
    ;;
```

**Step 3: Commit**

```bash
git add agent-skills/skill-sync/scripts/skill-sync.sh
git commit -m "feat: implement skill-sync update command"
```

---

### Task 6: Implement the `harvest` command

**Files:**
- Modify: `agent-skills/skill-sync/scripts/skill-sync.sh`

**Step 1: Add the harvest function**

```bash
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
```

**Step 2: Add harvest to the dispatch case**

```bash
  harvest)
    [ -n "$SKILL" ] || die "Usage: skill-sync.sh harvest <skill>"
    cmd_harvest "$SKILL"
    ;;
```

**Step 3: Commit**

```bash
git add agent-skills/skill-sync/scripts/skill-sync.sh
git commit -m "feat: implement skill-sync harvest command"
```

---

### Task 7: Implement the `remove` command

**Files:**
- Modify: `agent-skills/skill-sync/scripts/skill-sync.sh`

**Step 1: Add the remove function**

```bash
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
    fi
  done

  # Update manifest
  local manifest
  manifest="$(read_manifest)"
  manifest="$(echo "$manifest" | jq --arg s "$skill" 'del(.skills[$s])')"
  write_manifest "$manifest"
  echo "Removed $skill from manifest"

  # Clean up empty .shared/skills directory
  if [ -d "$SHARED_DIR" ] && [ -z "$(ls -A "$SHARED_DIR" 2>/dev/null)" ]; then
    rmdir "$SHARED_DIR"
    # Remove manifest if no skills left
    local remaining
    remaining="$(echo "$manifest" | jq '.skills | length')"
    if [ "$remaining" -eq 0 ] && [ -f "$MANIFEST" ]; then
      rm "$MANIFEST"
      echo "Removed empty manifest"
    fi
    # Clean up .shared if empty
    if [ -d ".shared" ] && [ -z "$(ls -A ".shared" 2>/dev/null)" ]; then
      rmdir ".shared"
    fi
  fi

  echo ""
  echo "Removed skill '$skill' from project"
}
```

**Step 2: Add remove to the dispatch case**

```bash
  remove)
    [ -n "$SKILL" ] || die "Usage: skill-sync.sh remove <skill>"
    cmd_remove "$SKILL"
    ;;
```

**Step 3: Commit**

```bash
git add agent-skills/skill-sync/scripts/skill-sync.sh
git commit -m "feat: implement skill-sync remove command"
```

---

### Task 8: Integration test — full round-trip

**Files:** None (manual testing)

**Step 1: Create a test project and run the full lifecycle**

```bash
mkdir -p /tmp/test-skill-sync && cd /tmp/test-skill-sync && git init

SCRIPT="/Users/mattmcmurry/coding-agent-skills/agent-skills/skill-sync/scripts/skill-sync.sh"

# Install
$SCRIPT install make-pr
echo "--- After install ---"
cat .shared/skills-manifest.json
ls -la .claude/skills/
ls -la .shared/skills/make-pr/

# Status
echo "--- Status ---"
$SCRIPT status

# Modify the installed skill (simulate teammate edit)
echo "# Modified by teammate" >> .shared/skills/make-pr/SKILL.md

# Status again (should show locally modified)
echo "--- Status after local edit ---"
$SCRIPT status

# Harvest
echo "--- Harvest ---"
$SCRIPT harvest make-pr

# Remove
echo "--- Remove ---"
$SCRIPT remove make-pr

# Status (should show empty)
echo "--- Status after remove ---"
$SCRIPT status

echo "--- Directory structure ---"
find . -not -path './.git/*' -not -path './.git' | sort
```

**Step 2: Verify all output is correct**

- Install: files copied, symlinks created, manifest populated
- Status: shows `up to date` initially, `locally modified` after edit
- Harvest: shows the diff, copies files back to private repo
- Remove: cleans up files, symlinks, manifest

**Step 3: Clean up**

```bash
rm -rf /tmp/test-skill-sync
# Revert any harvest changes to private repo
cd /Users/mattmcmurry/coding-agent-skills && git checkout -- agent-skills/make-pr/
```

**Step 4: Commit (if any fixes were needed)**

```bash
git add agent-skills/skill-sync/
git commit -m "fix: integration test fixes for skill-sync"
```

---

### Task 9: Run sync-skills.sh to install skill-sync locally

**Files:** None (run existing script)

**Step 1: Run the sync script**

```bash
/Users/mattmcmurry/coding-agent-skills/agent-skills/sync-skills.sh
```

Expected: `skill-sync` appears in the linked skills list.

**Step 2: Verify the symlink**

```bash
ls -la ~/.claude/skills/skill-sync
```

Expected: symlink pointing to `coding-agent-skills/agent-skills/skill-sync/`

**Step 3: Final commit and push**

```bash
cd /Users/mattmcmurry/coding-agent-skills
git add -A
git status
# If there are changes, commit
git commit -m "feat: complete skill-sync skill for bidirectional skill distribution"
git push origin HEAD
```
