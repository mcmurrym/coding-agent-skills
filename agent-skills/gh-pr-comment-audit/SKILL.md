---
name: gh-pr-comment-audit
description: Download GitHub pull request review comments via gh api, evaluate all unresolved comments or one targeted discussion/next unresolved comment, auto-fix trivial issues, resolve safe threads, and present complex issues in chat.
---

# GitHub PR Comment Audit

Use this skill to triage a pull request's unresolved review comments.

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

### Step 1 — Fetch unresolved threads

```bash
"$SCRIPT" fetch <pr-url>
```

For targeted mode, use one of the targeted fetch forms above.

### Step 2 — Read and evaluate each thread

For every unresolved thread, or the single selected comment in targeted mode, review in this order:

1. Read the full review thread: comment body, `isOutdated`, `path`, `line`, `startLine`, and `diffHunk`.
2. Open the referenced file at the relevant line range (or nearest equivalent commit/version if outdated).
3. Confirm whether the review point still applies in the current diff.

Use this evidence template (required before bucket placement):

- Finding: <what the selected review comment is claiming>
- Scope check: <file/path + line + old/new commit context if outdated>
- Evidence: <specific code excerpt or API behavior confirming or disproving>
- Outcome: <real / not real + rationale>

If a finding cannot be verified from the available context, classify it as **non-trivial** and ask for confirmation, rather than resolving it as not real.

Only after verification, classify each thread/comment into one of three buckets:

1. **Not a real issue** — false positive, stale/outdated, style nit that doesn't apply, etc.
2. **Real issue, trivial fix** — small one-liner or obvious change you can make right now.
3. **Real issue, non-trivial** — needs thought, has trade-offs, or touches multiple places.

### Step 3 — Act on each bucket

**Research gate for all classifications**

- A thread is **Not a real issue** only if you can point to one concrete reason from evidence that the comment is invalid (for example, outdated thread, duplicate/already-fixed behavior, or the suggested change is outside changed behavior).
- If evidence is incomplete or contradictory, default to **Real issue, non-trivial**.

**Not a real issue →** Resolve the thread on GitHub after documenting the evidence briefly in chat:

```bash
"$SCRIPT" resolve <pr-url> --thread-id <id>
```

You may batch multiple thread IDs in one call.

In targeted comment mode, follow the targeted resolution rule above before resolving the parent thread.

**Real issue, trivial fix →** Fix the code directly (edit the file), verify the local change matches the comment intent, then resolve the thread on GitHub:

```bash
"$SCRIPT" resolve <pr-url> --thread-id <id>
```

You may batch multiple thread IDs in one call. No comment is needed — just resolve.

In targeted comment mode, follow the targeted resolution rule above before resolving the parent thread.

**Real issue, non-trivial →** Do NOT fix or resolve. Instead, present the analysis in chat using this format:

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
> - <remaining risk, alternative, or reason to ask the user>

When a trivial fix was made, summarize it with progressive bullets:

> **Fixed `<file>:<line>`**
> - <issue fixed>
> - <change made>
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
3. Include one concrete validation step that proves the impact.

### Step 4 — Summary

After processing all threads, output a summary:

| Category | Count | Action taken |
|----------|-------|-------------|
| Not real / stale | N | Resolved on GitHub |
| Trivial fixes | N | Fixed in code + resolved on GitHub |
| Non-trivial (awaiting decision) | N | Presented above |

### Step 5 — Follow-up

If the user asks you to fix any of the non-trivial issues:
1. Make the code changes.
2. Resolve the corresponding threads on GitHub.

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
