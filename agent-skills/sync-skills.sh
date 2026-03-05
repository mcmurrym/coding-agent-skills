#!/usr/bin/env bash
# sync-skills.sh — Sync shared skills to Claude Code, Codex CLI, and Gemini CLI
#
# Claude Code:  ~/.claude/skills/ (per-skill symlinks)
# Codex CLI:    ~/.codex/skills/  (per-skill symlinks, preserves .system/)
# Gemini CLI:   ~/.gemini/skills/ (per-skill symlinks)
#
# Usage: ./sync-skills.sh

set -euo pipefail

SHARED_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_SKILLS="$HOME/.claude/skills"
CODEX_SKILLS="$HOME/.codex/skills"
GEMINI_SKILLS="$HOME/.gemini/skills"

echo "Shared skills directory: $SHARED_DIR"

# --- Claude Code ---
# If the skills dir is a whole-directory symlink from a previous version, replace it
if [ -L "$CLAUDE_SKILLS" ]; then
  echo "Claude Code: replacing whole-directory symlink with per-skill symlinks"
  rm "$CLAUDE_SKILLS"
fi

mkdir -p "$CLAUDE_SKILLS"

added=0
removed=0

# Remove stale symlinks (broken, or pointing into SHARED_DIR for a skill that no longer exists)
for link in "$CLAUDE_SKILLS"/*; do
  [ -L "$link" ] || continue
  target=$(readlink "$link")
  if [ ! -e "$link" ]; then
    # Broken symlink — remove regardless of where it points
    name=$(basename "$link")
    rm "$link"
    echo "Claude Code: removed broken link $name"
    ((removed++))
  elif [[ "$target" == "$SHARED_DIR"/* ]] && [ ! -d "$SHARED_DIR/$(basename "$link")" ]; then
    # Points into our SHARED_DIR but the skill directory was removed
    name=$(basename "$link")
    rm "$link"
    echo "Claude Code: removed stale link $name"
    ((removed++))
  fi
  # Symlinks from other sources are left untouched
done

# Add missing symlinks
for skill_dir in "$SHARED_DIR"/*/; do
  [ -d "$skill_dir" ] || continue
  name=$(basename "$skill_dir")
  [ "$name" = ".git" ] && continue
  [ ! -f "$skill_dir/SKILL.md" ] && continue
  link="$CLAUDE_SKILLS/$name"
  if [ ! -e "$link" ]; then
    ln -s "$skill_dir" "$link"
    echo "Claude Code: linked $name"
    ((added++))
  fi
done

if [ "$added" -eq 0 ] && [ "$removed" -eq 0 ]; then
  echo "Claude Code: all symlinks up to date"
else
  echo "Claude Code: added $added, removed $removed"
fi

# --- Codex CLI ---
if [ ! -d "$CODEX_SKILLS" ]; then
  echo "Codex CLI: ~/.codex/skills/ does not exist, skipping."
else
  added=0
  removed=0

  # Remove stale symlinks (broken, or pointing into SHARED_DIR for a skill that no longer exists)
  for link in "$CODEX_SKILLS"/*; do
    [ -L "$link" ] || continue
    target=$(readlink "$link")
    if [ ! -e "$link" ]; then
      name=$(basename "$link")
      rm "$link"
      echo "Codex CLI: removed broken link $name"
      ((removed++))
    elif [[ "$target" == "$SHARED_DIR"/* ]] && [ ! -d "$SHARED_DIR/$(basename "$link")" ]; then
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
    [ ! -f "$skill_dir/SKILL.md" ] && continue
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

# --- Gemini CLI ---
if [ ! -d "$HOME/.gemini" ]; then
  echo "Gemini CLI: ~/.gemini/ does not exist, skipping."
else
  # Create skills directory if it doesn't exist
  mkdir -p "$GEMINI_SKILLS"

  added=0
  removed=0

  # Remove stale symlinks (broken, or pointing into SHARED_DIR for a skill that no longer exists)
  for link in "$GEMINI_SKILLS"/*; do
    [ -L "$link" ] || continue
    target=$(readlink "$link")
    if [ ! -e "$link" ]; then
      name=$(basename "$link")
      rm "$link"
      echo "Gemini CLI: removed broken link $name"
      ((removed++))
    elif [[ "$target" == "$SHARED_DIR"/* ]] && [ ! -d "$SHARED_DIR/$(basename "$link")" ]; then
      name=$(basename "$link")
      rm "$link"
      echo "Gemini CLI: removed stale link $name"
      ((removed++))
    fi
  done

  # Add missing symlinks
  for skill_dir in "$SHARED_DIR"/*/; do
    [ -d "$skill_dir" ] || continue
    name=$(basename "$skill_dir")
    [ "$name" = ".git" ] && continue
    [ ! -f "$skill_dir/SKILL.md" ] && continue
    link="$GEMINI_SKILLS/$name"
    if [ ! -e "$link" ]; then
      ln -s "$skill_dir" "$link"
      echo "Gemini CLI: linked $name"
      ((added++))
    fi
  done

  if [ "$added" -eq 0 ] && [ "$removed" -eq 0 ]; then
    echo "Gemini CLI: all symlinks up to date"
  else
    echo "Gemini CLI: added $added, removed $removed"
  fi
fi

echo ""
echo "Skills available:"
for skill_dir in "$SHARED_DIR"/*/; do
  [ -d "$skill_dir" ] || continue
  name=$(basename "$skill_dir")
  [ "$name" = ".git" ] && continue
  [ ! -f "$skill_dir/SKILL.md" ] && continue
  echo "  - $name"
done
