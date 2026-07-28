---
name: skill-sync
description: Install, update, harvest, remove, and check status of skills from your private repo into project repos. Use when you want to share skills with a project, pull skill changes from a project, or check which skills are installed.
---

# Skill Sync

## Overview

Manage skills from your private repo (`coding-agent-skills`) in project repos. Skills are copied into `.shared/skills/` with symlinks for each agent platform. A manifest tracks versions for bidirectional sync.

## Arguments

- **command** (required): One of `install`, `update`, `harvest`, `remove`, `status`
- **skill** (required for install/update/harvest/remove): Name of the skill directory in `agent-skills/`
- **--all** (optional, update only): Update all skills listed in the manifest

## Commands

### install <skill>
Copy a skill from your private repo into the current project.
1. Verify skill exists in private repo at `agent-skills/<skill>/`.
2. Run the script: `skill-sync.sh install <skill>`
3. Report what was installed.

### update <skill> | --all
Pull newer version from private repo into project.
1. Run: `skill-sync.sh update <skill>` or `skill-sync.sh update --all`
2. Show the diff of what changed.
3. Report result.

### harvest <skill>
Diff project's version against last-synced and apply changes back to private repo.
1. Run: `skill-sync.sh harvest <skill>`
2. Review the diff shown.
3. If changes look good, confirm they were applied to the private repo.

### remove <skill>
Delete a skill from the project.
1. Run: `skill-sync.sh remove <skill>`
2. Report what was removed.

### status
Show all installed skills and their sync state.
1. Run: `skill-sync.sh status`
2. Display the table output.

## Script Location

Resolve the directory containing this `SKILL.md`, then use its bundled script:

```bash
SKILL_SYNC_SCRIPT="<skill-directory>/scripts/skill-sync.sh"
"$SKILL_SYNC_SCRIPT" <command> [skill] [--all]
```

## Workflow

When invoked as `/skill-sync <command> [args]`, parse the command and arguments, then run the corresponding script command. Always show the script output to the user.
