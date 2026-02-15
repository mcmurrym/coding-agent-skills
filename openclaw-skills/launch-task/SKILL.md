---
name: launch-task
description: "Launch a Linear issue as a background task: provision an isolated working copy from the master repo, launch Claude CLI to execute kit-and-kaboodle, and track the task to completion. Supports multiple concurrent tasks."
---

# Start Task

## Overview

Orchestrates end-to-end task execution for Linear issues. Provisions an isolated working copy of the source repo, launches Claude CLI to run `kit-and-kaboodle`, and tracks the task through completion. Multiple tasks can run concurrently.

## Prerequisites

- Master repos live in `workspace/Developer/` (e.g. `coverpanda-app/`, `Postee/`)
- Master repos are always on `main`, never modified directly — only pulled
- Claude CLI is installed and available as `claude`
- `pnpm` is installed globally

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

Check `workspace/Developer/tasks/_state/repo-map.json` for a mapping from this Linear team prefix to a local master repo.

If `repo-map.json` does not exist or the team is not mapped:

1. List directories in `workspace/Developer/` (exclude `tasks/` and `coding-agent-skills/`).
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
git fetch --prune
git pull --ff-only
```

If pull fails (diverged state, dirty working tree), **stop and report the problem**. Never modify the master repo beyond pulling.

### Step 4: Create the working copy

Use the bundled script to create a hardlink copy:

```bash
"$SKILL_DIR/scripts/copy-repo.sh" "workspace/Developer/<repo>" "workspace/Developer/tasks/<issue-key-slug>/"
```

The slug is derived from the issue key and title: lowercase, hyphenated, punctuation removed. Example: `cp-123-fix-login-bug`.

The script will:
- Validate the source is on `main` with no uncommitted changes
- Pull latest
- Hardlink-copy with `cp -al` (falls back to `cp -a`)
- Run `pnpm install` in the copy
- Verify `.git` exists in the copy

### Step 5: Write initial task state

Create `workspace/Developer/tasks/_state/{issue-key}.json`:

```json
{
  "issueKey": "CP-123",
  "issueUrl": "https://linear.app/team/issue/CP-123",
  "repo": "coverpanda-app",
  "workDir": "workspace/Developer/tasks/cp-123-fix-login-bug/",
  "status": "starting",
  "startedAt": "2026-02-12T00:00:00Z",
  "agentType": "claude",
  "agentSessionId": null,
  "prUrl": null,
  "completedAt": null,
  "error": null
}
```

### Step 6: Launch Claude CLI

Run Claude in the background via the exec tool:

```bash
exec background:true pty:true workdir:<absolute-path-to-working-copy> command:"claude --dangerously-skip-permissions -p '/kit-and-kaboodle <linear-url>'"
```

Capture the returned `sessionId` and update the state file:
- Set `status` to `running`
- Set `agentSessionId` to the session ID

Report to the user: "**{issue-key}** is now running. Agent is executing kit-and-kaboodle in `tasks/{slug}/`."

### Step 7: Track until completion

When polled (via `/taskStatus` or heartbeat), check if the Claude session has completed:

```bash
process action:poll sessionId:<sessionId>
```

On completion:
- If a PR was created: set `status` to `completed`, capture `prUrl`, set `completedAt`.
- If kit-and-kaboodle failed (15-attempt limit): set `status` to `failed`, capture `error` details.

**On failure:**
1. Post failure details as a **comment on the Linear issue** via the Linear MCP:
   - Last test output / error
   - Number of attempts made
   - What was tried
2. Send a **message to the user** via the current messaging channel (WhatsApp/Slack) with a summary of the failure.

### Step 8: Auto-cleanup on heartbeat

During heartbeat cycles, check all tasks with status `completed`:

1. Read the `prUrl` from the state file.
2. Check if the PR is merged: `gh pr view <prUrl> --json state`
3. If merged:
   - Remove the working copy directory.
   - Update state `status` to `cleaned`.

---

## Additional Commands

### `/taskStatus` — Check on running tasks

1. Read all `.json` files in `workspace/Developer/tasks/_state/` (skip `repo-map.json`).
2. For tasks with status `running`, poll the background session:
   ```bash
   process action:poll sessionId:<sessionId>
   ```
3. Present a status table:
   ```
   | Issue   | Repo           | Status    | Started           | PR               |
   |---------|----------------|-----------|-------------------|------------------|
   | CP-123  | coverpanda-app | running   | 2026-02-12 10:30  | —                |
   | CP-456  | coverpanda-app | completed | 2026-02-12 09:00  | github.com/...   |
   ```
4. If a running task has actually completed, update its state file accordingly.

### `/taskCleanup {issue-key}` — Manual cleanup

1. Read the state file for the given issue key.
2. If a PR exists, verify it is merged via `gh pr view`.
3. Remove the working copy directory.
4. Update state `status` to `cleaned`.
5. If the PR is not merged, warn the user and ask for confirmation before cleaning up.

## Safety Notes

- Never modify master repos beyond `git fetch` and `git pull --ff-only`.
- If the master repo has uncommitted changes or is not on `main`, stop and report — do not attempt to fix it.
- Working copies are fully disposable. Cleaning them up loses nothing that isn't already pushed.
- The `_state/` directory is the source of truth for task tracking. Do not delete it during cleanup — only update status fields.
