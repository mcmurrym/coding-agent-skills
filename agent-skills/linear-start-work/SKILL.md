---
name: linear-start-work
description: Start work from a Linear issue link or key by loading full issue context (including comments, attachments, parent issue, and child sub-issues), researching the issue against the codebase to determine the work required, creating and pushing a git branch from the issue slug/branch, and moving the issue to In Progress. Use when a user says “start work”, “spin up a branch”, or provides a Linear issue to begin coding.
---

# Linear Start Work

## Workflow

Follow this sequence every time.

1. Resolve the issue
- Accept a Linear issue URL or key.
- Use the Linear skill/MCP to fetch the issue with full details, including relations.
- If the issue has a parent, read the parent issue context before branch creation (title, goal, acceptance criteria, constraints, open questions, and links) so the implementation is aligned with parent intent.
- Also list all comments and explicitly enumerate sub-issues (children) in a list.
- If attachments exist, load them when possible.

2. Summarize context
- Build a brief, actionable summary: title, goal, acceptance criteria, relevant links, and risks.
- If a parent issue is present, include a short parent context section (scope, dependencies, and constraints) in the same summary.
- If attachments or sub-issues are large, summarize each in 1-3 bullets.

3. Research the implementation
- Inspect the repository to locate the relevant code paths, configs, and tests tied to the issue.
- Identify what must change to satisfy the acceptance criteria, including edge cases and dependencies.
- Produce a concrete work plan with:
  - files/components likely to be modified,
  - implementation steps,
  - test/validation steps.
- If requirements are ambiguous, call out assumptions and open questions before implementation.

4. Create and push the branch
- Prefer the issue’s provided `branchName` or `branch` field when present.
- Otherwise derive a slug from the issue title: lowercase, hyphenated, remove punctuation.
- Create and push:

```bash
branch="<issue-branch-or-slug>"
git checkout -b "$branch" || git checkout "$branch"
git push -u origin "$branch"
```

- If the remote branch already exists, fetch and check it out:

```bash
git fetch origin "$branch":"$branch"
git checkout "$branch"
```

5. Move issue to In Progress
- Use Linear statuses from the issue’s team.
- Prefer status type `started` or the name “In Progress”.
- Update the issue to that status after the branch is created.

## Notes

- If any required data is missing (team, status, branch name), infer safely and note the assumption.
- Keep the context summary concise and skimmable.
- Keep the research output specific enough to implement without re-discovery.
