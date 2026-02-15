---
name: coderabbit-codex-review
description: Run CodeRabbit CLI review from Codex and summarize actionable findings for the user. Use when the user asks to review current branch changes with CodeRabbit, run AI code review before commit/PR, inspect uncommitted changes, or troubleshoot CodeRabbit CLI output/authentication in Codex.
---

# CodeRabbit Codex Review

## Overview

Use this skill to invoke CodeRabbit CLI from the current repository and return a concise, prioritized review summary.

## Workflow

1. Confirm repository state.
Run `git status -sb` and `git rev-parse --abbrev-ref HEAD` to determine branch and whether local changes are uncommitted.

2. Choose review scope.
Use the default branch-based review command unless the user requests another scope.

- Review current branch diff:
```bash
coderabbit --prompt-only
```

- Review uncommitted local changes:
```bash
coderabbit --prompt-only --type uncommitted
```

- Review changes against a specific base branch:
```bash
coderabbit --prompt-only --base <branch-name>
```

3. Execute CodeRabbit and capture output.
Run the selected command from the repository root. Preserve raw output for parsing.

4. Return findings in review-first format.
List issues by severity and include file paths and line references when available. Keep summaries brief and concrete.

5. Apply troubleshooting when blocked.
If authentication or installation is missing, run:
```bash
coderabbit auth login
coderabbit setup-installation
```
Then rerun the review command.

## Output Requirements

- Prioritize bugs, regressions, security concerns, and missing test coverage.
- State explicitly when no findings are returned.
- Include residual risks when review signal is incomplete (for example, partial diff or CLI failure).

## Reference

Use `references/coderabbit-codex-integration.md` for the documented command patterns and troubleshooting notes.
