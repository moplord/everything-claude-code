---
name: module-pack
description: Apply reusable infra module packs (patches/templates/verifiers) to a generated JHipster project in a deterministic, idempotent way.
---

# Module Packs (Reusable, Idempotent)

This skill defines a module-pack system for "post-scaffold" augmentation:
- cache (Redis)
- storage (S3-compatible: S3/OSS/MinIO)
- MQ (RocketMQ/Kafka/RabbitMQ)
- quality tooling (SonarQube)
- jobs (scheduler)

Principles:
- Modules are stored once (in this repo/skill) and applied to many projects.
- Modules never vendor dependencies; they only patch build files and add minimal wrapper code.
- Modules must be idempotent: applying twice must not duplicate content.
- Modules must be verifiable: each module provides a minimal deterministic verify script.

## Storage

Module packs live under:
- `.codex/skills/module-pack/assets/modules/<moduleName>/`

Each module directory contains:
- `manifest.json` (metadata + declared file edits)
- `patches/` (snippets and markers)
- `templates/` (new files to copy in)
- `verify.ps1` (self-check in a target repo)

## Commands

List available modules:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<path-to-skill>/scripts/modules-list.ps1"
```

Apply modules to a target repo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<path-to-skill>/scripts/modules-apply.ps1" `
  -TargetDir "<target-project-dir>" `
  -Modules "storage-s3-compatible,cache-redis"
```

