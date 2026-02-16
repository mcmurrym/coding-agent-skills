---
name: task-status
description: "Check the status of background tasks launched by launch-task. Polls running agent sessions, updates state files on completion or failure, and presents a summary table. Use when the user asks about running tasks, task progress, or says 'task status'."
compatibility: Requires gh CLI. Designed for macOS (Darwin).
metadata:
  author: openclaw
  version: "1.0"
  openclaw: '{"os": ["darwin"], "requires": {"bins": ["gh"]}}'
---

# Task Status

## Overview

Checks on all tasks launched by `/launch-task`. Polls running agent sessions, updates state files when tasks complete or fail, and presents a summary.

## Prerequisites

- `$WORKSPACE_ROOT` must be set (see launch-task Environment Configuration)
- Task state files exist in `$WORKSPACE_ROOT/tasks/_state/`

## Workflow

### Step 1: Read task state files

Read all `.json` files in `$WORKSPACE_ROOT/tasks/_state/` (skip `repo-map.json`).

If no state files exist, report: "No tasks found."

### Step 2: Poll running sessions

For each task with status `running`, poll the background session:

```bash
process action:poll sessionId:<agentSessionId>
```

### Step 3: Update completed tasks

If a polled session has completed:

- Check the session output or working copy for a PR URL.
- If a PR was created: set `status` to `completed`, capture `prUrl`, set `completedAt`.
- If the agent failed: set `status` to `failed`, capture error details in the `error` field.

### Step 4: Present status table

```
| Issue   | Repo           | Status    | Started           | PR               |
|---------|----------------|-----------|-------------------|------------------|
| CP-123  | coverpanda-app | running   | 2026-02-12 10:30  | —                |
| CP-456  | coverpanda-app | completed | 2026-02-12 09:00  | github.com/...   |
| CP-789  | coverpanda-app | failed    | 2026-02-12 08:00  | —                |
```

If any tasks failed, include the error summary below the table.
