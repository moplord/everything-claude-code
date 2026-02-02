---
name: requirements-authoring
description: Use when you need to create or update authoritative requirements in a target project repo (REQ/ADR/AC/Index/Changelog), strictly separated from JDL/code generation.
---

# Requirements Authoring (Authority-First)

This skill defines a strict, repeatable requirements workflow for a *target project
repository*. The output is an authoritative requirements set that downstream steps
can derive from (including JDL later), without guessing missing details.

Important:
- Requirements are NOT JDL.
- Do not include generator schemas, entity declarations, or implementation details.
- If you cannot write a REQ without inventing details, the requirement is incomplete.

## Where Requirements Live (Target Repo)

Default root folder (configurable): `requirements/`
Default locale: `zh-CN` (supports `en-US`)

Layout:
```
requirements/
  README.md
  INDEX.md
  CHANGELOG.md
  templates/
    REQ-TEMPLATE.md
    ADR-TEMPLATE.md
    ACCEPTANCE-TEMPLATE.md
    APPENDIX-DOMAIN-TEMPLATE.md
    APPENDIX-CONSUMER-TEMPLATE.md
    APPENDIX-GENERIC-TEMPLATE.md
    APPENDIX-CROSS-SERVICE-TEMPLATE.md
  CONVERSATIONS/
  DECISIONS/
  ACCEPTANCE/
  REQ-001-<title>.md
  REQ-001-<title>-appendix.md
  REQ-002-<title>.md
```

## Bootstrap the Requirements Workspace

From the target repo root, run:

```powershell
powershell -ExecutionPolicy Bypass -File "<path-to-skill>/scripts/req-init.ps1" -RootPath requirements -Locale zh-CN
```

This creates the folder structure + baseline files using the templates bundled in this skill.

## Authoring Procedure (Deterministic)

### Step 0: Input Gate

Require one of:
- an "elicitation packet" (preferred; use `$requirements-elicitation`), or
- a clear written problem statement plus enough answers to avoid inventing details.

### Step 1: Create a New REQ File

```powershell
powershell -ExecutionPolicy Bypass -File "<path-to-skill>/scripts/req-new.ps1" `
  -RootPath requirements `
  -Title "short title" `
  -Type consumer-feature `
  -Level L3 `
  -Parent "" `
  -Scopes "web,mp" `
  -References "REQ-001 (v1.2.0)" `
  -Service "monolith" `
  -Owner "team" `
  -Locale zh-CN
```

Rules:
- The REQ file is the single source of truth for scope and acceptance.
- Use SHALL/SHOULD/MAY for requirements language.
- Explicitly list Non-Goals (to prevent scope creep).
- The appendix file is equally authoritative, but contains structured, derivation-ready tables.
- `req-new.ps1` also creates `requirements/ACCEPTANCE/REQ-XXX-acceptance.md` as a checklist scaffold.

Naming:
- Keep the REQ narrative human-friendly (Chinese is fine).
- In `Type=domain-model` appendices, assign stable code identifiers:
  - `EntityCode` (PascalCase) and `FieldCode` (camelCase).
- In consumer appendices, reference fields via `EntityCode.FieldCode` (never "guess" English names).

### Step 2: Acceptance Criteria Must Be Verifiable

Each AC must be:
- specific
- testable
- unambiguous

Avoid:
- "fast", "secure", "scalable", "user friendly" without measurable criteria
- "etc.", "and so on"
- hidden requirements implied by implementation decisions

### Step 3: Create an Acceptance Checklist

Create `requirements/ACCEPTANCE/REQ-XXX-acceptance.md` from the acceptance template.
It should map 1:1 to AC items and include an "Evidence" section for later verification.

### Step 3.5: Fill the Appendix (Required for Approval)

Create and maintain `requirements/REQ-XXX-<title>-appendix.md` using the appendix template selected by `-Type`.

The appendix is still a requirements document (human-readable), but it MUST be structured
enough to allow downstream generation (JDL/tests/CI) without guessing. It MUST NOT contain
JDL syntax or CI YAML.

### Step 4: Record Decisions (ADRs) When Needed

If a decision affects meaning/constraints (not just code style), create an ADR:
`requirements/DECISIONS/REQ-XXX-ADR-YYY-<title>.md`

Link ADRs from the REQ.

### Step 5: Update INDEX + CHANGELOG

- Add the REQ to `requirements/INDEX.md` with status + current version.
- Append a `requirements/CHANGELOG.md` entry for any meaning-changing update.

For large projects, prefer generating the index deterministically (Mode A: flat files, tree via metadata):

```powershell
powershell -ExecutionPolicy Bypass -File "<path-to-skill>/scripts/req-index.ps1" -RootPath requirements
```

## Ledger (Change Tracking Gate)

To prevent silent drift and enforce "change => version bump + changelog", maintain a ledger:

```powershell
powershell -ExecutionPolicy Bypass -File "<path-to-skill>/scripts/req-ledger.ps1" -RootPath requirements
```

This writes/updates `requirements/.audit/ledger.json` and fails if a REQ changed without a version bump
or a CHANGELOG entry.

## Req Pack (LLM Context Slicing)

When the requirements set is too large to fit in context, generate a minimal authoritative packet for one REQ:

```powershell
powershell -ExecutionPolicy Bypass -File "<path-to-skill>/scripts/req-pack.ps1" -RootPath requirements -ReqId REQ-001 -IncludeReferences -IncludeDecisions
```

## Versioning Rules

REQ version format: `vMAJOR.MINOR.PATCH`
- MAJOR: breaking change to behavior/scope/contract
- MINOR: additive requirement change
- PATCH: clarifications that do not change meaning

Rule:
- If meaning changes, you MUST bump version and append to `CHANGELOG.md`.

Deletion:
- Prefer `Status: DEPRECATED` + explanation (and link to replacement) over deleting REQ files,
  so downstream audits and traceability remain possible.

## Audit Gate (Required)

Before treating a REQ as approved, run `$requirements-audit` (or execute its script) to
ensure the document set is consistent and enforceable.
