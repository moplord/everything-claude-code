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
  CONVERSATIONS/
  DECISIONS/
  ACCEPTANCE/
  REQ-001-<title>.md
  REQ-002-<title>.md
```

## Bootstrap the Requirements Workspace

From the target repo root, run:

```powershell
powershell -ExecutionPolicy Bypass -File "<path-to-skill>/scripts/req-init.ps1" -RootPath requirements
```

This creates the folder structure + baseline files using the templates bundled in this skill.

## Authoring Procedure (Deterministic)

### Step 0: Input Gate

Require one of:
- an "elicitation packet" (preferred; use `$requirements-elicitation`), or
- a clear written problem statement plus enough answers to avoid inventing details.

### Step 1: Create a New REQ File

```powershell
powershell -ExecutionPolicy Bypass -File "<path-to-skill>/scripts/req-new.ps1" -RootPath requirements -Title "short title"
```

Rules:
- The REQ file is the single source of truth for scope and acceptance.
- Use SHALL/SHOULD/MAY for requirements language.
- Explicitly list Non-Goals (to prevent scope creep).

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

### Step 4: Record Decisions (ADRs) When Needed

If a decision affects meaning/constraints (not just code style), create an ADR:
`requirements/DECISIONS/REQ-XXX-ADR-YYY-<title>.md`

Link ADRs from the REQ.

### Step 5: Update INDEX + CHANGELOG

- Add the REQ to `requirements/INDEX.md` with status + current version.
- Append a `requirements/CHANGELOG.md` entry for any meaning-changing update.

## Versioning Rules

REQ version format: `vMAJOR.MINOR.PATCH`
- MAJOR: breaking change to behavior/scope/contract
- MINOR: additive requirement change
- PATCH: clarifications that do not change meaning

Rule:
- If meaning changes, you MUST bump version and append to `CHANGELOG.md`.

## Audit Gate (Required)

Before treating a REQ as approved, run `$requirements-audit` (or execute its script) to
ensure the document set is consistent and enforceable.

