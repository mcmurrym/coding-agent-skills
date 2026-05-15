---
name: git-add-commit-push
description: Stage, commit, and push Git changes in a single, repeatable zero-input flow. Use when asked to run `git add`, `git commit`, and `git push` together with no prompts, or when you need to stage all changes, auto-generate a commit message from the diff, commit, and push to the current branch.
---

# Git Add Commit Push

## Overview

Run a zero-input workflow to stage all changes, generate a commit message from the current diff, commit, and push to the current branch on `origin`.

## Workflow

1. Summarize changes and auto-generate a commit message.
- Run `git status -sb` and `git diff --stat`.
- Use `git diff` to understand the actual change content.
- Draft a commit message automatically based on the diff.

2. Run the scripted flow (recommended).
- Resolve the script path from the skill directory, then run it directly:
  - `"$CODEX_HOME/skills/git-add-commit-push/scripts/git-add-commit-push.sh"`
  - If `CODEX_HOME` is unavailable, use the known absolute path:
    - `"/Users/mattmcmurry/.codex/skills/git-add-commit-push/scripts/git-add-commit-push.sh"`
- Run with no arguments for the zero-input flow.
- Use `--dry-run` only if you need a preview, otherwise proceed directly.

3. Verify result.
- Re-run `git status -sb`.
- Share the new commit hash.

## Script Usage

Use the bundled script for consistency:

```bash
"$CODEX_HOME/skills/git-add-commit-push/scripts/git-add-commit-push.sh" [--dry-run] [--no-push] [-r origin] [-b branch] [-m "message"]
```

Behavior:
- Stages all changes with `git add -A`
- Commits with an auto-generated message (or provided `-m`)
- Pushes to `origin` on the current branch unless overridden or `--no-push` is set
- Refuses to run if there are no changes

## Manual Fallback

If you cannot run the script:

```bash
git status -sb
git diff --stat
git add -A
git commit -m "message"
git push origin HEAD
```

## Safety Notes

- Never commit secrets or real `.env` values. Template files such as `.env.example`, `.env.sample`, and `.env.template` may be committed.
- This skill is for full staging only; do not use it for partial staging.
