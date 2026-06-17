# Repository Instructions

This repository stores reusable agent skills. Treat each skill directory under
`agent-skills/` as a distributable unit whose source of truth is its
`SKILL.md`, plus any supporting `agents/`, `scripts/`, `assets/`, or `docs/`
files in that same skill directory.

## Skill Changes

Whenever you add, rename, remove, or materially edit a skill in `agent-skills/`,
update the repository documentation and sync surface in the same change.

Required checks:

1. Update `agent-skills/index.html`.
   - Add, rename, remove, or revise the skill card so the catalog matches the
     current `SKILL.md` metadata and workflow.
   - Keep the hero statistics, filters, tags, local links, and resource list
     accurate.
   - Preserve the page as a static, self-contained HTML file that can be opened
     directly from disk. Do not introduce a build step, dev server, or external
     runtime dependency.

2. Review `agent-skills/sync-skills.sh`.
   - Confirm the script still discovers the intended skill directories and skips
     non-skill folders.
   - If a skill is renamed or removed, make sure stale symlink cleanup still
     removes the old name for Claude, Codex, and Gemini skill directories.
   - If a new agent platform, destination, generated file, or directory shape is
     introduced, update the sync script in the same change.

3. Verify local links and repo state.
   - Check that `agent-skills/index.html` links point to existing local files.
   - Run `git status --short` and make sure only intentional skill, catalog, and
     sync-script changes are present.

## Editing Guidance

- Prefer small, focused updates that keep each skill self-contained.
- Do not commit machine-local symlink outputs from `~/.claude/skills`,
  `~/.codex/skills`, or `~/.gemini/skills`.
- Keep shell scripts portable Bash with `set -euo pipefail` unless a script has a
  documented reason to differ.
- Avoid replacing user changes. If the worktree contains unrelated edits, leave
  them alone and work around them.
