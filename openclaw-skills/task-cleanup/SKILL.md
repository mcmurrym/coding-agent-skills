---
name: task-cleanup
description: "Clean up completed task working copies created by launch-task. Verifies PRs are merged before removing working copy directories. Use when the user wants to clean up tasks, free disk space, or says 'task cleanup'."
compatibility: Requires gh CLI. Designed for macOS (Darwin).
metadata:
  author: openclaw
  version: "1.0"
  openclaw: '{"os": ["darwin"], "requires": {"bins": ["gh"]}}'
---

# Task Cleanup

## Overview

Removes working copy directories for completed tasks. Verifies PRs are merged before cleanup to prevent data loss.

## Prerequisites

- `$WORKSPACE_ROOT` must be set (see launch-task Environment Configuration)
- Task state files exist in `$WORKSPACE_ROOT/tasks/_state/`

## Workflow

Accept an optional issue key argument. If not provided, clean up all tasks with status `completed`.

### For each task to clean up:

1. Read the state file at `$WORKSPACE_ROOT/tasks/_state/{issue-key}.json`.

2. If a `prUrl` exists, verify the PR is merged:
   ```bash
   gh pr view <prUrl> --json state --jq '.state'
   ```

3. If merged:
   - Remove the working copy directory.
   - Update state `status` to `cleaned`.
   - Report: "Cleaned up **{issue-key}** — PR merged."

4. If NOT merged:
   - Warn the user: "**{issue-key}** has an open PR at `<prUrl>`. Clean up anyway?"
   - Only proceed if the user confirms.

5. If no `prUrl` exists and status is `failed`:
   - Warn the user: "**{issue-key}** failed without creating a PR. The working copy at `<workDir>` will be deleted."
   - Only proceed if the user confirms.

## Safety Notes

- Never delete the `_state/` directory or state files — only update the `status` field.
- Working copies are fully disposable. Cleaning them up loses nothing that isn't already pushed.
