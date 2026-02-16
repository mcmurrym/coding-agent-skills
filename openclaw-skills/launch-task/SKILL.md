---
name: launch-task
description: "Orchestrate background task execution: provision an isolated working copy from a master repo, spawn a Claude Code agent to work on a Linear issue via kit-and-kaboodle, and track the task through completion. Use when the user wants to launch a task, run an issue in the background, or start automated delivery for a Linear ticket."
compatibility: Requires git, pnpm, gh CLI, and Claude Code CLI. Designed for macOS (Darwin).
metadata:
  author: openclaw
  version: "1.0"
  openclaw: '{"os": ["darwin"], "requires": {"bins": ["git", "pnpm", "gh", "claude"]}}'
---

# Launch Task

## Overview

Provisions an isolated working copy of a source repo and spawns a Claude Code agent in the background to execute `kit-and-kaboodle` for a Linear issue. Multiple tasks can run concurrently.

This skill only handles launching. Use `/task-status` to check on running tasks and `/task-cleanup` to remove completed working copies.

## Prerequisites

- `$WORKSPACE_ROOT` must be set (see Environment Configuration below)
- Master repos live in `$WORKSPACE_ROOT/` (e.g. `coverpanda-app/`, `Postee/`)
- Master repos are always on `main`, never modified directly — only pulled
- Claude Code CLI is installed and available as `claude`
- `pnpm` is installed globally

## Environment Configuration

Set `WORKSPACE_ROOT` in `~/.openclaw/openclaw.json`:

```json
{
  "skills": {
    "launch-task": {
      "env": {
        "WORKSPACE_ROOT": "/Users/agent1/.openclaw/workspace/Developer"
      }
    }
  }
}
```

This env var is also used by `task-status` and `task-cleanup`. Set it for all three skills.

## Workflow

**Follow these steps in order. Do not skip steps.**

### Step 1: Parse the Linear URL

Accept a Linear issue URL or issue key from the user.

Extract the issue key (e.g. `CP-123`) and the team prefix (e.g. `CP`).

If the input is missing or invalid, ask for it before continuing.

**Immediately after parsing**, send a message to the user:

> "Got it — picking up **{issue-key}**. Setting up the working copy now…"

This acknowledgment must be sent **before** any git or file operations begin. Do not wait.

### Step 2: Resolve the repo mapping

Check `$WORKSPACE_ROOT/tasks/_state/repo-map.json` for a mapping from this Linear team prefix to a local master repo.

If `repo-map.json` does not exist or the team is not mapped:

1. List directories in `$WORKSPACE_ROOT/` (exclude `tasks/`).
2. Ask the user which repo this Linear team maps to.
3. Save the mapping to `repo-map.json`:

```json
{
  "mappings": [
    {
      "linearTeam": "CP",
      "repoPath": "coverpanda-app",
      "addedAt": "2026-02-12T00:00:00Z"
    }
  ]
}
```

### Step 3: Ensure master repo is current

Run the following in the master repo directory:

```bash
git -C "$WORKSPACE_ROOT/<repo>" fetch --prune
git -C "$WORKSPACE_ROOT/<repo>" pull --ff-only
```

If pull fails (diverged state, dirty working tree), **stop and report the problem**. Never modify the master repo beyond pulling.

### Step 4: Create the working copy

Use the bundled script to create a copy:

```bash
"$SKILL_DIR/scripts/copy-repo.sh" "$WORKSPACE_ROOT/<repo>" "$WORKSPACE_ROOT/tasks/<issue-key-slug>/"
```

The slug is derived from the issue key and title: lowercase, hyphenated, punctuation removed. Example: `cp-123-fix-login-bug`.

The script will:
- Validate the source is on `main` with no uncommitted changes
- Pull latest
- Copy the repo (APFS clone on macOS, hardlink on Linux)
- Run `pnpm install` in the copy
- Verify `.git` exists in the copy

### Step 5: Write initial task state

Create `$WORKSPACE_ROOT/tasks/_state/{issue-key}.json`:

```json
{
  "issueKey": "CP-123",
  "issueUrl": "https://linear.app/team/issue/CP-123",
  "repo": "coverpanda-app",
  "workDir": "$WORKSPACE_ROOT/tasks/cp-123-fix-login-bug/",
  "status": "starting",
  "startedAt": "2026-02-12T00:00:00Z",
  "agentType": "claude",
  "agentSessionId": null,
  "prUrl": null,
  "completedAt": null,
  "error": null
}
```

### Step 6: Launch Claude Code

Spawn Claude Code in the background using the coding-agent pattern. PTY mode is required — Claude Code is an interactive terminal application.

```bash
bash pty:true background:true workdir:<absolute-path-to-working-copy> command:"claude --dangerously-skip-permissions -p '/kit-and-kaboodle <linear-url>'"
```

Capture the returned `sessionId` and update the state file:
- Set `status` to `running`
- Set `agentSessionId` to the session ID

Report to the user: "**{issue-key}** is now running. Agent is executing kit-and-kaboodle in `tasks/{slug}/`."

## Safety Notes

- Never modify master repos beyond `git fetch` and `git pull --ff-only`.
- If the master repo has uncommitted changes or is not on `main`, stop and report — do not attempt to fix it.
- Working copies are fully disposable. Cleaning them up loses nothing that isn't already pushed.
- The `_state/` directory is the source of truth for task tracking. Do not delete it during cleanup — only update status fields.
