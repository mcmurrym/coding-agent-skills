---
name: gh-pr-comment-audit
description: Audit GitHub pull request review comments against the branch's stated purpose, analyze upstream/downstream and practical capacity effects before changing code, prevent speculative mechanical scope creep, auto-fix only small safe issues, resolve justified threads, and render per-issue Codex HTML actions for research, resolution, implementation, and shipping when inline visualizations are available.
---

# GitHub PR Comment Audit

Use this skill to triage a pull request's unresolved review comments without letting review-driven fixes expand beyond the branch's purpose.

## Purpose and scope gate

Before auditing comments or editing code, establish the branch contract from the PR title/body, linked issue or task, base/head branch, changed files, and the current diff. Write a one- or two-sentence purpose statement covering:

- the user or system behavior this branch is meant to change;
- the explicit non-goals or boundaries, when stated; and
- the smallest acceptance signal that would show the branch is complete.

If that purpose is ambiguous, contradictory, or cannot be recovered from the PR and repository context, pause before processing comments and ask the user to clarify it. Do not infer a broader purpose from reviewer suggestions.

Classify every finding against that purpose before deciding whether to act:

1. **Core-purpose correctness** — required for the stated behavior, or prevents a concrete regression, security issue, data loss, or compatibility break caused by the branch.
2. **Necessary supporting change** — not the headline behavior, but required for the core change to work safely in its existing callers, consumers, persistence, tests, or deployment path.
3. **Adjacent improvement** — useful cleanup, hardening, refactoring, theoretical edge case, or generalized abstraction that is not required by the branch contract.

Only the first two categories are in scope by default. Do not turn an adjacent improvement into a new workstream merely because it can be made more complete. If a reviewer finding is valid but adjacent, explain that it is out of scope and leave the code unchanged unless the user explicitly expands the branch purpose.

## Targeted Mode

If the user provides a discussion URL/anchor, thread ID, or `next-unresolved`, process exactly one selected review comment/thread and do not review siblings or other unresolved items.

Supported targeted requests:

```bash
"$SCRIPT" fetch <pr-url>#discussion_r123456789
"$SCRIPT" fetch <pr-url> --discussion discussion_r123456789
"$SCRIPT" fetch <pr-url> --thread-id <thread-id>
"$SCRIPT" fetch <pr-url> next-unresolved
```

If the user says only `next-unresolved` and no PR URL is provided, infer the PR from the current branch first:

```bash
PR_URL="$(gh pr view --json url -q .url)"
"$SCRIPT" fetch "$PR_URL" next-unresolved
```

Targeted discussion anchors select the matching review comment inside its parent review thread. In AI-generated review threads, the first/head comment is often general context and later comments are the actual issues. Treat the selected comment as the finding under review; use the head comment and sibling comments only as context.

GitHub resolves review threads, not individual comments. In targeted comment mode:

- Resolve the parent thread only when the selected comment is the only actionable issue in that thread or the rest of the thread is clearly context/non-actionable.
- If sibling comments appear to contain other unprocessed issues, fix or classify only the selected comment and do not resolve the parent thread automatically. Report that resolution was skipped because the thread contains other issue comments.
- If a selector cannot be matched, stop instead of falling back to the full audit.

## Output Style

When explaining an issue, fix made, or suggested fix, prefer progressive bullet points over paragraphs. Each bullet should add one layer of understanding:

- Start with the immediate symptom or reviewer claim.
- Then explain the code path or condition that makes it happen.
- Then explain the user/runtime impact.
- Then explain the smallest safe fix or the proposed fix.
- Then give the validation step or remaining trade-off.

Keep bullets concise and concrete. Avoid dense paragraphs for problem explanations and solutions unless the user explicitly asks for prose.

## Interactive follow-up UI

When the Codex inline visualization surface and the `$visualize` skill are available, load and follow `$visualize` before creating the response. Write one HTML fragment to the task-owned visualization directory outside the repository and emit its `visualize{"path":"<absolute-path>"}` content reference in the same response. Do not print raw HTML in chat.

Render all **Real issue, non-trivial or out of scope** items in that fragment. Use one semantic, unframed section per issue and place that issue's actions immediately below its analysis. Seven issues therefore render fourteen independently bound buttons, subject to the resolution safety rule below.

Use native `<button type="button">` elements and the visualization design-system classes. Attach event listeners in the fragment script and call:

```js
await window.openai.sendFollowUpMessage({ prompt, title });
```

Do not use inline `onclick` handlers, network requests, client-specific Markdown, or `request_user_input`. Keep issue data out of executable markup; safely serialize it into the fragment script and select it by a stable issue key. Retain the complete bound issue record in the HTML artifact so a concise follow-up can recover it from the immediately preceding visualization.

Bind every button's artifact record to the exact PR URL and number, review thread ID, selected comment or discussion ID, file/line, commit, branch-purpose statement, classification, and issue analysis. Keep operational metadata and instructions in that record instead of serializing them into the visible **Make it so** prompt.

For each initial non-trivial issue, render:

- **Explain and Research** — send a follow-up prompt that invokes only `$explain` and contains the assessment this audit produced for the selected issue. Do not copy or re-fetch the GitHub review-comment body and do not include PR, thread, branch-purpose, or action-instruction metadata in the visible prompt. Build one assessment text block first and reuse it verbatim in both the rendered issue section and the button prompt; do not regenerate, summarize, normalize capitalization, or reorder it for the prompt. Resolve symlinks for `$explain` and prefer its canonical repository-source `SKILL.md` path over an installation symlink such as `~/.codex/skills/explain/SKILL.md`. Construct the prompt exactly in this shape:

  ```text
  [$explain](<absolute-explain-skill-path>) <assessment title>
  <Current or Outdated> · <priority when known> · <purpose classification>

  <path>:<line> at <commit>
  <assessment symptom or reviewer claim>
  <assessment code path or condition>
  <assessment user/runtime impact>
  <assessment smallest safe direction>
  <assessment regression proof>

  and research the most correct and straightforward, non-overly-complex fix.
  ```

  Before building the shared assessment block, format its status and classification with the exact user-facing labels used by this skill: **Current**, **Outdated**, **Core-purpose correctness**, **Necessary supporting change**, or **Adjacent improvement**. Then preserve the block's wording, capitalization, punctuation, and ordering verbatim between the rendered issue section and prompt; omit unknown metadata instead of inventing it. Make no code or GitHub changes. The new turn may inspect the repository to research the fix. Carry the original bound PR/thread identity forward from conversation context when rendering that response's **Make it so** and **Mark issue resolved** buttons, but do not add it to the visible `$explain` prompt.
- **Mark issue resolved** — send a follow-up prompt that invokes `$gh-pr-comment-audit` in targeted mode, re-fetches the bound thread, and resolves it without code changes. Treat the clicked follow-up message as explicit authorization for this GitHub write.

After **Explain and Research**, render:

- **Make it so** — send exactly `Make it so` as the complete follow-up prompt. Do not add a skill invocation, link, punctuation, PR URL, IDs, file/commit metadata, branch purpose, assessment, recommendation, validation plan, stale-state instructions, or any other text. Render this post-research artifact for exactly one issue and retain that issue's complete binding plus researched recommendation in its serialized issue record.
- **Mark issue resolved** — use the same targeted resolution behavior as the initial control.

When the user sends the exact **Make it so** follow-up from this artifact, continue the current audit workflow: read the immediately preceding interactive artifact and recover its single bound issue record. If there is no artifact, more than one issue is eligible, or the binding or researched recommendation is incomplete, stop and ask the user to rerun **Explain and Research** for the intended issue; never guess from nearby conversation. Once the record is unambiguous, re-fetch only its selected thread with this skill's bundled script, stop if it is already resolved or materially changed, implement the recorded recommended fix, repeat the purpose and fix-impact analysis, run the relevant validation, and resolve the thread only after success. End the successful response with **Git Add Commit Push** when the shipping safety gate passes.

After **Make it so** succeeds, render:

- **Git Add Commit Push** — resolve symlinks for `$git-add-commit-push`, prefer its canonical repository-source `SKILL.md` path, and send exactly `[$git-add-commit-push](<absolute-git-add-commit-push-skill-path>)` as the complete follow-up prompt. Do not add punctuation, worktree instructions, diff or commit instructions, issue metadata, or any other text.

Before rendering either **Mark issue resolved** button, apply the targeted resolution rule. If resolving the parent thread would also resolve actionable sibling comments, omit or disable the button and show a concise reason in that issue section.

Before rendering **Git Add Commit Push**, confirm the worktree contains only the intended audit fix. Because `$git-add-commit-push` stages all changes, do not render or invoke it when unrelated changes are present; identify those changes and ask the user how to handle them.

If the inline visualization surface or `window.openai.sendFollowUpMessage` is unavailable, present the same action labels as concise plain-text choices and wait for the user to select one. Never imply that displaying a button performed its action.

`window.openai.sendFollowUpMessage` is the supported host API for this interaction. It may stage the generated prompt in the Codex composer for user submission. No supported auto-submit option is currently exposed; do not invent one or simulate a click on the composer.

## Workflow

### Step 1 — Establish the branch purpose

Inspect the PR metadata, linked issue/task, changed-file list, and diff before fetching or processing review threads. Use the purpose gate above. Record the purpose statement and a short list of in-scope behavior in the audit notes.

For a targeted request, perform this gate first as well. A targeted selector limits which comment is processed; it does not remove the need to understand the branch boundary.

### Step 2 — Fetch unresolved threads

```bash
"$SCRIPT" fetch <pr-url>
```

For targeted mode, use one of the targeted fetch forms above.

### Step 3 — Read, verify, and scope each thread

For every unresolved thread, or the single selected comment in targeted mode, review in this order:

1. Read the full review thread: comment body, `isOutdated`, `path`, `line`, `startLine`, and `diffHunk`.
2. Open the referenced file at the relevant line range (or nearest equivalent commit/version if outdated).
3. Confirm whether the review point still applies in the current diff.
4. Compare the finding with the branch purpose: mark it core-purpose, necessary supporting change, or adjacent improvement.

Use this evidence template (required before bucket placement):

- Finding: <what the selected review comment is claiming>
- Scope check: <file/path + line + old/new commit context if outdated>
- Evidence: <specific code excerpt or API behavior confirming or disproving>
- Purpose fit: <core-purpose / necessary supporting change / adjacent improvement + rationale>
- Capacity reality: <reachable collection size and relevant service/query limit, or not applicable>
- Outcome: <real / not real + rationale>

If a finding cannot be verified from the available context, classify it as **non-trivial** and ask for confirmation, rather than resolving it as not real.

#### Required fix-impact analysis

Before making any code change, analyze the proposed fix itself, not only the reviewer's symptom. Trace:

- **Upstream effects:** callers, inputs, producers, shared helpers, contracts, and state that can now reach the changed code differently.
- **Downstream effects:** consumers, outputs, persistence, side effects, error handling, retries, UI/API behavior, and tests that observe the changed result.
- **Boundary effects:** existing behavior outside the changed path, compatibility, performance, concurrency, security, and failure modes.

State the smallest fix that addresses the verified cause and list at least one regression check for the affected upstream/downstream path. If the proposed fix only makes the code more generalized, defensive, abstract, or theoretically complete without a demonstrated branch-related impact, classify it as an adjacent improvement and do not implement it automatically.

When a new review comment is caused by a previous review-driven fix, re-evaluate the whole chain against the original purpose. Prefer reverting or simplifying the prior fix when it created the new complexity, rather than layering another mechanical fix on top. Do not continue an iterative “fix the fix” chain without showing a concrete user/runtime impact and a bounded end state.

#### Capacity and pagination reality check

For a finding about an unbounded collection query, missing pagination, batch size, payload size, rate limit, memory pressure, timeout, or service degradation, do not assume the worst-case type shape is reachable. Establish:

- the concrete business event and population the query serves;
- the reachable upper bound from feature rules, tenant/account shape, selectors, ownership, retention, or existing limits;
- the relevant service/query/transport threshold; and
- whether the realistic bound approaches that threshold with meaningful headroom.

Classify the finding as **not actionable in practice** when evidence shows the reachable size is safely bounded below the relevant threshold. A theoretical possibility alone is not sufficient to expand the branch with pagination, batching, or a generalized limit.

If the repository and PR context cannot establish the realistic bound, pause and ask before fixing or resolving:

> This finding assumes this query can return up to `<reviewer estimate>` items at once. Is that realistic for this feature? What is the expected upper bound for the collection, and is there a known service/query limit we need to stay below?

Only after verification, classify each thread/comment into one of four buckets:

1. **Not a real issue** — false positive, stale/outdated, style nit that doesn't apply, etc.
2. **Not actionable in practice** — theoretically possible, but concrete business and technical bounds keep it safely below the relevant operational limit.
3. **Real issue, trivial in-scope fix** — small one-liner or obvious change whose upstream/downstream impact is understood and bounded.
4. **Real issue, non-trivial or out of scope** — needs thought, has trade-offs, touches multiple places, is speculative, or would expand the branch purpose.

### Step 4 — Act on each bucket

**Research gate for all classifications**

- A thread is **Not a real issue** only if you can point to one concrete reason from evidence that the comment is invalid (for example, outdated thread, duplicate/already-fixed behavior, or the claimed behavior does not exist in the changed path).
- A thread is **Not actionable in practice** only when the business context establishes a reachable bound and a relevant operational threshold shows sufficient headroom. If either is unknown, ask the capacity-reality question rather than guessing.
- If evidence is incomplete or contradictory, default to **Real issue, non-trivial**.
- A valid comment is not automatically in scope. If it is an adjacent improvement with no concrete impact on the branch contract, do not implement it; present it as **out of scope** and ask only if the user wants to expand the purpose.
- Do not call a fix trivial just because the diff is small. It is trivial only when the cause, purpose fit, upstream/downstream effects, and regression check are all clear.

**Not a real issue →** Resolve the thread on GitHub after documenting the evidence briefly in chat:

```bash
"$SCRIPT" resolve <pr-url> --thread-id <id>
```

You may batch multiple thread IDs in one call.

In targeted comment mode, follow the targeted resolution rule above before resolving the parent thread.

**Not actionable in practice →** Document the realistic collection bound and the relevant operational limit in chat, then resolve the thread on GitHub. Do not add pagination, batching, or protective machinery solely for a disproven worst-case scenario:

```bash
"$SCRIPT" resolve <pr-url> --thread-id <id>
```

In targeted comment mode, follow the targeted resolution rule above before resolving the parent thread.

**Real issue, trivial in-scope fix →** Fix the code directly (edit the file), perform the required fix-impact analysis, verify the local change matches the comment intent and branch purpose, run the regression check, then resolve the thread on GitHub:

```bash
"$SCRIPT" resolve <pr-url> --thread-id <id>
```

You may batch multiple thread IDs in one call. No comment is needed — just resolve.

In targeted comment mode, follow the targeted resolution rule above before resolving the parent thread.

**Real issue, non-trivial or out of scope →** Do NOT fix or resolve automatically. When inline HTML is available, render all non-trivial items and their per-issue actions in one fragment using the interactive follow-up UI rules. Preserve the following content for every issue. When inline HTML is unavailable, present it in chat using this format:

> **`<file>:<line>`** — <one-line summary of the review comment>
>
> **Problem:**
> - <reviewer claim or observed symptom>
> - <code path / condition that causes it>
> - <impact if left unchanged>
>
> **Evidence:** <line-level citation, snippet, or observed behavior>
>
> **Suggested fix:**
> - <smallest safe change>
> - <why this addresses the cause>
> - <validation step>
>
> ```<lang>
> <optional concrete code showing a possible fix>
> ```
>
> **Trade-offs / notes:**
> - <upstream/downstream effects>
> - <remaining risk, alternative, scope boundary, or reason to ask the user>

Then offer the **Explain and Research** and **Mark issue resolved** actions using the interactive follow-up UI rules above.

When a trivial in-scope fix was made, summarize it with progressive bullets:

> **Fixed `<file>:<line>`**
> - <issue fixed>
> - <change made>
> - <purpose fit and upstream/downstream impact check>
> - <validation performed or recommended>

When a not-real/stale issue is resolved, summarize it with progressive bullets:

> **Resolved `<file>:<line>` as not real**
> - <reviewer claim>
> - <evidence that invalidates it>
> - <resolution action taken>

When a theoretical capacity issue is resolved as not actionable in practice, summarize it with progressive bullets:

> **Resolved `<file>:<line>` as not actionable in practice**
> - <reviewer’s worst-case concern>
> - <business constraint and realistic maximum collection size>
> - <relevant service/query limit and safety headroom>
> - <resolution action taken>

Use code blocks only when the code itself clarifies the suggested solution:

> ```<lang>
> <concrete code showing a possible fix>
> ```

Required minimum for every non-trivial item:

1. Confirm whether the thread is outdated/stale.
2. Include exact `path`, `line`, and `commit` references where available.
3. State whether it is core-purpose, necessary supporting change, or adjacent improvement.
4. For capacity or pagination concerns, state the reachable collection size and relevant threshold, or ask the capacity-reality question.
5. Describe relevant upstream and downstream effects of the suggested fix.
6. Include one concrete validation step that proves the impact.

### Step 5 — Summary

After processing all threads, output a summary:

| Category | Count | Action taken |
|----------|-------|-------------|
| Not real / stale | N | Resolved on GitHub |
| Not actionable in practice | N | Bounded by evidence + resolved on GitHub |
| Trivial in-scope fixes | N | Fixed in code + resolved on GitHub |
| Non-trivial / out of scope | N | Presented above; no automatic code change |

### Step 6 — Follow-up

If the user asks you to fix any of the non-trivial issues:
1. Make the code changes.
2. Reconfirm the expanded purpose and repeat the upstream/downstream impact analysis.
3. Resolve the corresponding threads on GitHub.
4. After successful validation and resolution, offer **Git Add Commit Push** only when its shipping safety gate passes.

## Setup

- Requires `gh` authentication with repository access and permission to resolve review threads.

## Script

**Always use the bundled script for all GitHub API calls. Never construct `gh api graphql` commands inline — they break due to quote mangling.**

Resolve the script path:

```bash
SCRIPT="<skill-directory>/scripts/review-pr-comments.sh"
```

### Commands

**fetch** — Download unresolved review threads (read-only).

```bash
"$SCRIPT" fetch <pr-url> [--discussion <discussion-id-or-url>] [--thread-id <thread-id>] [next-unresolved|--next-unresolved] [--json-only]
```

**resolve** — Resolve one or more threads on GitHub.

```bash
"$SCRIPT" resolve <pr-url> \
  --thread-id <id1> [--thread-id <id2> ...]
```
