# Requirements System (Authority-First)

This folder defines how we capture, review, and maintain product requirements as an
authoritative source of truth.

Important:
- Requirements documents are NOT JDL. JDL generation happens later and must be
  derived from the approved requirements, not mixed into them.
- This system is intentionally "heavy": it favors correctness, auditability, and
  downstream determinism over speed.

## Goals

- Single source of truth for "what to build" (business intent + acceptance criteria)
- Strong traceability (decisions, changes, risks, assumptions)
- Produce inputs that make later steps deterministic (JDL/code/tests/CI)
- Support iterative discussion without corrupting the authoritative spec

## Directory Layout

```
docs/requirements/
  README.md
  INDEX.md
  CHANGELOG.md
  templates/
    REQ-TEMPLATE.md
    ADR-TEMPLATE.md
    ACCEPTANCE-TEMPLATE.md
  CONVERSATIONS/
    (working notes and AI discussion logs)
  DECISIONS/
    (ADRs: architectural/product decisions for a given REQ)
  ACCEPTANCE/
    (acceptance checklists mapped from REQs)
  REQ-XXX-*.md
    (authoritative requirement specs)
```

## The Core Artifacts

1) Authoritative Requirement (REQ)
- File: `REQ-XXX-<short-title>.md`
- This is the only document considered "truth" for scope and acceptance.

2) Conversation Log (DISCUSSION)
- File: `CONVERSATIONS/REQ-XXX-discussion.md`
- Captures exploration, alternatives, unresolved questions, and rough notes.
- This file is allowed to be messy. It is NOT authoritative.

3) Decision Record (ADR)
- File: `DECISIONS/REQ-XXX-ADR-YYY-<short-title>.md`
- Records a decision that impacts how the requirement will be implemented or
  interpreted (tradeoffs, constraints, why A not B).

4) Acceptance Checklist
- File: `ACCEPTANCE/REQ-XXX-acceptance.md`
- A normalized checklist derived from the REQ acceptance criteria. This becomes
  a bridge to tests and CI later.

5) Requirements Changelog
- File: `CHANGELOG.md`
- A single log of requirement updates (version bumps, rationale, impact).

## Workflow (Discussion -> Authority)

### Phase 0: Create a REQ ID

- Pick the next number: `REQ-001`, `REQ-002`, ...
- Create:
  - `REQ-XXX-<short-title>.md` from `templates/REQ-TEMPLATE.md`
  - `CONVERSATIONS/REQ-XXX-discussion.md` from the discussion section in the REQ
    template (or start as free-form notes)

### Phase 1: Discussion (non-authoritative)

Goal: converge on intent, boundaries, and acceptance criteria.

Rules:
- Keep speculation and alternatives in `CONVERSATIONS/`.
- Promote only confirmed statements into the REQ.
- Every time you "promote" something, ensure it is testable via acceptance criteria.

### Phase 2: Authority Draft (REQ v0.1 -> v1.0)

Goal: produce a complete, unambiguous spec.

Minimum bar for v1.0:
- Clear scope + explicit non-goals
- Acceptance criteria that are verifiable (no vague words like "fast" without metrics)
- Risks/assumptions/unknowns captured
- Dependencies and constraints listed
- Naming/terminology defined (glossary)

### Phase 3: Decisions (ADRs)

When a decision is needed (e.g., "multi-tenant by schema vs db", "sync vs async"),
record it as an ADR and link it from the REQ.

### Phase 4: Freeze for Downstream Generation

Once REQ is approved (v1.0):
- Do not "quietly edit" the meaning. Any scope change requires:
  - a version bump in the REQ
  - an entry in `CHANGELOG.md`
  - updated acceptance checklist

## Versioning Rules

- REQ version format: `vMAJOR.MINOR.PATCH`
  - MAJOR: breaking change to scope/behavior/contract
  - MINOR: additive requirement change (new acceptance criteria, new flows)
  - PATCH: editorial clarifications that do not change meaning

## Relationship to Later JDL (Explicit Separation)

- REQ answers: "what + why + acceptance"
- JDL answers: "how to declare entities/relations/config for generation"

When we later add a JDL step:
- JDL must be derived from REQ v1.0+.
- If JDL cannot be generated without inventing details, that indicates the REQ is
  incomplete and must be revised (with a proper version bump and changelog entry).

