# Contributing

This repository is organized for Codex-first usage.

## What To Contribute

- New or improved Codex skills under `.codex/skills/<skill-name>/SKILL.md`

Keep skills small, focused, and actionable.

## Skill Format

Each skill must have a `SKILL.md` with YAML frontmatter containing at least:

```yaml
---
name: your-skill-name
description: When to use this skill and what it does
---
```

Notes:
- Keep the `description` trigger-oriented (when/why you would use it).
- Extra YAML keys are allowed but should be used sparingly.

## Directory Layout

```
.codex/
  skills/
    your-skill-name/
      SKILL.md
      scripts/        (optional)
      references/     (optional)
      assets/         (optional)
```

## Hygiene

- Do not commit secrets or credentials.
- Prefer ASCII in new files.
- Validate changes with a quick read-through: triggers, steps, and examples should be consistent.

