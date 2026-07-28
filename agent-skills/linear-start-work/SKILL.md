---
name: linear-start-work
description: Start and carry out coding work from a Linear issue link or key by loading full issue context (including comments, attachments, linked Linear documents/notes, parent issue, and child sub-issues), researching the codebase, creating a branch when appropriate, moving the issue to In Progress, then implementing and validating the issue unless blocked by a real open question. Use when a user says “start work”, “spin up a branch”, or provides a Linear issue to begin coding.
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
- For every new or changed data read, trace the real production caller and volume. Specify the scope/tenant boundary, filters, sort order, expected cardinality, and whether the caller needs a complete result set, a page/cursor, an aggregate, or an existence check. Do not use an arbitrary row cap (for example, `100`) as a substitute for pagination or a business rule, and do not read all rows unless the bounded dataset and complete-read requirement are explicit.
- For every new or changed external, asynchronous, or multi-step operation, identify essential failures: invalid input or missing prerequisite data, dependency/network/timeout/invalid response, and partial completion. Decide the user-safe behavior, retry ownership/limits, error propagation for capture, and whether compensation/rollback is required.
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
- Add a data-access checklist for every changed query or list endpoint:
  - caller intent and expected production volume,
  - tenant/business filters and deterministic ordering,
  - pagination/cursor behavior or an explicit bounded-complete-read justification,
  - cardinality and empty-result behavior.
- Add a failure-handling checklist for every changed external, asynchronous, or multi-step path:
  - essential failure modes and the customer-safe UI/API response,
  - retry policy (automatic, manual, or none) and ownership,
  - propagation to the error-capture boundary without leaking raw exceptions to the UI,
  - atomicity/compensation plan when earlier steps must be undone after a later failure.
- Add a reviewer-risk checklist and confirm each item is either covered by code or intentionally deferred:
  - missing negative-path tests,
  - index exists but no logical uniqueness guard,
  - ambiguous status mapping that can mislead UI,
  - cross-entity mismatch (record exists but belongs to different parent/org),
  - arbitrary query limit, missing pagination, or an unscoped/full-table read,
  - swallowed dependency failure, raw exception exposure, or incomplete compensation after partial failure.
- Create a short acceptance-to-tests map:
  - each acceptance criterion maps to at least one validation step,
  - include at least one regression test for the most likely refactor break.
- Include focused tests for relevant query boundaries (filters, pagination, ordering, empty results) and failure paths (safe response, error propagation, retry/compensation). Do not add fictional error tests for paths that cannot fail in the changed scope; state why they are not applicable.
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

7. Implement and validate the issue
- If `Go/No-Go` is `go`, continue immediately into code changes without waiting for user confirmation. Treat `go` as permission to proceed, not as a stopping point.
- Make the smallest implementation that satisfies the acceptance criteria and preserves the existing contracts identified in preflight.
- Add or update focused tests for the acceptance-to-validation map, including the planned regression test.
- Implement the chosen query semantics rather than relying on default limits. Handle the essential failures identified in preflight: preserve error capture, return a customer-safe response, and apply retries or compensation only where the plan calls for them.
- Run the planned validation steps. If validation is too expensive or blocked, run the strongest targeted checks available and state the remaining risk.
- Stop before coding only when requirements, ownership, production safety, or high-risk behavior is genuinely unclear.

## Notes

- If any required data is missing (team, status, branch name), infer safely and note the assumption.
- Treat linked Linear documents/notes as required context, not optional references. If a linked document cannot be fetched, call that out as a blocker or explicit assumption before planning.
- Keep the context summary concise and skimmable.
- Keep the research output specific enough to implement without re-discovery.
- For "small" issues, avoid shallow plans: include the depth gate in a compact format (3-7 bullets total).
- Treat data access and failure behavior as product behavior. Select query scope, pagination, retry, and rollback based on how customers and production volume will actually use the feature, not merely on what makes a local test pass.
- Do not treat branch creation, status updates, or preflight output as the end of the task unless the user explicitly asked only for kickoff/setup.

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

**Data Access**
- `Query intent/volume`: <caller need + expected scale>
- `Scope/order`: <tenant/business filters + deterministic ordering>
- `Result strategy`: <cursor/page | aggregate/existence check | bounded complete read + reason>
- `Empty result`: <intended behavior>

**Failure Handling**
- `Essential failures`: <missing data/input, dependency/timeout/invalid response, partial completion>
- `Customer-safe response`: <UI/API behavior; no raw exception>
- `Capture/retry`: <what is thrown/reported; automatic/manual/none + reason>
- `Atomicity/compensation`: <transaction/undo plan or not needed + reason>

**Reviewer-Risk Checklist**
- `Negative-path tests`: <planned test names>
- `Uniqueness guard`: <needed / not needed + reason>
- `Cross-entity mismatch`: <checked path(s)>
- `Potentially misleading status`: <decision + reason>
- `Query safety`: <pagination/filtering/bounded-read decision + planned test>
- `Failure safety`: <safe response, capture, retry/compensation decision + planned test>

**Acceptance -> Validation Map**
- `<criterion 1>` -> `<validation step>`
- `<criterion 2>` -> `<validation step>`

**Go/No-Go**
- `Decision`: <go | ask>
- `Open question(s)`: <none or list>
```
