# CodeRabbit Codex Integration Reference

Source:
- https://docs.coderabbit.ai/cli/codex-integration

## Canonical command patterns

- Default review from current branch context:
`coderabbit --prompt-only`

- Review uncommitted changes:
`coderabbit --prompt-only --type uncommitted`

- Review using explicit base branch:
`coderabbit --prompt-only --base <branch-name>`

## Reported troubleshooting commands

- Authenticate CLI:
`coderabbit auth login`

- Complete CLI installation setup:
`coderabbit setup-installation`

## Notes

- `--prompt-only` is the integration mode intended for Codex-style review loops.
- Use `--type uncommitted` when user wants feedback before committing changes.
- Use `--base` when branch ancestry is unclear or non-standard.
