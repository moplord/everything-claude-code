---
name: requirements-system
description: Use when you want to author requirements at scale (multi-scope, shared DB, optional microservices) with zero-guess downstream derivation using REQ + appendix, strong metadata, and audit gates.
---

# Requirements System (Scalable, Zero-Guess)

This skill defines the requirements system semantics used by the other requirements skills.
It is designed for large projects where:
- multiple "scopes" (apps/clients/entrypoints) exist,
- a shared database model exists (single JDL source),
- microservices may or may not be adopted,
- requirements must remain human-readable while enabling deterministic derivation.

## Core Concepts

### REQ = Authoritative Contract

Each requirement is a dual-file authoritative spec:
- `REQ-XXX-<title>.md` (main doc, human narrative)
- `REQ-XXX-<title>-appendix.md` (structured tables, derivation-ready)

Both files are authoritative. Neither may contain JDL syntax or CI YAML.

### Mode A (Flat Files, Indexed Hierarchy)

All REQ files remain in a single directory (e.g. `requirements/REQ-*.md`).
Hierarchy is represented via metadata (`Level`, `Parent`) and a generated index (`requirements/INDEX.md`).
This keeps storage simple while allowing large projects to be navigated deterministically.

### Ledger (No Silent Drift)

To make requirements "auditably authoritative" over time, keep a committed ledger
(`requirements/.audit/ledger.json`) that records hashes and versions per REQ. This prevents:
- edits without version bump,
- edits without changelog entry,
- "I forgot to update the appendix/acceptance checklist".

### Scopes (Not "mp/admin")

`Scopes` is an arbitrary set of labels representing consumers:
- examples: `web`, `mp`, `ios`, `android`, `batch`, `partner`, `ops`

Do not hardcode scope names in templates or tooling.

### Shared Database Model Ownership

To prevent conflicts when multiple scopes share one DB:
- Only `Type=domain-model` requirements may define entities/fields/relationships/enums.
- All other requirements must reference the owning domain-model requirement version and
  must not redefine types/lengths/relationships.

### Naming: Display vs Code Identifiers (No Physical Names)

Requirements stay human-readable, but downstream derivation must not guess identifiers.
Use two layers of naming in `Type=domain-model` appendices:
- Display name (human): typically Chinese
- Code identifiers (machine): `EntityCode` (PascalCase) and `FieldCode` (camelCase)

Other REQs should reference model items via `EntityCode.FieldCode` (e.g. `Product.mainImage`).
Do not introduce physical naming (`table_name`/`column_name`) into requirements unless it is a hard external contract,
in which case record it explicitly as a decision (ADR) and keep it out of the core model tables.

### Optional Microservices

Use `Service` to express ownership boundaries:
- `Service: monolith` (or empty) means a single codebase/system.
- `Service: <service-name>` for microservices (e.g. `catalog`, `order`).
- `Service: cross-service` for cross-service contracts.

## Required Metadata (Header Fields)

Every REQ + appendix must include these lines near the top:
- `Status: ...`
- `Version: vX.Y.Z`
- `Owner: ...`
- `Last Updated: YYYY-MM-DD`
- `Type: ...`
- `Level: L0|L1|L2|...`
- `Parent: REQ-XXX-...` (optional)
- `Scopes: ...` (required for consumer-facing requirements)
- `References: ...` (required for consumer-facing requirements)
- `Service: ...` (optional; required if you are using microservices)

## Change, Refactor, Delete (How It Exists Over Time)

- Refactor/meaning change: bump `Version`, update `Last Updated`, and append an entry to `requirements/CHANGELOG.md`.
- Superseded requirement: keep the old REQ file, set `Status: DEPRECATED`, and add a link to the replacing REQ in the body.
- Deleted scope: prefer `DEPRECATED` + explanation over physically deleting the file, so history remains auditable.

## Type Taxonomy (Minimal Set)

Recommended `Type` values (extend if needed, but keep the set small):
- `system`: overall product/system behavior
- `cross-cutting`: auth/logging/security/observability standards (requirements-level)
- `domain-model`: shared DB/domain model (single source for JDL derivation)
- `consumer-feature`: a feature delivered to one or more Scopes (UI/API behavior + field projection)
- `cross-service-contract`: requirements-level API/event contract between services
- `module`: a grouping/epic-level requirement that mainly organizes children

## Audit Gates (Enforced)

Before a REQ can be treated as authoritative for downstream derivation:
- run `$requirements-audit`
- resolve all placeholder values and open questions for APPROVED status
- ensure consumer-feature references a domain-model version

## Scale Strategy (When Requirements Get Huge)

To keep "requirements as authority" workable when the set grows beyond LLM context:
- Use `INDEX.md` (generated) to locate relevant REQs by scope/type/service.
- Treat `Type=domain-model` as the only place where DB entities/fields/relations are defined.
- Keep each REQ narrow and link via `Parent` + `References` instead of writing mega-docs.
- For consumer features, use the appendix "Model Snapshot" to include only the subset needed to implement/test,
  so downstream steps don't have to open the full domain-model every time.

- For downstream generation/testing, use a per-REQ "pack" (REQ + appendix + acceptance + ADRs + optionally referenced REQs)
  instead of feeding the entire requirements directory into context.
