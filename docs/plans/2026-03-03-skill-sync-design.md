# skill-sync Design

## Problem

Skills live in a private repo (`coding-agent-skills`). They need to be installed into shared project repos so teammates get them automatically. The skill author needs to push updates to projects, pull back changes teammates make, and remove skills cleanly.

## Solution

A personal skill (`skill-sync`) that copies skill directories from the private repo into project repos, tracks versions in a manifest, and handles bidirectional updates.

## Where things live

- **Skill source of truth:** `coding-agent-skills/agent-skills/skill-sync/`
- **Installed via:** `agent-skills/sync-skills.sh` (symlinks to `~/.claude/skills/skill-sync/`)
- **Never shared** with project repos — this is a personal management tool

## Project layout (after installing skills)

```
project-repo/
  .shared/
    skills/
      make-pr/
        SKILL.md
      linear/
        SKILL.md
    skills-manifest.json
  .claude/
    skills/
      make-pr -> ../../.shared/skills/make-pr
      linear  -> ../../.shared/skills/linear
  .agents/
    skills/
      make-pr -> ../../.shared/skills/make-pr
      linear  -> ../../.shared/skills/linear
  .gemini/
    skills/
      make-pr -> ../../.shared/skills/make-pr
      linear  -> ../../.shared/skills/linear
```

Real files live in `.shared/skills/`. Each agent's skills directory contains relative symlinks pointing there.

## Manifest (`.shared/skills-manifest.json`)

Committed to the project repo. Tracks what was installed and from where.

```json
{
  "source": "coding-agent-skills",
  "skills": {
    "make-pr": {
      "sourceCommit": "10f6fbf",
      "installedAt": "2026-03-03T12:00:00Z",
      "updatedAt": "2026-03-03T12:00:00Z"
    }
  }
}
```

## Commands

| Command | Description |
|---|---|
| `/skill-sync install <skill>` | Copy skill from private repo into project, create symlinks, add to manifest |
| `/skill-sync update <skill>` | Pull newer version from private repo into project, update manifest |
| `/skill-sync update --all` | Update all skills listed in manifest |
| `/skill-sync harvest <skill>` | Diff project's version against last-synced, apply changes back to private repo |
| `/skill-sync remove <skill>` | Delete skill from project (files, symlinks, manifest entry) |
| `/skill-sync status` | Show installed skills, staleness, and local modifications |

## Flows

### Install

1. Verify the skill exists in `coding-agent-skills/agent-skills/<skill>/`.
2. Resolve the current commit hash of the private repo (`git rev-parse HEAD`).
3. Copy the skill directory into `.shared/skills/<skill>/` in the project.
4. Create relative symlinks in `.claude/skills/`, `.agents/skills/`, and `.gemini/skills/` (creating directories as needed).
5. Add an entry to `.shared/skills-manifest.json` with the commit hash and timestamp.

### Update (private repo changed)

1. Read manifest to get `sourceCommit` for the skill.
2. In the private repo, run `git diff <sourceCommit>..HEAD -- agent-skills/<skill>/` to see what changed upstream.
3. If no changes, report "already up to date."
4. Show the diff for review.
5. If approved, copy updated files into the project and update manifest (`sourceCommit`, `updatedAt`).

### Harvest (project changed a skill)

1. Read manifest to get `sourceCommit`.
2. Reconstruct the originally-installed version: `git show <sourceCommit>:agent-skills/<skill>/SKILL.md` from the private repo.
3. Diff that against the project's current `.shared/skills/<skill>/` version.
4. If no changes, report "no local modifications."
5. Show the diff for review.
6. If approved, copy the project's version back into `coding-agent-skills/agent-skills/<skill>/`.

### Conflict (both sides changed)

The `status` command detects this case:
- Upstream changed: `sourceCommit` differs from private repo HEAD for that skill's path.
- Local changed: project files differ from what was at `sourceCommit`.

When both are true, recommend: harvest first (capture project changes), then update (apply upstream changes). Standard git merge handles the rest if both touch the same lines.

### Remove

1. Delete `.shared/skills/<skill>/`.
2. Delete symlinks from `.claude/skills/`, `.agents/skills/`, `.gemini/skills/`.
3. Remove the entry from `.shared/skills-manifest.json`.
4. Clean up empty directories.

## Status output

```
Skill        Installed    Upstream    Local Changes
make-pr      10f6fbf      10f6fbf     none           (up to date)
linear       abc1234      def5678     modified        (both changed)
```

## Design decisions

- **`.shared/skills/` as canonical path**: Agent-neutral; avoids coupling to any one tool.
- **Relative symlinks**: Work regardless of where the project is cloned.
- **Manifest committed to project**: Teammates can see what skills are installed and at what version, even without access to the private repo.
- **No dependency on private repo for teammates**: Once installed, skills are regular files. Only the skill author needs the private repo to run sync commands.
- **Harvest is explicit**: Changes from projects are never auto-pulled. The author always reviews diffs before accepting.
