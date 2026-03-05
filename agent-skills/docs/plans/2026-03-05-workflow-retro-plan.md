# Workflow Retro — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a `workflow-retro` skill that analyzes review feedback patterns and proposes improvements to skills and project config files, with a persistent retro log for recurrence tracking.

**Architecture:** Single SKILL.md file with a helper shell script for retro log operations (read/write/match). The skill is purely instructional (tells the AI what to do) — the script handles JSON log manipulation since shell-based JSON editing is error-prone inline.

**Tech Stack:** Markdown (SKILL.md), YAML (openai.yaml), Bash + jq (retro-log script)

---

### Task 1: Create skill directory structure

**Files:**
- Create: `workflow-retro/SKILL.md` (placeholder)
- Create: `workflow-retro/agents/openai.yaml`
- Create: `workflow-retro/scripts/retro-log.sh`

**Step 1: Create the directory structure**

```bash
mkdir -p /Users/mattmcmurry/coding-agent-skills/agent-skills/workflow-retro/agents
mkdir -p /Users/mattmcmurry/coding-agent-skills/agent-skills/workflow-retro/scripts
```

**Step 2: Create the openai.yaml agent interface**

Create `workflow-retro/agents/openai.yaml`:

```yaml
interface:
  display_name: "Workflow Retro"
  short_description: "Analyze review feedback patterns and improve skills/configs to prevent recurring issues"
  default_prompt: "Use $workflow-retro to analyze this session's review feedback, identify preventable patterns, and propose improvements to skills and project config files."
```

**Step 3: Commit**

```bash
git add workflow-retro/
git commit -m "chore: scaffold workflow-retro skill directory"
```

---

### Task 2: Create the retro-log.sh helper script

**Files:**
- Create: `workflow-retro/scripts/retro-log.sh`

This script handles all `.git/retro-log.json` operations so the AI doesn't have to construct jq commands inline.

**Step 1: Write the script**

Create `workflow-retro/scripts/retro-log.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Resolve the .git directory (works in worktrees too)
GIT_DIR="$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir)"
LOG_FILE="$GIT_DIR/retro-log.json"

usage() {
  cat <<'USAGE'
Usage:
  retro-log.sh read                          Print current log (or empty JSON)
  retro-log.sh append --json '<entry>'       Append a JSON entry to the log
  retro-log.sh search --finding '<text>'     Search for similar past findings
USAGE
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

ensure_log() {
  if [[ ! -f "$LOG_FILE" ]]; then
    echo '{"entries":[]}' > "$LOG_FILE"
  fi
}

cmd_read() {
  ensure_log
  cat "$LOG_FILE"
}

cmd_append() {
  local entry_json=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) entry_json="$2"; shift ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
  done

  if [[ -z "$entry_json" ]]; then
    echo "append requires --json '<entry>'" >&2
    exit 1
  fi

  ensure_log

  # Validate the entry is valid JSON
  if ! echo "$entry_json" | jq empty 2>/dev/null; then
    echo "Invalid JSON entry" >&2
    exit 1
  fi

  # Append entry to the log
  local tmp
  tmp="$(mktemp)"
  jq --argjson new "$entry_json" '.entries += [$new]' "$LOG_FILE" > "$tmp"
  mv "$tmp" "$LOG_FILE"

  echo "Entry appended to $LOG_FILE"
}

cmd_search() {
  local finding=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --finding) finding="$2"; shift ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
  done

  if [[ -z "$finding" ]]; then
    echo "search requires --finding '<text>'" >&2
    exit 1
  fi

  ensure_log

  # Normalize: lowercase, strip punctuation, split into words
  local words
  words="$(echo "$finding" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' ' ' | xargs)"

  # Search entries where finding contains any of the key words
  # Returns matching entries with a simple word-overlap score
  local word
  local jq_filter=".entries[]"
  local conditions=()

  for word in $words; do
    # Skip very short/common words
    if [[ ${#word} -le 2 ]]; then
      continue
    fi
    conditions+=("(.finding | ascii_downcase | contains(\"$word\"))")
  done

  if [[ ${#conditions[@]} -eq 0 ]]; then
    echo "[]"
    return
  fi

  # Match entries where at least half the significant words match
  local threshold=$(( (${#conditions[@]} + 1) / 2 ))
  local count_expr
  count_expr="$(printf "[%s] | map(if . then 1 else 0 end) | add" "$(IFS=,; echo "${conditions[*]}")")"

  jq --argjson threshold "$threshold" \
    "[.entries[] | . as \$e | ($count_expr) as \$score | select(\$score >= \$threshold) | . + {match_score: \$score}] | sort_by(-.match_score)" \
    "$LOG_FILE"
}

main() {
  require_cmd jq
  require_cmd git

  local cmd="${1:-}"
  if [[ -z "$cmd" ]]; then
    usage
    exit 1
  fi
  shift

  case "$cmd" in
    read) cmd_read ;;
    append) cmd_append "$@" ;;
    search) cmd_search "$@" ;;
    --help|-h) usage ;;
    *) echo "Unknown command: $cmd" >&2; usage; exit 1 ;;
  esac
}

main "$@"
```

**Step 2: Make executable**

```bash
chmod +x /Users/mattmcmurry/coding-agent-skills/agent-skills/workflow-retro/scripts/retro-log.sh
```

**Step 3: Verify the script works**

```bash
cd /Users/mattmcmurry/coding-agent-skills
# Test read (should create empty log)
agent-skills/workflow-retro/scripts/retro-log.sh read
# Expected: {"entries":[]}

# Test append
agent-skills/workflow-retro/scripts/retro-log.sh append --json '{"date":"2026-03-05","finding":"test entry","classification":"not_preventable","recurrence_count":1,"action_taken":"skipped","target_file":null,"fix_description":null}'
# Expected: Entry appended to .git/retro-log.json

# Test search
agent-skills/workflow-retro/scripts/retro-log.sh search --finding "test entry"
# Expected: JSON array with the test entry + match_score

# Test read again to see the appended entry
agent-skills/workflow-retro/scripts/retro-log.sh read
# Expected: {"entries":[...the test entry...]}

# Clean up test data
rm -f .git/retro-log.json
```

**Step 4: Commit**

```bash
git add workflow-retro/scripts/retro-log.sh
git commit -m "feat: add retro-log.sh helper for persistent retro log"
```

---

### Task 3: Write the SKILL.md

**Files:**
- Create: `workflow-retro/SKILL.md`

This is the core deliverable. The skill file instructs the AI on the full workflow.

**Step 1: Write SKILL.md**

Create `workflow-retro/SKILL.md`:

```markdown
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
```

**Step 2: Commit**

```bash
git add workflow-retro/SKILL.md
git commit -m "feat: add workflow-retro skill"
```

---

### Task 4: Update sync-skills.sh if needed

**Files:**
- Check: `sync-skills.sh`

**Step 1: Check if sync-skills.sh has a hardcoded skill list**

Read `sync-skills.sh` and determine if new skills are auto-discovered (by directory) or need to be registered.

**Step 2: If registration is needed, add `workflow-retro` to the list**

**Step 3: Commit if changed**

---

### Task 5: End-to-end manual test

**Step 1: Verify skill structure matches other skills**

```bash
ls -la workflow-retro/
ls -la workflow-retro/agents/
ls -la workflow-retro/scripts/
```

Compare structure against `gh-pr-comment-audit/` to confirm parity.

**Step 2: Test retro-log.sh in a real git repo**

```bash
cd /Users/mattmcmurry/coding-agent-skills

# Read (empty)
agent-skills/workflow-retro/scripts/retro-log.sh read

# Append a test finding
agent-skills/workflow-retro/scripts/retro-log.sh append --json '{"date":"2026-03-05","pr_url":"https://github.com/test/repo/pull/1","branch":"test-branch","finding":"Missing unit tests for new helper functions","classification":"preventable_by_skill","recurrence_count":1,"action_taken":"applied","target_file":"make-pr/SKILL.md","fix_description":"Added test verification step"}'

# Search for it
agent-skills/workflow-retro/scripts/retro-log.sh search --finding "missing tests for functions"

# Append a second similar finding
agent-skills/workflow-retro/scripts/retro-log.sh append --json '{"date":"2026-03-05","pr_url":null,"branch":"other-branch","finding":"No test coverage for new utility","classification":"preventable_by_skill","recurrence_count":1,"action_taken":"skipped","target_file":null,"fix_description":null}'

# Search again — should match both
agent-skills/workflow-retro/scripts/retro-log.sh search --finding "test coverage missing"

# Clean up
rm -f .git/retro-log.json
```

**Step 3: Verify worktree sharing**

```bash
cd /Users/mattmcmurry/coding-agent-skills

# The retro-log.sh uses `git rev-parse --git-common-dir` which returns the
# shared .git directory across worktrees. Verify this resolves correctly:
git rev-parse --git-common-dir
# Expected: the path to the main .git directory
```

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: workflow-retro skill complete"
```

---

## Execution summary

| Task | What | Files |
|------|------|-------|
| 1 | Scaffold directories + openai.yaml | `workflow-retro/agents/openai.yaml` |
| 2 | retro-log.sh helper script | `workflow-retro/scripts/retro-log.sh` |
| 3 | SKILL.md (core skill) | `workflow-retro/SKILL.md` |
| 4 | Check sync-skills.sh registration | `sync-skills.sh` (maybe) |
| 5 | End-to-end manual test | — |
