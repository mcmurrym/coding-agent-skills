---
name: kit-and-kaboodle
description: "End-to-end delivery flow for a Linear issue: from kickoff through implementation, Playwright browser verification, Codex code review with cyclomatic complexity gating, to PR creation with attached screen recordings."
---

# Kit And Kaboodle

Run a gated workflow that starts from a Linear issue and ends with a verified, reviewed PR.

## Workflow

### Step 1: Validate input

- Accept a Linear issue URL or issue key.
- If missing, ask for it before continuing.

### Step 2: Run `linear-start-work`

- Use the `linear-start-work` skill to fetch full issue context, create/push the branch, and move the issue to In Progress.
- Reuse both the summary and the implementation research from that skill as the primary baseline context.
- Do not rerun broad issue-context discovery or duplicate codebase-wide investigation.

### Step 3: Implement

- Translate the `linear-start-work` research into a concrete implementation plan.
- Keep it actionable and scoped to the issue acceptance criteria.
- If the plan is vague, pause only briefly to do a focused planning pass (assumptions, affected files, likely changes, and validation checks), then execute immediately.
- Execute without asking for confirmation.
- Perform the code changes.
- Run relevant validation commands/tests for touched areas.

### Step 4: Playwright Browser Verification

Verify the implementation works in a real browser using Playwright.

1. **Start the dev server** in the background:
   ```bash
   pnpm dev &
   DEV_PID=$!
   ```
   Keep it running across all verification iterations. Wait for the server to be ready before proceeding (check for the port to be listening).

2. **Write an ad-hoc Playwright test script** based on the Linear issue's acceptance criteria:
   - Navigate to the relevant pages and flows.
   - Assert the expected behavior described in the issue.
   - Enable video recording:
     ```javascript
     use: {
       video: 'on',
       // Save recordings to test-recordings/ in the project root
     }
     ```
   - Save the test file in the project (e.g. `e2e/verify-issue.spec.ts`).

3. **Run the Playwright test:**
   ```bash
   npx playwright test e2e/verify-issue.spec.ts
   ```

4. **Evaluate results:**
   - **Pass** → Save the recording to `test-recordings/`, proceed to step 5.
   - **Fail** → Analyze the failure output. Fix the code (not the test, unless the test itself is wrong). Re-run the test.

5. **Loop up to 15 attempts.** On each iteration, analyze what went wrong and make targeted fixes. Do not repeat the same fix twice.

6. **After 15 failures — STOP:**
   - Kill the dev server.
   - Run `git-add-commit-push` to push whatever code exists.
   - Do NOT create a PR.
   - Return structured failure info:
     ```json
     {
       "status": "failed",
       "issueKey": "CP-123",
       "issueUrl": "https://linear.app/...",
       "attempts": 15,
       "lastError": "...",
       "lastRecordingPath": "test-recordings/...",
       "iterationLog": ["Attempt 1: ...", "Attempt 2: ..."]
     }
     ```
   - Exit the workflow. The calling skill (`start-task`) handles failure reporting.

7. **On success**, kill the dev server and proceed.

### Step 5: Checkpoint Commit

Run `git-add-commit-push` to commit and push the working implementation.

This creates a clear baseline in git history — the "original implementation" commit. If the code review step finds issues, fixes will appear in a separate commit for easy comparison.

### Step 6: Codex Code Review

Get an independent code review from Codex CLI, then filter and act on the findings.

1. **Run Codex code review:**
   ```bash
   codex -p "Review the changes on this branch against main. Focus on bugs, logic errors, security issues, and code quality problems. For each finding report: the file path, line number(s), severity, and a clear explanation of the issue."
   ```

2. **Filter the findings.** For each issue Codex reports:
   - **Is it related to the current changes?** Check if the flagged code was modified in this branch (`git diff main...HEAD`). Discard findings about pre-existing code that was not touched.
   - **Is it a real issue?** Validate the finding by reading the code and understanding the context. Discard false positives.

3. **Measure cyclomatic complexity** of the affected function or block for each validated finding. Consider:
   - Number of branches (if/else, switch cases, ternary operators)
   - Number of loops
   - Number of logical operators in conditions
   - Nesting depth

4. **Act on each validated finding:**

   **Low cyclomatic complexity** (the function is simple, few branches, changes are unlikely to cause side-effects beyond the scope of work):
   - Auto-fix the issue directly.

   **High cyclomatic complexity** (the function is complex, many branches, fixing risks unintended side-effects):
   - Do NOT fix the code.
   - Collect the finding for a PR comment. Include:
     - File and line number
     - The issue description
     - Why it was flagged but not auto-fixed (complexity, risk of side-effects)
     - Suggested fix approach for a human reviewer

### Step 7: Re-verify After Fixes (if needed)

If any auto-fixes were made in step 6:

1. Start the dev server again.
2. Re-run the Playwright verification (same test, same 15-attempt loop as step 4).
3. On success, run `git-add-commit-push` — this creates a second commit ("review fixes") clearly separated from the original implementation.
4. On failure (15 attempts exhausted), follow the same failure path as step 4.

If no auto-fixes were made, skip this step.

### Step 8: Create PR

Run `make-pr`:

1. **Attach the screen recording** to the PR description. Include the recording file path or upload it as a PR asset. Reference it in the PR body:
   ```markdown
   ## Verification Recording
   [Screen recording of the implemented feature](test-recordings/...)
   ```

2. **Add PR comments for unfixed high-complexity issues** (from step 6). For each one, add a review comment on the specific file and line:
   ```
   gh api repos/{owner}/{repo}/pulls/{pr_number}/comments -f body="..." -f path="..." -f line=N -f commit_id="..."
   ```
   Each comment should explain:
   - What the code review found
   - The cyclomatic complexity concern
   - A suggested fix for the human reviewer

3. Return the PR URL and summary.

## Guardrails

- Do not skip validation and blocker checks.
- If any step fails, stop, report the blocker, and propose the minimal recovery action.
- The Playwright test should verify the issue's acceptance criteria, not test the entire application.
- Do not modify the Playwright test to make it pass if the underlying code is broken — fix the code.
- The 15-attempt limit is absolute. Do not work around it by resetting the counter.
- During code review filtering, err on the side of caution: if unsure whether a finding is real, treat it as real but flag it for human review (high-complexity path) rather than auto-fixing.
