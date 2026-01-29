---
name: jdl-derivation
description: Derive deterministic JHipster JDL (entities/enums/relationships) from Type=domain-model requirement appendices, split by Service + REQ (no guessing, no CI/YAML).
---

# JDL Derivation (Domain-Model -> JDL, Zero-Guess)

This skill turns authoritative `Type=domain-model` requirements into JHipster JDL files.

Scope:
- Inputs: `Type=domain-model` only (appendix tables are the source of truth).
- Outputs: JDL *entities/enums/relationships* only (no `application {}` blocks here).
- Non-goals: choose tech stack, CI, database vendor specifics, or any YAML.

## Why

You want JDL generation to be:
- deterministic (no "AI guessing"),
- traceable (each output links to REQ + version),
- scalable (many small JDL files, not a monolith file).

## Inputs (Required Format)

JDL derives from the **domain-model appendix** tables (see `requirements/templates/APPENDIX-DOMAIN-TEMPLATE.md`):

- A1 Entities: must include `EntityCode`
- A2 Field Dictionary: must include `EntityCode` + `FieldCode` + `Type Candidates (JDL)`
- A3 Enums: must include `Enum` + `Value`
- A4 Relationships: must include
  - `Entity A (EntityCode)`, `Entity B (EntityCode)`
  - `Cardinality` in `{1:1,1:N,N:1,N:N}`
  - relationship field names: `Field On A`, `Field On B`

Naming:
- Use `EntityCode` (PascalCase) for JDL entity names.
- Use `FieldCode` (camelCase) for JDL field names.
- Never use physical `table_name/column_name` in requirements.

## Outputs

Generated files live under:
- `jdl/generated/<service>/REQ-XXX.jdl`

Rules:
- `<service>` comes from REQ header `Service:`; default is `monolith` if empty.
- One file per domain-model REQ (keeps diffs small and large projects manageable).

## Commands

Derive JDL for all domain-model REQs in a target repo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<path-to-skill>/scripts/jdl-derive.ps1" `
  -RequirementsRoot requirements `
  -OutRoot jdl/generated
```

Derive for one REQ:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<path-to-skill>/scripts/jdl-derive.ps1" `
  -RequirementsRoot requirements `
  -ReqId REQ-010 `
  -OutRoot jdl/generated
```

Validate:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<path-to-skill>/scripts/jdl-validate.ps1" `
  -RequirementsRoot requirements `
  -OutRoot jdl/generated
```

## Deterministic Failures (By Design)

The scripts will fail (non-zero exit) if:
- any required table/column is missing,
- a referenced `EntityCode/FieldCode` does not exist,
- a field type is ambiguous (multiple candidates) or empty,
- relationships are missing required field names.

This is intentional: incomplete requirements are not allowed to silently generate broken JDL.

