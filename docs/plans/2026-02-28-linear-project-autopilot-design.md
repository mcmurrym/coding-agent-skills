# Linear Project Autopilot — Design

## Purpose

A skill that takes a Linear project URL and autonomously works through all its issues in dependency order: implementing, testing, committing, creating PRs, self-reviewing, fixing review issues, and auto-merging — only stopping when a human is needed for something like configuring an external service or providing an API key.

## Input

A Linear project URL, e.g.:
```
https://linear.app/mcmurryfamily/project/weather-service-67bc81b55df4/overview
```

## Initialization

1. Extract the project slug from the URL.
2. Fetch the project via Linear MCP (`get_project` with `includeMilestones: true`).
3. Fetch all issues in the project (`list_issues`).
4. Build a work queue sorted by:
   - Milestone order (M0 before M1, etc.) — if milestones exist
   - Priority within milestone (Urgent > High > Medium > Low)
   - Unblocked issues as tiebreaker (respect Linear blocking relations)
5. Filter out Done/Cancelled issues.
6. Display a summary (project name, milestone count, issue count, queue order) and immediately begin working.

## Main Loop

For each issue in the work queue:

### Step 1: Start work
- Invoke `linear-start-work` with the issue (fetch context, create branch, move to In Progress).
- Create a git worktree for isolation.

### Step 2: Implement + Test
- Implement the changes based on the research from linear-start-work.
- Write meaningful unit tests that cover real behavior and edge cases, not just line coverage.
- If the project doesn't have a test framework established, set one up as part of the first issue.
- Run tests and validation (type checking, linting) for touched areas.

### Step 3: Commit & Push
- Invoke `git-add-commit-push` to stage, commit, and push.

### Step 4: Self-review
- Review the diff against main (`git diff main...HEAD`).
- Evaluate for: bugs, logic errors, security issues, missing edge cases.
- If critical issues found: fix, re-commit, re-push.
- If acceptable: proceed.

### Step 5: Create PR
- Invoke `make-pr` to create the pull request.

### Step 6: Auto-merge
- `gh pr merge <pr-url> --squash --delete-branch`
- Wait for merge to complete.

### Step 7: Clean up & advance
- Clean up the worktree.
- Move the Linear issue to Done.
- Pull latest main.
- Move to the next issue.

## Human-Needed Detection

Before or during implementation, if the issue requires something the agent cannot do autonomously (configure an external service dashboard, obtain an API key, set up a webhook on a third-party platform, etc.), the agent stops the loop and prints:

- What manual action is needed
- Which issue it's on
- The remaining work queue
- Instructions: "Complete the manual step and say 'continue' to resume"

## Edge Cases

- **No milestones**: Sort by priority only.
- **Sub-issues**: Process as part of the parent issue unless they're standalone project issues.
- **Merge conflicts**: Attempt rebase. If rebase fails, stop and ask.
- **CI failures**: Read failure output, attempt fix, re-push. Max 3 attempts before stopping.
- **All remaining issues blocked on manual steps**: Stop and report the full list.

## Skills Composed

| Skill | Role |
|-------|------|
| `linear-start-work` | Fetch issue context, create branch, move to In Progress |
| `git-add-commit-push` | Stage, commit, push |
| `make-pr` | Create the pull request |

## Decisions Made

- **Worktrees** for isolation (one per issue).
- **Auto-merge** after self-review passes (no human approval gate).
- **Stop-and-wait** for manual steps (don't skip/create sub-issues).
- **Unit tests** on every issue, establish test framework if missing.
- **Monolithic skill** — single file, no sub-skill decomposition.
