---
name: back-to-main
description: Switch a repository back to the main branch and sync it with origin using a pruning fetch and pull. Use when finishing work on a feature branch and preparing to return to up-to-date main.
---

# Back To Main

Run this workflow in the target repo:

1. Run `git fetch --prune`.
2. Run `git checkout main`.
3. Run `git pull --ff-only`.

If `git checkout main` fails because `main` does not exist locally, run:

1. `git checkout -b main --track origin/main`
2. `git pull --ff-only`

If pull fails due to local changes, stop and report the blocking files. Do not stash, reset, or discard changes unless explicitly requested.
