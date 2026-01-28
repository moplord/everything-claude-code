# Everything Codex (Project Skills)

This repository is organized for Codex-first usage.

## What You Get

- A curated set of Codex skills under `.codex/skills/` (planning, TDD, security review, verification, etc.)
- A single project instruction entrypoint in `AGENTS.md`
- Legacy Claude Code plugin materials are preserved under `legacy/claude-code/` but are not part of the Codex layout

## How To Use (Project-Local)

Run Codex from this repository root. Codex automatically discovers project skills in:

- `.codex/skills/`

Then invoke skills explicitly (recommended) in your request, e.g.:

- `$tdd-workflow`
- `$security-review`
- `$verification-loop`

## How To Use (Global Install)

If you want these skills available across projects, copy `.codex/skills/*` into your Codex home skills directory:

- Windows (typical): `%USERPROFILE%\\.codex\\skills\\`
- macOS/Linux (typical): `~/.codex/skills/`

## Repo Layout

```
.
|-- AGENTS.md
|-- .codex/
|   |-- skills/
|-- legacy/
|   |-- claude-code/   # Not used by Codex, kept for reference
```

