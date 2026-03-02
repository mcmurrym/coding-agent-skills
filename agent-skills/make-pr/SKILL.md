---
name: make-pr
description: Create GitHub pull requests from the current branch, including commit/push flow when there are uncommitted changes and a concise branch summary for the PR description. Use when the user asks to make a PR, open a PR, or draft a PR for the current branch.
args: "[draft]"
---

# Make PR

## Overview

Create a PR for the current git branch, ensuring changes are committed and pushed, then generate a branch summary to use as the PR description.

## Arguments

- **draft** (optional): Pass `draft` to create a draft PR instead of a regular PR. Example: `/make-pr draft`

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

6. Report back.
Return the PR URL and the title/body used. If the PR could not be created because `gh` is missing, authentication failed, or no remote exists, explain the blocker and ask for the missing info.

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
