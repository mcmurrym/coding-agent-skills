---
name: kit-and-kaboodle
description: "End-to-end delivery flow for a Linear issue from kickoff to cleanup. Use when a user wants one command to: take a Linear issue URL or key, run linear-start-work, propose a concrete implementation approach, wait for explicit approval, implement the approved work, then offer make-pr and, if approved, run make-pr followed by back-to-main."
---

# Kit And Kaboodle

Run a gated workflow that starts from a Linear issue and ends with optional PR creation and branch cleanup.

## Workflow

1. Validate input
- Accept a Linear issue URL or issue key.
- If missing, ask for it before continuing.

2. Run `linear-start-work`
- Use the `linear-start-work` skill to fetch full issue context, create/push the branch, and move the issue to In Progress.
- Reuse the summary from that skill as the baseline context.

3. Propose solution and pause
- Suggest a concrete implementation plan based on the issue context.
- Keep it actionable and scoped to the issue acceptance criteria.
- Stop and wait for explicit approval before editing files.

4. Execute approved implementation
- Perform the code changes.
- Run relevant validation commands/tests for touched areas.
- Report what changed and any remaining risks.

5. Offer PR creation
- Ask whether to run `make-pr`.
- If approved, execute the `make-pr` skill and return PR details.

6. Return repository to main
- After successful `make-pr`, ask whether to run `back-to-main` if not already explicitly approved together with PR creation.
- If approved, execute `back-to-main` to sync local `main` with `origin/main`.

## Guardrails

- Do not skip the approval gate before implementation.
- Do not run `make-pr` or `back-to-main` without user approval.
- If any step fails, stop, report the blocker, and propose the minimal recovery action.
