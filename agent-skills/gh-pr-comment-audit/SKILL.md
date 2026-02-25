---
name: gh-pr-comment-audit
description: Download review comments from a GitHub pull request URL via gh api, evaluate whether each finding is real, auto-fix trivial issues, resolve non-real threads on GitHub, and present complex issues in chat for the user to decide on.
---

# GitHub PR Comment Audit

Use this skill to triage a pull request's unresolved review comments.

## Workflow

### Step 1 — Fetch unresolved threads

```bash
./review-pr-comments.sh fetch <pr-url>
```

### Step 2 — Read and evaluate each thread

For every unresolved thread, read the comment body and the surrounding source code. Classify each thread into one of three buckets:

1. **Not a real issue** — false positive, stale/outdated, style nit that doesn't apply, etc.
2. **Real issue, trivial fix** — small one-liner or obvious change you can make right now.
3. **Real issue, non-trivial** — needs thought, has trade-offs, or touches multiple places.

### Step 3 — Act on each bucket

**Not a real issue →** Resolve the thread on GitHub immediately:

```bash
./review-pr-comments.sh resolve <pr-url> --thread-id <id>
```

You may batch multiple thread IDs in one call. No comment is needed — just resolve.

**Real issue, trivial fix →** Fix the code directly (edit the file), then resolve the thread on GitHub:

```bash
./review-pr-comments.sh resolve <pr-url> --thread-id <id>
```

**Real issue, non-trivial →** Do NOT fix or resolve. Instead, present the analysis in chat using this format:

> **`<file>:<line>`** — <one-line summary of the review comment>
>
> **Problem:** <clear explanation of what's wrong>
>
> **Suggested fix:**
> ```<lang>
> <concrete code showing a possible fix>
> ```
>
> **Trade-offs / notes:** <anything the user should know before deciding>

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

## Helper script

```bash
"$CODEX_HOME/agent-skills/gh-pr-comment-audit/scripts/review-pr-comments.sh"
```

If `CODEX_HOME` is not set, use the absolute workspace path:

```bash
"/Users/mattmcmurry/coding-agent-skills/agent-skills/gh-pr-comment-audit/scripts/review-pr-comments.sh"
```

### Commands

**fetch** — Download unresolved review threads (read-only).

```bash
./review-pr-comments.sh fetch <pr-url> [--json-only]
```

**resolve** — Resolve one or more threads on GitHub.

```bash
./review-pr-comments.sh resolve <pr-url> \
  --thread-id <id1> [--thread-id <id2> ...]
```

## Direct gh api equivalents

Fetch unresolved threads:

```bash
gh api graphql -f query='query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$number){reviewThreads(first:100, states:[UNRESOLVED]){nodes{id isResolved isOutdated path line comments(first:20){nodes{id author{login} body originalLine originalPosition diffHunk originalCommit{oid} path line url}}}}}}}' -F owner=<owner> -F repo=<repo> -F number=<number>
```

Resolve a thread:

```bash
gh api graphql -f query='mutation($threadId:ID!){resolveReviewThread(input:{threadId:$threadId,clientMutationId:"gh-pr-comment-audit"}){thread{isResolved id}}}' -F threadId=<thread_id>
```
