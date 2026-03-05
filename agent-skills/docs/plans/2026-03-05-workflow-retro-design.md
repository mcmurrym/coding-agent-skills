# Workflow Retro — Design Document

**Date:** 2026-03-05
**Skill name:** `workflow-retro`

## Purpose

A manually-invoked retrospective skill that analyzes review feedback patterns from the current session, identifies root causes, and proposes concrete improvements to skills and project config files. All changes require human approval before being applied. A persistent log tracks issues across sessions to surface recurring patterns.

## Workflow

### Step 1 — Gather context

- Scan the current conversation for review-fix cycles (PR comments, test failures, review rounds)
- Check git log on the current branch for iteration signals — commit messages like "fix tests", "address review feedback", "add missing X" supplement conversation context that may have been compressed
- Identify the PR URL from conversation context and fetch all threads (including resolved) via `gh-pr-comment-audit`'s fetch script
- Build a list of "findings" — each issue that was raised during review

### Step 2 — Classify patterns

For each finding, classify it:

- **Preventable by instruction** — a rule in CLAUDE.md/AGENTS.md/GEMINI.md/.cursor/rules would have caught this (e.g., "always write tests for new functions")
- **Preventable by skill improvement** — a workflow step is missing from an existing skill (e.g., make-pr should verify test coverage before creating the PR)
- **Preventable by new skill** — needs a whole new workflow step (rare, flag but don't auto-create)
- **Not preventable** — genuinely novel or context-dependent, no systemic fix

### Step 3 — Scan existing artifacts

Before proposing changes, read the relevant files to avoid duplicating existing rules:

- **Resolve symlinks first** — check if CLAUDE.md, AGENTS.md, GEMINI.md are symlinks (via `readlink` or `ls -la`). Deduplicate so we only read and edit the canonical (real) file. When proposing changes, name the canonical file and note which others are symlinked to it.
- Read `.cursor/rules` in the current project (if it exists)
- Read any skill files that are relevant to the pattern (e.g., `make-pr/SKILL.md`)

### Step 4 — Check retro log for recurring patterns

- Read `.git/retro-log.json` (if it exists)
- Cross-reference current findings against past entries
- Flag recurring issues that have appeared before — these get higher priority for workflow changes
- Flag issues where a past fix was attempted but the issue recurred — the fix may need strengthening

### Step 5 — Propose improvements

For each preventable finding, present:

```
### Finding: <one-line summary>

**Pattern:** <what happened — e.g., "Tests were missing for 3 new functions, caught in 2 review rounds">
**Recurrence:** <first time / Nth occurrence / previously attempted fix that didn't hold>
**Root cause:** <why it wasn't caught earlier>
**Proposed fix:** <conceptual description>

**Target file:** `make-pr/SKILL.md` (or `CLAUDE.md`, etc.)
**Exact change:**
\`\`\`diff
- ### Step 2 — Push and create PR
+ ### Step 2 — Verify test coverage
+ - Check that new/modified functions have corresponding tests
+ - Run the test suite and confirm all tests pass
+
+ ### Step 3 — Push and create PR
\`\`\`

Apply this change? [discuss / apply / skip]
```

Wait for user response on each proposal before proceeding to the next.

### Step 6 — Apply approved changes

- For each change the user approves, apply the edit to the canonical file (not symlinks)
- After all changes are applied, offer to commit them with `git-add-commit-push`

### Step 7 — Update retro log

Write all findings to `.git/retro-log.json`, regardless of whether a fix was applied:

```json
{
  "entries": [
    {
      "date": "2026-03-05",
      "pr_url": "https://github.com/...",
      "branch": "feature/xyz",
      "finding": "Missing tests for new functions",
      "classification": "preventable_by_skill",
      "recurrence_count": 1,
      "action_taken": "applied",
      "target_file": "make-pr/SKILL.md",
      "fix_description": "Added test coverage verification step"
    },
    {
      "date": "2026-03-05",
      "finding": "No error handling convention",
      "classification": "preventable_by_instruction",
      "recurrence_count": 1,
      "action_taken": "skipped",
      "target_file": null,
      "fix_description": null
    }
  ]
}
```

### Step 8 — Summary

Output a table:

| Finding | Recurrence | Target | Action |
|---------|-----------|--------|--------|
| Missing tests | 1st time | make-pr/SKILL.md | Applied |
| No error handling | 3rd time | CLAUDE.md | Skipped |

## Retro log

- **Location:** `.git/retro-log.json` — shared across worktrees, never committed
- **Format:** JSON with an `entries` array
- **Append-only during a session** — new findings are appended, existing entries are not modified (except `recurrence_count` which gets incremented on matching findings)
- **Matching heuristic:** findings are matched by normalized description similarity, not exact string match — the skill should recognize "missing tests" and "no test coverage for new code" as the same pattern

## Key principles

- **Human-in-the-loop** — every change is proposed and discussed before applying
- **Conversation + git log** — conversation is primary evidence, git log supplements when context is compressed
- **Resolve symlinks** — always edit the canonical file, note symlink relationships
- **Additive by default** — prefer adding rules/steps over rewriting existing ones
- **Minimal changes** — each proposal should be the smallest edit that prevents the pattern
- **No speculative improvements** — only propose changes tied to concrete evidence from the session
- **Recurrence tracking** — persistent log surfaces patterns across sessions

## Scope boundaries

- Does NOT create new skills (flags when one might be needed)
- Does NOT modify code in the target project (only workflow/config artifacts)
- Does NOT auto-run — always manually invoked
- Does NOT auto-apply — every change requires explicit approval
