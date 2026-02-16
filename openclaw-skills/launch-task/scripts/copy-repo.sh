#!/usr/bin/env bash
set -euo pipefail

# copy-repo.sh — Copy a master repo to a task working directory.
#
# Usage: copy-repo.sh <source-repo-path> <destination-path>
#
# Steps:
#   1. Validates the source repo exists and is on the main branch.
#   2. Pulls the latest changes (fetch --prune + pull --ff-only).
#   3. Copies the repo (APFS clone on macOS via cp -c, hardlink on Linux via cp -al).
#   4. Runs pnpm install in the destination.
#   5. Verifies the copy has a valid .git directory.

SOURCE="${1:?Usage: copy-repo.sh <source-repo-path> <destination-path>}"
DEST="${2:?Usage: copy-repo.sh <source-repo-path> <destination-path>}"

# --- Validate source ---
if [ ! -d "$SOURCE/.git" ]; then
  echo "ERROR: $SOURCE is not a git repository." >&2
  exit 1
fi

CURRENT_BRANCH=$(git -C "$SOURCE" rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
  echo "ERROR: Source repo is on branch '$CURRENT_BRANCH', expected 'main'." >&2
  exit 1
fi

# Check for uncommitted changes in source
if ! git -C "$SOURCE" diff --quiet || ! git -C "$SOURCE" diff --cached --quiet; then
  echo "ERROR: Source repo has uncommitted changes. Aborting." >&2
  exit 1
fi

# --- Pull latest ---
echo "Fetching and pulling latest for $(basename "$SOURCE")..."
git -C "$SOURCE" fetch --prune
if ! git -C "$SOURCE" pull --ff-only; then
  echo "ERROR: pull --ff-only failed. Source repo may have diverged." >&2
  exit 1
fi

# --- Validate destination does not exist ---
if [ -d "$DEST" ]; then
  echo "ERROR: Destination $DEST already exists." >&2
  exit 1
fi

# --- Copy ---
# macOS APFS: cp -c uses clonefile(2) — instant copy-on-write, no data copied until modified.
# Linux: cp -al uses hardlinks for fast copies.
# Falls back to cp -a if neither is available.
echo "Copying $(basename "$SOURCE") to $DEST..."
if [ "$(uname)" = "Darwin" ] && cp -cRp "$SOURCE" "$DEST" 2>/dev/null; then
  echo "APFS clone succeeded (instant copy-on-write)."
elif [ "$(uname)" = "Linux" ] && cp -al "$SOURCE" "$DEST" 2>/dev/null; then
  echo "Hardlink copy succeeded (Linux)."
else
  cp -a "$SOURCE" "$DEST"
  echo "Full copy completed (fallback)."
fi

# --- Verify copy ---
if [ ! -d "$DEST/.git" ]; then
  echo "ERROR: Copy failed — $DEST/.git does not exist." >&2
  exit 1
fi

# --- Install dependencies ---
if [ -f "$DEST/pnpm-lock.yaml" ] || [ -f "$DEST/package.json" ]; then
  echo "Installing dependencies..."
  (cd "$DEST" && pnpm install)
fi

echo "Done. Working copy ready at $DEST"
