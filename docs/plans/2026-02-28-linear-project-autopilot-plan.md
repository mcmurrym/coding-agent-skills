# Linear Project Autopilot — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a skill that autonomously works through all issues in a Linear project — implementing, testing, reviewing, PR-ing, and merging each one in dependency order.

**Architecture:** Single SKILL.md file at `~/.claude/skills/linear-project-autopilot/SKILL.md` with an `agents/openai.yaml` for Codex compatibility. The skill orchestrates existing skills (linear-start-work, git-add-commit-push, make-pr) in a loop.

**Tech Stack:** Claude Code skills (Markdown instruction files), Linear MCP, GitHub CLI (`gh`)

---

### Task 1: Create the skill directory and SKILL.md

**Files:**
- Create: `~/.claude/skills/linear-project-autopilot/SKILL.md`
- Create: `~/.claude/skills/linear-project-autopilot/agents/openai.yaml`

**Step 1: Create the directory structure**

```bash
mkdir -p ~/.claude/skills/linear-project-autopilot/agents
```

**Step 2: Write the SKILL.md file**

Create `~/.claude/skills/linear-project-autopilot/SKILL.md` with the following content:

```markdown
---
name: linear-project-autopilot
description: Take a Linear project URL, work through all issues autonomously in milestone/priority order. For each issue: implement with unit tests, commit, self-review, create PR, auto-merge, mark done. Stops only when human action is needed (API keys, external service config, etc).
---

# Linear Project Autopilot

Autonomously work through all issues in a Linear project. Implement, test, review, PR, merge, repeat.

## Input

A Linear project URL. Examples:
- `https://linear.app/teamname/project/project-slug-abc123/overview`
- `https://linear.app/teamname/project/project-slug-abc123`

## Workflow

### Phase 1: Initialize

1. Extract the project slug from the URL (the segment after `/project/`).
2. Fetch the project via Linear MCP: `get_project` with `includeMilestones: true`.
3. Fetch all project issues via Linear MCP: `list_issues` with the project ID, `limit: 250`.
4. If more than 250 issues, paginate with cursor until all are fetched.
5. Filter out issues with status type `completed` or `cancelled`.
6. Build the **work queue** — sort remaining issues by:
   - **Milestone order**: Parse milestone names for ordering (e.g., "M0: ..." before "M1: ..."). If milestones don't have numeric prefixes, use their position in the milestones array. Issues without milestones go last.
   - **Priority within milestone**: Urgent (1) > High (2) > Medium (3) > Low (4) > None (0).
   - **Unblocked first**: If issues have Linear blocking relations (`blockedBy`), push blocked issues after their blockers.
   - **Creation date** as final tiebreaker (oldest first).
7. Print a summary table and immediately begin working:

```
## Project: <name>
## Milestones: <count> | Issues: <count> remaining

| # | Issue | Milestone | Priority | Status |
|---|-------|-----------|----------|--------|
| 1 | MCM-140 Initialize Next.js + Convex project | M0 | Urgent | Backlog |
| 2 | MCM-141 Define Convex schema | M1 | Urgent | Backlog |
| ... | ... | ... | ... | ... |

Starting work on issue #1...
```

### Phase 2: Issue Loop

For each issue in the work queue, execute these steps. Do NOT stop between issues unless a human-needed situation is detected.

#### Step 1: Detect human-needed blockers BEFORE starting

Read the issue description carefully. If the issue requires ANY of these, STOP the loop immediately:
- Obtaining an API key or secret from an external service
- Configuring a webhook, OAuth app, or integration in an external dashboard
- Manual DNS, domain, or infrastructure setup
- Purchasing or subscribing to a third-party service
- Any action that requires logging into a service the agent cannot access

When stopping, print:
```
## PAUSED — Human action needed

**Issue:** <identifier> — <title>
**What's needed:** <specific description of the manual action>
**Instructions:** Complete this step, then say "continue" to resume.

**Remaining queue:** <count> issues
```

Then wait for the user to say "continue" before resuming the loop.

#### Step 2: Start work on the issue

Invoke the `linear-start-work` skill with the issue URL or key. This will:
- Fetch full issue context (description, comments, parent, sub-issues, attachments)
- Create a git branch
- Move the issue to In Progress

#### Step 3: Create worktree

After the branch is created, create an isolated git worktree:
```bash
git worktree add ".claude/worktrees/<branch-name>" <branch-name>
```
Change working directory to the worktree for all subsequent work on this issue.

#### Step 4: Implement with tests

Using the research output from `linear-start-work`:

1. **Detect the project platform and tooling.** On the first issue, inspect the project to understand what you're working with and what quality tooling exists or needs to be set up.

   **Platform detection — look for these signals:**

   | Signal files | Platform | Test framework | Type/compile check | Linter | Formatter |
   |---|---|---|---|---|---|
   | `package.json` | JS/TS (Node, Next.js, etc.) | vitest, jest, mocha | `tsc --noEmit` | eslint, biome | prettier, biome |
   | `build.gradle.kts` / `pom.xml` | Kotlin/Java (JVM) | JUnit 5, kotest | `./gradlew compileKotlin` / `mvn compile` | ktlint, detekt | ktfmt, spotless |
   | `Package.swift` / `*.xcodeproj` | Swift | XCTest, swift-testing | `swift build` | swiftlint | swift-format |
   | `Cargo.toml` | Rust | built-in (`cargo test`) | `cargo check` | `cargo clippy` | `cargo fmt` |
   | `pyproject.toml` / `setup.py` | Python | pytest | mypy, pyright | ruff, flake8 | ruff format, black |
   | `go.mod` | Go | built-in (`go test`) | `go vet` | golangci-lint | `gofmt` |

   **For each quality dimension, check if tooling exists. If not, set it up:**

   - **Testing**: Every project needs a test framework. If none exists, install the idiomatic one for the platform.
   - **Compilation / type checking**: If the language has a compile step or static type checker, ensure it runs cleanly.
   - **Linting**: If no linter is configured, install the standard one for the platform with a minimal config.
   - **Formatting**: If no formatter is configured, install the standard one for the platform.

   Use whatever is already in the project. Don't replace existing tools — augment what's missing. All tooling setup is part of the first issue's commit.

2. **Implement the feature/fix** as described in the issue.

3. **Write unit tests** that provide real value:
   - Test actual behavior, not implementation details
   - Cover edge cases and error paths
   - Test the contract (inputs → outputs), not internals
   - If the issue involves API endpoints, test request validation, success responses, and error responses
   - If the issue involves data mutations, test state transitions
   - Do NOT write tests that just assert the code exists or mock everything away

4. **Run all validation checks.** Use the commands appropriate to the detected platform:
   - **Tests**: Run the full test suite
   - **Compile / type check**: Run the compiler or type checker in check mode
   - **Lint**: Run the linter with zero-warning tolerance
   - **Format**: Run the formatter in check mode

   Run ALL applicable checks. Fix any failures before proceeding.

5. If any check fails, fix the issue:
   - Test failures → fix the implementation (not the tests, unless the tests are wrong)
   - Type/compile errors → fix the code
   - Lint errors → prefer auto-fix if the linter supports it, otherwise fix manually
   - Format errors → auto-fix with the formatter
   Loop until all checks pass.

#### Step 5: Commit and push

Invoke `git-add-commit-push`. This stages all changes, generates a commit message from the diff, commits, and pushes.

#### Step 6: Self-review

Review your own changes critically:

```bash
git diff main...HEAD
```

Evaluate the diff for:
- **Bugs**: Logic errors, off-by-one, null/undefined issues, race conditions
- **Security**: Injection, exposed secrets, missing auth checks
- **Missing edge cases**: What happens with empty input? Invalid input? Concurrent access?
- **Code quality**: Is this the simplest correct implementation?

If you find critical issues:
1. Fix them.
2. Run tests again to verify the fix doesn't break anything.
3. Invoke `git-add-commit-push` again (creates a second "review fix" commit).

If the code is acceptable, proceed.

#### Step 7: Create PR

Invoke `make-pr` to create a pull request. The PR description should reference the Linear issue.

#### Step 8: Auto-merge

Merge the PR:
```bash
gh pr merge <pr-number> --squash --delete-branch
```

If merge fails due to CI:
1. Check CI failure output: `gh pr checks <pr-number>`
2. Read the failure logs.
3. Fix the issue in the worktree.
4. Commit, push, wait for CI.
5. Retry merge.
6. Max 3 CI-fix attempts. After 3 failures, STOP and report the CI issue to the user.

If merge fails due to conflicts:
1. Attempt rebase: `git rebase main`
2. If rebase succeeds, force-push and retry merge.
3. If rebase fails, STOP and report the conflict to the user.

#### Step 9: Clean up and advance

1. Change working directory back to the main repo.
2. Remove the worktree:
   ```bash
   git worktree remove ".claude/worktrees/<branch-name>"
   ```
3. Update main:
   ```bash
   git checkout main
   git pull origin main
   ```
4. Move the Linear issue to Done:
   - Use `list_issue_statuses` to find the team's "Done" status (type: `completed`).
   - Update the issue status via `save_issue`.
5. Print a progress update:
   ```
   ## Completed: <identifier> — <title>
   ## Progress: <completed>/<total> issues done
   ## Next: <next-identifier> — <next-title>
   ```
6. Continue to the next issue in the queue.

### Phase 3: Completion

When all issues are processed (or all remaining issues are blocked on human actions), print a final summary:

```
## Project Autopilot Complete

| Status | Count |
|--------|-------|
| Completed | N |
| Skipped (human needed) | N |
| Failed | N |

### Completed Issues
- MCM-140: Initialize Next.js + Convex project (PR #1)
- MCM-141: Define Convex schema (PR #2)
- ...

### Pending (human action needed)
- MCM-150: Implement Stripe webhook handler — needs Stripe webhook secret configured
- ...
```

## Guardrails

- Never skip unit tests. Every issue gets tests.
- Never skip type checking, linting, or formatting if the project has them configured.
- Never auto-merge if any validation check is failing (tests, types, lint, format).
- Never continue past a human-needed blocker — stop and wait.
- Never modify tests just to make them pass if the underlying code is wrong.
- The 3-attempt CI fix limit is absolute.
- If an issue's description is empty or too vague to implement, stop and ask the user for clarification rather than guessing.
```

**Step 3: Write the agents/openai.yaml file**

Create `~/.claude/skills/linear-project-autopilot/agents/openai.yaml`:

```yaml
interface:
  display_name: "Linear Project Autopilot"
  short_description: "Autonomously work through all issues in a Linear project"
  default_prompt: "Use this skill to take a Linear project URL, work through all issues in milestone/priority order, implementing each with tests, creating PRs, self-reviewing, and auto-merging. Stops only when human action is needed."
```

**Step 4: Verify the skill is discoverable**

```bash
ls -la ~/.claude/skills/linear-project-autopilot/
cat ~/.claude/skills/linear-project-autopilot/SKILL.md | head -5
```

Expected: The file exists and the frontmatter shows `name: linear-project-autopilot`.

**Step 5: Commit**

```bash
cd /Users/mattmcmurry/Developer/coding-agent-skills
git add docs/plans/2026-02-28-linear-project-autopilot-plan.md
git commit -m "Add implementation plan for linear-project-autopilot skill"
```

Note: The skill files themselves are in `~/.claude/skills/` (outside this repo), so they won't be committed here. They live alongside the other skills.
