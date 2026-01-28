# Codex Project Instructions

This repository is Codex-first.

## Entry Points

- Project instructions: `AGENTS.md` (this file)
- Project skills: `.codex/skills/`

Legacy Claude Code plugin materials are preserved under `legacy/claude-code/` and are not used by Codex.

## Working Style

- Prefer `rg` for searching and `rg --files` for listing files.
- Keep diffs small and scoped; avoid drive-by refactors.
- Default to ASCII; only keep non-ASCII if the file already uses it.

## Quality Bar (Always On)

- Immutability: do not mutate inputs; return new values.
- Error handling: handle failures explicitly; no silent catch-and-ignore.
- Testing: update/add tests when behavior changes.
- Logging: avoid `console.log` in production paths.

## Using Skills

Explicitly reference skills when you want a specific workflow, for example:

- `$tdd-workflow`
- `$security-review`
- `$verification-loop`

## Scope Guardrail

Do not add new "requirements/JDL" automation unless explicitly requested. This repo will gain a
requirements authoring workflow later, but not during the current Codex refactor phase.

## Requirements Docs

The requirements documentation system lives under:
- `docs/requirements/`

Requirements are authoritative; JDL is a downstream artifact and must remain separate.
