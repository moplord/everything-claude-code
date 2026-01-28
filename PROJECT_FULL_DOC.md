# Project Documentation (Codex Mode)

This repository is a Codex-first collection of reusable project skills.

## Goals

- Provide project-local Codex skills under `.codex/skills/`
- Provide a single, stable instructions entrypoint in `AGENTS.md`
- Keep legacy Claude Code materials under `legacy/claude-code/` (not used by Codex)

## How Codex Uses This Repo

Codex automatically discovers project skills from:

- `.codex/skills/`

Each skill is a folder containing a `SKILL.md` with a small YAML frontmatter. The skill body is
loaded only when the skill is selected or triggered.

## Key Paths

- `AGENTS.md`: project-wide instructions and guardrails
- `.codex/skills/`: Codex skills
- `legacy/claude-code/`: archived materials from the original Claude Code plugin layout

