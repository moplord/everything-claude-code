# Codex Project Instructions

This repository is organized for Codex-first usage.

## What This Repo Contains

- Codex skills: `.codex/skills/*`
- Legacy reference material (original Claude Code plugin content): `agents/`, `commands/`, `hooks/`, `rules/`, `.claude-plugin/`

## How To Work In This Repo

- Prefer `rg` for searching and `rg --files` for listing files.
- Make changes incrementally and keep diffs small.
- Do not introduce non-ASCII characters unless the file already contains them.

## Default Quality Bar

- Immutability: do not mutate input objects/arrays; return new values.
- Error handling: handle errors explicitly; do not swallow failures silently.
- Testing: write or update tests when behavior changes; keep coverage expectations high.
- Logging: avoid `console.log` in production code paths; use structured logging when needed.

## How To Use Skills In Codex

- Use the Codex skills in `.codex/skills/*` by explicitly referencing them in your request
  (e.g. "$tdd-workflow", "$security-review", "$verification-loop") or by selecting them in Codex.

## Notes

- Do not add new "requirements/JDL" automation unless explicitly requested. This repo will later gain
  a requirements authoring workflow, but not in the current refactor phase.

