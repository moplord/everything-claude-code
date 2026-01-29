---
name: db-plan
description: Generate and validate DB-agnostic data/performance plans (indexes, access patterns, cache contracts) from Type=domain-model requirements without choosing a database vendor.
---

# DB Plan (Domain-Model -> DB-Agnostic Plan)

This skill generates a database-agnostic plan from `Type=domain-model` appendices.

Important:
- This does NOT replace JHipster/Liquibase table generation.
- This does NOT choose a DB vendor (MySQL/Postgres/etc).
- This captures **requirements-level physical intent** (indexes, access patterns, caching), so later steps can implement
  migrations or caching correctly without guessing.

## Inputs

Source is the domain-model appendix.

Required:
- A1 Entities (`EntityCode`)
- A2 Field Dictionary (`EntityCode.FieldCode`)

Optional but recommended for large projects:
- D1 Access Patterns (query budget, filters/sorts/pagination)
- D2 Index Plan (single/composite index intent)
- D3 Cache Plan (Redis or other cache contracts; keys/TTL/invalidation)

All references are expressed via concept identifiers, never physical names:
- `EntityCode` / `FieldCode`
- `EntityCode.FieldCode`

## Outputs

Generated files:
- `jdl/generated/<service>/REQ-XXX.db-plan.md`

The plan is DB-agnostic and traceable to a REQ version.

## Commands

Generate plans:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<path-to-skill>/scripts/db-plan-generate.ps1" `
  -RequirementsRoot requirements `
  -OutRoot jdl/generated
```

Validate plans:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<path-to-skill>/scripts/db-plan-validate.ps1" `
  -RequirementsRoot requirements `
  -OutRoot jdl/generated
```

