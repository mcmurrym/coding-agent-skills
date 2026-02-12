---
name: kit-and-kaboodle
description: "End-to-end delivery flow for a Linear issue from kickoff to PR creation and branch cleanup. Use when a user wants one command to: take a Linear issue URL or key, run linear-start-work, implement the work, and finish by running git-add-commit-push, make-pr, and back-to-main."
---

# Kit And Kaboodle

Run a gated workflow that starts from a Linear issue and ends with PR creation.

## Workflow

1. Validate input
- Accept a Linear issue URL or issue key.
- If missing, ask for it before continuing.

2. Run `linear-start-work`
- Use the `linear-start-work` skill to fetch full issue context, create/push the branch, and move the issue to In Progress.
- Reuse both the summary and the implementation research from that skill as the primary baseline context.
- Do not rerun broad issue-context discovery or duplicate codebase-wide investigation.

3. Propose solution and proceed
- Translate the `linear-start-work` research into a concrete implementation plan.
- Keep it actionable and scoped to the issue acceptance criteria.
- If the plan is vague, pause only briefly to do a focused planning pass (assumptions, affected files, likely changes, and validation checks), then execute immediately.
- Execute without asking for confirmation.

4. Execute implementation
- Perform the code changes.
- Run relevant validation commands/tests for touched areas.
- Report what changed and any remaining risks.

5. Create PR
- Execute `git-add-commit-push` automatically before PR creation.
- Execute the `make-pr` skill automatically when implementation is complete and changes are committed/pushed.
- Return PR details and the PR summary.

6. Return repository to main
- Always run `back-to-main` after successful `make-pr`.
- Return the result of branch sync along with PR details.

## Guardrails

- Do not skip validation and blocker checks.
- If any step fails, stop, report the blocker, and propose the minimal recovery action.
