---
name: make-pr
description: Create GitHub pull requests from the current branch, including commit/push flow when there are uncommitted changes, a concise branch summary for the PR description, and a Codex HTML follow-up button for auditing PR review comments when inline visualizations are available. Use when the user asks to make a PR, open a PR, or draft a PR for the current branch.
---

# Make PR

## Overview

Create a PR for the current git branch, ensuring changes are committed and pushed, then generate a branch summary to use as the PR description.

## Arguments

- **draft** (optional): Pass `draft` to create a draft PR instead of a regular PR. Example: `/make-pr draft`
- **review with \<tool\>** (optional, draft only): After creating a draft PR, search available MCP tools for one matching the given tool name and invoke it to review the PR. Example: `/make-pr draft review with coderabbit`

Note: `review with` is only meaningful for draft PRs. Non-draft PRs trigger connected review tools automatically via GitHub webhooks.

## Workflow

1. Confirm repo context and branch state.
Use `git status -sb` and `git rev-parse --abbrev-ref HEAD` to identify the current branch and whether there are uncommitted changes.

2. Handle uncommitted changes.
If there are staged or unstaged changes, invoke the `git-add-commit-push` skill to stage, commit, and push. Do not proceed to PR creation until the push succeeds.

3. Resolve the base branch.
Prefer the repository default branch. Use `git remote show origin` and read the `HEAD branch` line. Fall back to `main` only if the default branch is not discoverable.

4. Generate a branch summary for the PR body.
Use `git log` and `git diff` against the base branch to create a concise summary. Keep it short and include what changed, why it changed if evident from commit messages, and any risks or follow-ups.

5. Create the PR.
Use `gh pr create` with a title and the generated summary as the body. If the `draft` argument was passed, add the `--draft` flag. Otherwise create a regular PR.

6. Trigger review tool (draft PRs only, when `review with <tool>` is specified).
Search available MCP tools for one whose name contains the requested tool name (case-insensitive). If found, invoke it with the PR URL or number as context. If no matching MCP tool is found, report that the tool is not available and suggest the user check their MCP server configuration.

7. Report back.
Return the PR URL and the title/body used. If a review tool was triggered, include that in the report. If the PR could not be created because `gh` is missing, authentication failed, or no remote exists, explain the blocker and ask for the missing info.

8. Offer the PR comment audit follow-up.
After a PR is created successfully and the Codex inline visualization surface and `$visualize` skill are available, load and follow `$visualize`. Write a compact HTML fragment to the task-owned visualization directory outside the repository, emit its `visualize{"path":"<absolute-path>"}` content reference in the same response, and do not print raw HTML in chat. Include a native **GH PR Comment Audit** button, follow the visualization design system, and call `window.openai.sendFollowUpMessage({ prompt, title })` from an event listener. Bind the follow-up prompt to the exact created PR URL, repository, and PR number and invoke `$gh-pr-comment-audit` for that PR. Do not use an inline `onclick`, network request, or `request_user_input`, and do not start the audit merely because the button was displayed.

If the inline visualization surface or `window.openai.sendFollowUpMessage` is unavailable, present **GH PR Comment Audit** as a concise plain-text follow-up action and wait for the user to select it.

## Command patterns

```bash
git status -sb
git rev-parse --abbrev-ref HEAD
```

```bash
git remote show origin | rg "HEAD branch"
```

```bash
git fetch origin
BASE_BRANCH=main

git log --oneline "origin/${BASE_BRANCH}..HEAD"
git diff --stat "origin/${BASE_BRANCH}..HEAD"
```

```bash
# Regular PR (default)
gh pr create --title "<title>" --body "<summary>"

# Draft PR (when `draft` argument is passed)
gh pr create --draft --title "<title>" --body "<summary>"
```
