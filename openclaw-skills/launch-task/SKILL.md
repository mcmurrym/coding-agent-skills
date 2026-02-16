---
name: launch-task
description: "Orchestrate background task execution: provision an isolated working copy from a master repo, launch Claude Code to work on a Linear issue via kit-and-kaboodle, and track the task through completion. Use when the user wants to launch a task, run an issue in the background, or start automated delivery for a Linear ticket."
compatibility: Requires git, pnpm, gh CLI, and Claude Code CLI. Designed for macOS (Darwin).
metadata:
  author: openclaw
  version: "1.0"
  openclaw: '{"os": ["darwin"], "requires": {"bins": ["git", "pnpm", "gh", "claude"]}}'
---

# Launch Task

## Overview

Provisions an isolated working copy of a source repo and launches Claude Code as a background process to execute `kit-and-kaboodle` for a Linear issue. Multiple tasks can run concurrently.

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

### Step 0: Validate environment

Verify `$WORKSPACE_ROOT` is set. If not, **stop** and tell the user to configure it (see Environment Configuration above).

Ensure the tasks and state directories exist:
```bash
mkdir -p "$WORKSPACE_ROOT/tasks/_state"
```

### Step 1: Parse the Linear URL

Accept a Linear issue URL or issue key from the user.

Linear URLs follow this structure:
```
https://linear.app/{org}/issue/{TEAM}-{number}/{optional-slug}
```

For example, `https://linear.app/coverpanda/issue/ENG-88/fix-login-bug`:
- **org** = `coverpanda` (the Linear organization)
- **team** = `ENG` (the team within that org)
- **issue key** = `ENG-88`

Extract the **issue key** (e.g. `ENG-88`) and the **team prefix** (e.g. `ENG`).

If the input is a bare issue key (e.g. `ENG-88`) without a URL, accept it but note that the full URL will be needed for kit-and-kaboodle later.

If the input is missing or invalid, ask for it before continuing.

**Immediately after parsing**, send a message to the user:

> "Got it — picking up **{issue-key}**. Setting up the working copy now…"

This acknowledgment must be sent **before** any git or file operations begin. Do not wait.

### Step 2: Resolve the repo mapping

Check `$WORKSPACE_ROOT/tasks/_state/repo-map.json` for a mapping from this Linear **team prefix** to a local master repo directory.

The mapping connects a Linear team (e.g. `ENG`) to a cloned git repo that lives in `$WORKSPACE_ROOT/` (e.g. `coverpanda-app/`). Multiple teams can map to the same repo.

If `repo-map.json` does not exist or the team is not mapped:

1. List directories in `$WORKSPACE_ROOT/` that are git repos (contain a `.git` directory). Exclude `tasks/`.
2. Ask the user which repo this Linear team maps to.
3. Save the mapping to `repo-map.json`:

```json
{
  "mappings": [
    {
      "linearTeam": "ENG",
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

Run Claude Code as a background process using the **bash tool** — do NOT use `sessions_spawn`. PTY mode is required because Claude Code is an interactive terminal application.

```
bash pty:true background:true workdir:<absolute-path-to-working-copy> command:"claude --dangerously-skip-permissions -p '/kit-and-kaboodle <linear-url>'"
```

This uses the bash tool with `pty:true` and `background:true` parameters, following the coding-agent pattern. The bash tool will return a `sessionId`.

Capture the returned `sessionId` and update the state file:
- Set `status` to `running`
- Set `agentSessionId` to the session ID

To check on the process later, use:
```
process action:poll sessionId:<sessionId>
process action:log sessionId:<sessionId>
```

Report to the user: "**{issue-key}** is now running. Agent is executing kit-and-kaboodle in `tasks/{slug}/`."

## Safety Notes

- Never modify master repos beyond `git fetch` and `git pull --ff-only`.
- If the master repo has uncommitted changes or is not on `main`, stop and report — do not attempt to fix it.
- Working copies are fully disposable. Cleaning them up loses nothing that isn't already pushed.
- The `_state/` directory is the source of truth for task tracking. Do not delete it during cleanup — only update status fields.
