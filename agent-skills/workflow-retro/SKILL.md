---
name: workflow-retro
description: Analyze review feedback patterns from the current session, identify preventable root causes, and propose improvements to skills and project config files. Uses a persistent retro log to track recurring issues across sessions.
---

# Workflow Retro

Run a retrospective on the current session's review feedback to find preventable patterns and improve your workflow artifacts.

## Workflow

### Step 1 — Gather evidence

Collect findings from two sources:

**From the conversation:**
- Scan backward through conversation context for review-fix cycles
- Look for: PR review comments, test failures found during review, linting issues, repeated fix rounds
- Note how many iterations each issue took to resolve

**From git log:**
- Run `git log --oneline origin/main..HEAD` to see commit history on this branch
- Look for iteration signals: commits like "fix tests", "address review", "add missing X", "lint", multiple commits touching the same file
- Count the number of fix-up commits vs. implementation commits

**From the PR (if available):**
- If a PR URL is available in conversation context, fetch all threads (including resolved) using the fallback query:

```bash
SCRIPT="$CODEX_HOME/agent-skills/gh-pr-comment-audit/scripts/review-pr-comments.sh"
```

If `CODEX_HOME` is not set:

```bash
SCRIPT="/Users/mattmcmurry/coding-agent-skills/agent-skills/gh-pr-comment-audit/scripts/review-pr-comments.sh"
```

Note: The default fetch only returns UNRESOLVED threads. To see resolved threads too, run the fetch and check if threads were returned. If the PR has been fully resolved, the conversation and git log are the primary sources.

Build a deduplicated list of **findings** — each distinct issue that was raised during the review cycle.

### Step 2 — Classify each finding

For each finding, assign one classification:

| Classification | Meaning | Example |
|---|---|---|
| `preventable_by_instruction` | A rule in CLAUDE.md / AGENTS.md / GEMINI.md / .cursor/rules would catch this | "always write tests for new exported functions" |
| `preventable_by_skill` | A missing step in an existing skill would catch this | make-pr should verify test coverage before PR |
| `preventable_by_new_skill` | Needs a new workflow (rare — flag only, don't create) | "need a pre-commit lint skill" |
| `not_preventable` | Genuinely novel, context-dependent, no systemic fix | one-off architectural feedback |

### Step 3 — Scan existing artifacts

Before proposing changes, read the target files to avoid duplicating existing rules.

**Resolve symlinks first:**

```bash
for f in CLAUDE.md AGENTS.md GEMINI.md; do
  if [[ -L "$f" ]]; then
    echo "$f -> $(readlink "$f") [symlink]"
  elif [[ -f "$f" ]]; then
    echo "$f [real file]"
  fi
done
ls -la .cursor/rules 2>/dev/null || true
```

Deduplicate: if multiple files are symlinked to the same target, only read the canonical file. When proposing edits, always target the canonical (real) file and note which other files are symlinked to it.

Read:
- The canonical config file(s) that exist in the project
- `.cursor/rules` if it exists
- Any skill SKILL.md files relevant to the findings (resolve skill paths via `CODEX_HOME` or the absolute path `/Users/mattmcmurry/coding-agent-skills/agent-skills/<skill-name>/SKILL.md`)

### Step 4 — Check retro log for recurrence

```bash
RETRO_SCRIPT="$CODEX_HOME/agent-skills/workflow-retro/scripts/retro-log.sh"
```

If `CODEX_HOME` is not set:

```bash
RETRO_SCRIPT="/Users/mattmcmurry/coding-agent-skills/agent-skills/workflow-retro/scripts/retro-log.sh"
```

For each finding:

```bash
"$RETRO_SCRIPT" search --finding "<finding description>"
```

If matches are returned:
- Note the recurrence count and whether a past fix was attempted
- Recurring issues with no past fix → flag as "tracked but unaddressed"
- Recurring issues with a past fix → flag as "fix didn't hold — needs strengthening"
- First-time issues → note as "1st occurrence"

### Step 5 — Propose improvements

For each finding classified as preventable, present a proposal in this exact format:

```
### Finding: <one-line summary>

**Pattern:** <what happened and how many iterations it caused>
**Recurrence:** <1st time / Nth occurrence / previously attempted fix that didn't hold>
**Root cause:** <why it wasn't caught earlier in the workflow>
**Proposed fix:** <conceptual description of the change>

**Target file:** `<path to canonical file>`
<if symlinked>  (symlinked from: CLAUDE.md, GEMINI.md)</if>
**Exact change:**
```diff
<the actual diff to apply>
```

Apply this change? [discuss / apply / skip]
```

**Present one proposal at a time.** Wait for the user to respond (discuss / apply / skip) before showing the next proposal.

For findings classified as `preventable_by_new_skill`, present the idea but do NOT propose creating the skill — just note it as a suggestion for future consideration.

For findings classified as `not_preventable`, skip the proposal but still log them.

### Step 6 — Apply approved changes

For each change the user approves:
1. Apply the edit to the canonical file (not symlinks)
2. Verify the file is valid after editing

After all proposals have been addressed, if any changes were applied, ask:

> Changes applied to N file(s). Commit these improvements with git-add-commit-push?

### Step 7 — Update retro log

Log ALL findings (including skipped and not-preventable) using the retro-log script:

```bash
"$RETRO_SCRIPT" append --json '{
  "date": "<YYYY-MM-DD>",
  "pr_url": "<url or null>",
  "branch": "<branch name>",
  "finding": "<finding description>",
  "classification": "<classification>",
  "recurrence_count": <N>,
  "action_taken": "<applied|skipped|discussed>",
  "target_file": "<file path or null>",
  "fix_description": "<what was changed, or null>"
}'
```

Run one append per finding.

### Step 8 — Summary

Output a summary table:

| Finding | Classification | Recurrence | Target | Action |
|---------|---------------|-----------|--------|--------|
| Missing tests | preventable_by_skill | 1st time | make-pr/SKILL.md | Applied |
| No error handling | preventable_by_instruction | 3rd time | CLAUDE.md | Skipped |
| Architecture concern | not_preventable | 1st time | — | Logged |

## Script

Resolve the retro-log script path:

```bash
RETRO_SCRIPT="$CODEX_HOME/agent-skills/workflow-retro/scripts/retro-log.sh"
```

If `CODEX_HOME` is not set:

```bash
RETRO_SCRIPT="/Users/mattmcmurry/coding-agent-skills/agent-skills/workflow-retro/scripts/retro-log.sh"
```

### Commands

**read** — Print the current retro log.

```bash
"$RETRO_SCRIPT" read
```

**append** — Add a finding entry to the log.

```bash
"$RETRO_SCRIPT" append --json '<json object>'
```

**search** — Find similar past findings by keyword overlap.

```bash
"$RETRO_SCRIPT" search --finding "<description>"
```

## Key principles

- **Human-in-the-loop** — every change is proposed and discussed before applying
- **Conversation + git log** — conversation is primary evidence, git log supplements when context is compressed
- **Resolve symlinks** — always edit the canonical file, note symlink relationships
- **Additive by default** — prefer adding rules/steps over rewriting existing ones
- **Minimal changes** — each proposal is the smallest edit that prevents the pattern
- **No speculative improvements** — only propose changes tied to concrete evidence from the session
- **Recurrence tracking** — persistent log surfaces patterns across sessions

## Scope boundaries

- Does NOT create new skills (flags when one might be needed)
- Does NOT modify application code (only workflow/config artifacts)
- Does NOT auto-run — always manually invoked
- Does NOT auto-apply — every change requires explicit user approval
