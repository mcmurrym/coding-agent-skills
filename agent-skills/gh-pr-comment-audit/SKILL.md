---
name: gh-pr-comment-audit
description: Audit GitHub pull request review comments against the branch's stated purpose, analyze upstream and downstream effects before changing code, prevent speculative mechanical scope creep, auto-fix only small safe issues, resolve justified threads, and present ambiguous or non-trivial decisions in chat.
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
- Outcome: <real / not real + rationale>

If a finding cannot be verified from the available context, classify it as **non-trivial** and ask for confirmation, rather than resolving it as not real.

#### Required fix-impact analysis

Before making any code change, analyze the proposed fix itself, not only the reviewer's symptom. Trace:

- **Upstream effects:** callers, inputs, producers, shared helpers, contracts, and state that can now reach the changed code differently.
- **Downstream effects:** consumers, outputs, persistence, side effects, error handling, retries, UI/API behavior, and tests that observe the changed result.
- **Boundary effects:** existing behavior outside the changed path, compatibility, performance, concurrency, security, and failure modes.

State the smallest fix that addresses the verified cause and list at least one regression check for the affected upstream/downstream path. If the proposed fix only makes the code more generalized, defensive, abstract, or theoretically complete without a demonstrated branch-related impact, classify it as an adjacent improvement and do not implement it automatically.

When a new review comment is caused by a previous review-driven fix, re-evaluate the whole chain against the original purpose. Prefer reverting or simplifying the prior fix when it created the new complexity, rather than layering another mechanical fix on top. Do not continue an iterative “fix the fix” chain without showing a concrete user/runtime impact and a bounded end state.

Only after verification, classify each thread/comment into one of three buckets:

1. **Not a real issue** — false positive, stale/outdated, style nit that doesn't apply, etc.
2. **Real issue, trivial in-scope fix** — small one-liner or obvious change whose upstream/downstream impact is understood and bounded.
3. **Real issue, non-trivial or out of scope** — needs thought, has trade-offs, touches multiple places, is speculative, or would expand the branch purpose.

### Step 4 — Act on each bucket

**Research gate for all classifications**

- A thread is **Not a real issue** only if you can point to one concrete reason from evidence that the comment is invalid (for example, outdated thread, duplicate/already-fixed behavior, or the claimed behavior does not exist in the changed path).
- If evidence is incomplete or contradictory, default to **Real issue, non-trivial**.
- A valid comment is not automatically in scope. If it is an adjacent improvement with no concrete impact on the branch contract, do not implement it; present it as **out of scope** and ask only if the user wants to expand the purpose.
- Do not call a fix trivial just because the diff is small. It is trivial only when the cause, purpose fit, upstream/downstream effects, and regression check are all clear.

**Not a real issue →** Resolve the thread on GitHub after documenting the evidence briefly in chat:

```bash
"$SCRIPT" resolve <pr-url> --thread-id <id>
```

You may batch multiple thread IDs in one call.

In targeted comment mode, follow the targeted resolution rule above before resolving the parent thread.

**Real issue, trivial in-scope fix →** Fix the code directly (edit the file), perform the required fix-impact analysis, verify the local change matches the comment intent and branch purpose, run the regression check, then resolve the thread on GitHub:

```bash
"$SCRIPT" resolve <pr-url> --thread-id <id>
```

You may batch multiple thread IDs in one call. No comment is needed — just resolve.

In targeted comment mode, follow the targeted resolution rule above before resolving the parent thread.

**Real issue, non-trivial or out of scope →** Do NOT fix or resolve automatically. Instead, present the analysis in chat using this format:

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

Use code blocks only when the code itself clarifies the suggested solution:

> ```<lang>
> <concrete code showing a possible fix>
> ```

Required minimum for every non-trivial item:

1. Confirm whether the thread is outdated/stale.
2. Include exact `path`, `line`, and `commit` references where available.
3. State whether it is core-purpose, necessary supporting change, or adjacent improvement.
4. Describe relevant upstream and downstream effects of the suggested fix.
5. Include one concrete validation step that proves the impact.

### Step 5 — Summary

After processing all threads, output a summary:

| Category | Count | Action taken |
|----------|-------|-------------|
| Not real / stale | N | Resolved on GitHub |
| Trivial in-scope fixes | N | Fixed in code + resolved on GitHub |
| Non-trivial / out of scope | N | Presented above; no automatic code change |

### Step 6 — Follow-up

If the user asks you to fix any of the non-trivial issues:
1. Make the code changes.
2. Reconfirm the expanded purpose and repeat the upstream/downstream impact analysis.
3. Resolve the corresponding threads on GitHub.

## Setup

- Requires `gh` authentication with repository access and permission to resolve review threads.

## Script

**Always use the bundled script for all GitHub API calls. Never construct `gh api graphql` commands inline — they break due to quote mangling.**

Resolve the script path:

```bash
SCRIPT="$CODEX_HOME/agent-skills/gh-pr-comment-audit/scripts/review-pr-comments.sh"
```

If `CODEX_HOME` is not set, use the absolute workspace path:

```bash
SCRIPT="/Users/mattmcmurry/coding-agent-skills/agent-skills/gh-pr-comment-audit/scripts/review-pr-comments.sh"
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
