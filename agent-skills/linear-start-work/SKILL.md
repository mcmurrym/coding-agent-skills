---
name: linear-start-work
description: Start work from a Linear issue link or key by loading full issue context (including comments, attachments, linked Linear documents/notes, parent issue, and child sub-issues), researching the issue against the codebase to determine the work required, optionally creating a git branch, and moving the issue to In Progress. Use when a user says “start work”, “spin up a branch”, or provides a Linear issue to begin coding.
---

# Linear Start Work

## Workflow

Follow this sequence every time.

1. Resolve the issue
- Accept a Linear issue URL or key.
- Use the Linear skill/MCP to fetch the issue with full details, including relations.
- If the issue has a parent, read the parent issue context before branch creation (title, goal, acceptance criteria, constraints, open questions, and links) so the implementation is aligned with parent intent.
- If the issue has linked Linear documents/notes, fetch and read each document body before summarizing or planning. Do this for documents returned in the issue payload and for Linear document URLs found in the issue description or comments.
- Also list comments on each linked document/note when the Linear tooling supports it, and summarize any substantive document comments with the document.
- Also list all comments and explicitly enumerate sub-issues (children) in a list.
- If attachments exist, load them when possible.

2. Summarize context
- Build a brief, actionable summary: title, goal, acceptance criteria, relevant links, and risks.
- If a parent issue is present, include a short parent context section (scope, dependencies, and constraints) in the same summary.
- Include a linked documents/notes section with each document title, URL when available, and the implementation-relevant decisions or constraints from its body.
- If attachments, linked documents/notes, document comments, or sub-issues are large, summarize each in 1-3 bullets.

3. Research the implementation
- Inspect the repository to locate relevant code paths, configs, and tests tied to the issue.
- Identify what must change to satisfy acceptance criteria, including edge cases and dependencies.
- Produce a concrete work plan with:
  - files/components likely to be modified,
  - implementation steps,
  - test/validation steps.
- If requirements are ambiguous, call out assumptions and open questions before implementation.

4. Run a depth gate before coding
- Do this even for small tickets. Keep it concise, but explicit.
- Add an invariants checklist for the planned changes:
  - ownership and access boundaries (org, portal, role, hidden visibility),
  - cardinality/uniqueness expectations (one-to-one vs one-to-many),
  - state/status mapping semantics (including fallback and "in-review"/similar states),
  - null/unconfigured behavior.
- Add a reviewer-risk checklist and confirm each item is either covered by code or intentionally deferred:
  - missing negative-path tests,
  - index exists but no logical uniqueness guard,
  - ambiguous status mapping that can mislead UI,
  - cross-entity mismatch (record exists but belongs to different parent/org).
- Create a short acceptance-to-tests map:
  - each acceptance criterion maps to at least one validation step,
  - include at least one regression test for the most likely refactor break.
- If any high-risk item is unclear, stop and ask before implementation.
- Emit the preflight output template from `## Required Output Template` before writing code.

5. Create and push the branch (unless user opts out)
- **Skip this step** if the user says “no branch”, “stay on current branch”, “don’t switch branches”, or similar. In that case, proceed directly to step 6.
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

6. Move issue to In Progress
- Use Linear statuses from the issue’s team.
- Prefer status type `started` or the name “In Progress”.
- Update the issue to that status after the branch is created (or after research if branch was skipped).

## Notes

- If any required data is missing (team, status, branch name), infer safely and note the assumption.
- Treat linked Linear documents/notes as required context, not optional references. If a linked document cannot be fetched, call that out as a blocker or explicit assumption before planning.
- Keep the context summary concise and skimmable.
- Keep the research output specific enough to implement without re-discovery.
- For "small" issues, avoid shallow plans: include the depth gate in a compact format (3-7 bullets total).

## Required Output Template

Print this block after research and before implementation:

```md
**Preflight**
- `Issue`: <key + title>
- `Scope`: <what is in / out>
- `Files`: <likely files to touch>
- `Assumptions`: <explicit assumptions or "none">

**Invariants**
- `Access/ownership`: <checks>
- `Cardinality`: <one-to-one / one-to-many expectation>
- `Status semantics`: <state mapping + fallback behavior>
- `Null/unconfigured`: <intended behavior>

**Reviewer-Risk Checklist**
- `Negative-path tests`: <planned test names>
- `Uniqueness guard`: <needed / not needed + reason>
- `Cross-entity mismatch`: <checked path(s)>
- `Potentially misleading status`: <decision + reason>

**Acceptance -> Validation Map**
- `<criterion 1>` -> `<validation step>`
- `<criterion 2>` -> `<validation step>`

**Go/No-Go**
- `Decision`: <go | ask>
- `Open question(s)`: <none or list>
```
