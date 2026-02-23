---
name: gh-pr-comment-audit
description: Download review comments from a GitHub pull request URL via gh api, evaluate whether each finding is real, post suggested fixes for real issues, and resolve non-real findings by marking their review threads as resolved.
---

# GitHub PR Comment Audit

Use this skill when you need to triage a pull request’s review comments as actionable findings.

## Workflow

1. Fetch unresolved review threads for a PR.
2. Evaluate each thread:
   - Real issue: propose and publish a concrete suggestion.
   - Non-real issue: resolve the thread directly using the GraphQL `resolveReviewThread` mutation.
3. Report:
   - list of threads resolved,
   - list of suggestions posted,
   - any threads left open for follow-up.

## Setup

- Requires `gh` authentication with repository access.
- Run from a machine with network access and GraphQL permissions for resolving review threads.

## Default helper script

Use the bundled script for deterministic API calls:

```bash
"$CODEX_HOME/agent-skills/gh-pr-comment-audit/scripts/review-pr-comments.sh"
```

If `CODEX_HOME` is not set, use the absolute workspace path:

```bash
"/Users/mattmcmurry/coding-agent-skills/agent-skills/gh-pr-comment-audit/scripts/review-pr-comments.sh"
```

## Script usage

### 1) Download unresolved threads

```bash
./review-pr-comments.sh fetch https://github.com/<owner>/<repo>/pull/<number>
```

Flags:
- `--json-only`: output raw GraphQL JSON (useful for downstream parsing).

This prints each unresolved review thread with:
- `thread_id` (use this for resolution),
- file path and line,
- every comment in the thread with author/body/commit/position.

### 2) Add suggestions for real issues

Create a suggestion body in Markdown (with optional `suggestion` fence) and post it as a new PR comment against the exact location.

```bash
./review-pr-comments.sh suggest <pr-url> \
  --thread-id <thread_id> \
  --path "src/example.ts" \
  --line 120 \
  --commit-id "<commit_sha>" \
  --body-file /tmp/suggestion.md
```

`--body-file` is required and should include the exact proposed change text.
- Use suggestion format when you have a concrete replacement.

```suggestion
// suggestion.md
<your exact replacement code>
```

### 3) Resolve non-real issues

Pass one or more thread IDs to close them as resolved.

```bash
./review-pr-comments.sh resolve <pr-url> \
  --thread-id <thread_id_1> \
  --thread-id <thread_id_2> \
  --reason "Not an issue (intended behavior)"
```

This calls the GitHub GraphQL API mutation to actually resolve the review threads (not just add a comment).

## Recommended process

- Use `fetch` first and read the returned threads.
- For each item:
  - if real, call `suggest`.
  - if non-real, call `resolve`.
- Keep a short final notes block in the review thread or ticket indicating what was triaged.

## Direct gh api equivalents (no script)

- Fetch unresolved review threads:

```bash
gh api graphql -f query='query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$number){reviewThreads(first:100, states:[UNRESOLVED]){nodes{id isResolved isOutdated path line comments(first:20){nodes{id author{login} body originalLine originalPosition diffHunk originalCommit{oid} path line url}}}}}}}' -F owner=<owner> -F repo=<repo> -F number=<number>
```

- Resolve a thread:

```bash
gh api graphql -f query='mutation($threadId:ID!){resolveReviewThread(input:{threadId:$threadId,clientMutationId:"codex-pr-audit"}){thread{isResolved id}}}' -F threadId=<thread_id>
```

- Create a suggestion reply:

```bash
gh api repos/<owner>/<repo>/pulls/<number>/comments -f body="$(cat /tmp/suggestion.md)" -f commit_id=<commit_sha> -f path=<path> -f line=<line> -f side="RIGHT"
```


## Example body templates

Use these files as `--body-file` content when posting suggestions:

- `examples/suggest-null-guard.md`
- `examples/suggest-query-filter.md`

Use this file for a standard non-issue closeout comment when not implementing a fix:

- `examples/non-issue-resolve.md`
