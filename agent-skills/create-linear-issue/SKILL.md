---
name: create-linear-issue
description: Research, shape, and create Linear issues from rough feature, bug, or planning prompts. Use when the user invokes /create-linear-issue or asks to create a Linear issue after doing repository/product research, deciding whether the work is one issue or a parent with sub-issues, preserving concrete requirements, and setting proper blocking or blocked-by relationships.
---

# Create Linear Issue

## Overview

Turn a rough product prompt into real Linear issue(s). Research enough of the codebase and existing issue backlog to make the ticket actionable, then create the issue in Linear rather than stopping at a draft.

## Workflow

Follow this sequence every time.

1. Capture the request
- Treat everything after `/create-linear-issue` as source requirements.
- Preserve concrete user language for product behavior, UI entry points, data contracts, workflow states, and "must not" constraints.
- If the user provided an explicit team, project, priority, labels, assignee, or due date, carry those through.
- Ask only when creating the issue would otherwise be materially wrong, such as no plausible Linear team or mutually exclusive requirements.

2. Research the workspace
- Inspect the current repository before shaping the issue. Use `rg` first for named modules, functions, routes, schemas, jobs, tests, product copy, and related terminology from the prompt.
- Read the most relevant files enough to identify current behavior, ownership boundaries, and likely implementation areas.
- If the prompt references external docs, SDKs, APIs, CLIs, or cloud services, follow the workspace documentation policy for fetching current docs before relying on memory.
- Keep the research proportional: gather enough evidence for a useful ticket, not a full implementation plan.

3. Search Linear for duplicates and adjacency
- Use the Linear MCP tools to search existing issues for the main nouns, module names, and user-facing concepts.
- If issue search/list tools are not currently exposed, use tool discovery for Linear before skipping this step.
- If an existing issue is an exact duplicate, do not create a new one; summarize the match and recommend updating it.
- If related issues exist but this request is distinct, mention them in the new issue description or link them when appropriate.

4. Decide issue structure
- Prefer one issue when the work has one coherent user-facing outcome and can be implemented/reviewed as a single feature.
- Create a parent with sub-issues only when there are genuinely separable deliverables, cross-team ownership, staged rollout gates, or dependencies that would make one issue too broad to execute.
- Do not split merely because the prompt is detailed. When the user says they think it is one issue, default to one unless research shows clear independent workstreams.
- For parent/sub-issue structures:
  - Create the parent as the product umbrella with final outcome, scope, and non-goals.
  - Create sibling sub-issues with `parentId` set to the parent issue.
  - Set dependency relationships with `blocks` or `blockedBy` on the sub-issues, not just prose.
  - Keep each sub-issue independently testable.

5. Draft the issue body
- Use a title that names the product area and the outcome.
- Include sections that fit the work:
  - `Context`
  - `Problem`
  - `Goal`
  - `Proposed Scope`
  - `Acceptance Criteria`
  - `Implementation Notes`
  - `Out of Scope`
  - `Open Questions`
  - `Research Notes`
- Acceptance criteria should be concrete and testable. Include negative criteria for "do not create/mutate data yet", permission boundaries, preview/confirmation flows, and state transitions when relevant.
- Implementation notes should reference discovered files, functions, schemas, routes, jobs, and tests, but should not over-prescribe code unless the existing code path makes it obvious.
- Capture unresolved ambiguity as open questions; do not erase it by inventing certainty.

6. Create the Linear issue(s)
- Use `mcp__linear.save_issue` when available.
- Creating a normal issue requires at least `team` and `title`.
- Use `description` with literal Markdown newlines.
- Use `labels`, `project`, `priority`, `assignee`, `state`, `links`, `parentId`, `blocks`, and `blockedBy` when known. Treat `blocks` and `blockedBy` as append-only relationship updates.
- If using the Linear skill's generic MCP instructions instead, map to equivalent issue creation/update fields.

7. Verify and report
- After creation, read or use the tool result to confirm identifiers and relationships.
- If parent/sub-issues were created, verify every child has the correct `parentId`, and every dependency relationship was set with `blocks` or `blockedBy`.
- Final response should list created issue identifiers/titles, any parent-child/dependency structure, and the main assumptions or open questions left in the tickets.

## Quality Bar

- Create the real Linear record unless blocked by missing access, missing required team/project information, or an exact duplicate.
- Preserve the user's exact constraints more than polished abstraction. Product nuance is usually the point of the prompt.
- Distinguish discovered facts from assumptions.
- Avoid creating broad "investigate" issues when the prompt asks for a shippable feature; include research notes inside the implementation issue instead.
- Keep parent issues outcome-focused and sub-issues delivery-focused.

## Example Shape

For a prompt like "turn `modules/payments/schedule/devBackfill:backfillPastPeriodScheduledPayments` into a UX that previews a historical invoice before creating a payment":

- Research the referenced function, payment schedule states, invoice/payment creation flow, preview UI patterns, permission boundaries, and tests.
- Search Linear for existing backfill, invoice preview, and scheduled payment issues.
- Usually create one issue if the flow can be delivered as one feature.
- The issue should preserve requirements such as selecting a past collection period from a dropdown, generating a visual invoice preview before creating a payment, supporting schedule/complete/processing structures, and allowing collect or approval-needed payment creation from the preview.
- If split is justified, likely children would be data/preview generation, admin UX, and collection/approval mutation, with UX blocked by preview generation and mutation blocked by preview contract.
