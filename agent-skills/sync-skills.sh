#!/usr/bin/env bash
# sync-skills.sh — Sync shared skills to Claude Code and Codex CLI
#
# Claude Code:  ~/.claude/skills/ (directory symlink to this repo)
# Codex CLI:    ~/.codex/skills/  (per-skill symlinks, preserves .system/)
#
# Usage: ./sync-skills.sh

set -euo pipefail

SHARED_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_SKILLS="$HOME/.claude/skills"
CODEX_SKILLS="$HOME/.codex/skills"

echo "Shared skills directory: $SHARED_DIR"

# --- Claude Code ---
if [ -L "$CLAUDE_SKILLS" ]; then
  target=$(readlink "$CLAUDE_SKILLS")
  if [ "$target" = "$SHARED_DIR" ]; then
    echo "Claude Code: symlink OK -> $SHARED_DIR"
  else
    echo "Claude Code: updating symlink from $target -> $SHARED_DIR"
    rm "$CLAUDE_SKILLS"
    ln -s "$SHARED_DIR" "$CLAUDE_SKILLS"
  fi
elif [ -d "$CLAUDE_SKILLS" ]; then
  echo "Claude Code: WARNING — ~/.claude/skills/ is a real directory, not a symlink."
  echo "  To fix: mv ~/.claude/skills ~/.claude/skills.bak && ln -s $SHARED_DIR ~/.claude/skills"
else
  ln -s "$SHARED_DIR" "$CLAUDE_SKILLS"
  echo "Claude Code: created symlink -> $SHARED_DIR"
fi

# --- Codex CLI ---
if [ ! -d "$CODEX_SKILLS" ]; then
  echo "Codex CLI: ~/.codex/skills/ does not exist, skipping."
else
  added=0
  removed=0

  # Remove stale symlinks (broken or pointing outside SHARED_DIR)
  for link in "$CODEX_SKILLS"/*; do
    [ -L "$link" ] || continue
    target=$(readlink "$link")
    if [ ! -e "$link" ] || [[ "$target" != "$SHARED_DIR"/* ]]; then
      name=$(basename "$link")
      rm "$link"
      echo "Codex CLI: removed stale link $name"
      ((removed++))
    fi
  done

  # Add missing symlinks
  for skill_dir in "$SHARED_DIR"/*/; do
    [ -d "$skill_dir" ] || continue
    name=$(basename "$skill_dir")
    [ "$name" = ".git" ] && continue
    link="$CODEX_SKILLS/$name"
    if [ ! -e "$link" ]; then
      ln -s "$skill_dir" "$link"
      echo "Codex CLI: linked $name"
      ((added++))
    fi
  done

  if [ "$added" -eq 0 ] && [ "$removed" -eq 0 ]; then
    echo "Codex CLI: all symlinks up to date"
  else
    echo "Codex CLI: added $added, removed $removed"
  fi
fi

echo ""
echo "Skills available:"
for skill_dir in "$SHARED_DIR"/*/; do
  [ -d "$skill_dir" ] || continue
  name=$(basename "$skill_dir")
  [ "$name" = ".git" ] && continue
  echo "  - $name"
done
