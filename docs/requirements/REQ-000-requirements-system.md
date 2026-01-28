# REQ-000 - Requirements System

Status: APPROVED
Version: v1.0.0
Owner: team
Last Updated: 2026-01-28

## 1. Summary

Define an authority-first requirements system that is:
- precise enough to be executable (acceptance-driven),
- traceable (decisions + changelog),
- and suitable as the single source of truth before downstream artifacts (JDL/code/CI).

## 2. Background / Context

We want a workflow where:
- we can discuss ideas freely,
- but still end up with a document that is "the truth" and does not drift,
- and later steps (JDL generation, code generation, CI) can be derived without inventing details.

## 3. Goals (Must Have)

- G1: Authoritative REQ documents with explicit scope and acceptance criteria.
- G2: A separate space for discussion notes and alternatives.
- G3: Decision recording (ADRs) for major interpretation/implementation-impacting choices.
- G4: Versioned requirements with a central changelog.

## 4. Non-Goals (Explicitly Out of Scope)

- NG1: JDL content inside requirement documents.
- NG2: Any automated JDL/code generation in this phase.
- NG3: CI integration in this phase.

## 5. Stakeholders

- Product: owns priority, scope, acceptance.
- Engineering: owns feasibility constraints, risks, and mapping to implementation later.
- Security/Ops: owns security and operational NFR acceptance.

## 6. Terminology / Glossary

- REQ: authoritative requirements specification.
- DISCUSSION: non-authoritative notes, exploration, and negotiation records.
- ADR: decision record.
- AC: acceptance criteria.

## 7. User Stories

- US1: As a contributor, I want a consistent REQ template so that every requirement is comparable and auditable.
- US2: As a reviewer, I want acceptance criteria so that I can objectively approve or reject the requirement.
- US3: As an implementer, I want clear non-goals and constraints so that I do not overbuild or invent scope.

## 8. Functional Requirements

- FR1 (SHALL): The system SHALL define a standard directory layout and naming convention for REQs, discussions, ADRs, and acceptance checklists.
- FR2 (SHALL): Each REQ SHALL include explicit Non-Goals and Acceptance Criteria.
- FR3 (SHALL): Each REQ SHALL be versioned and changes SHALL be recorded in `docs/requirements/CHANGELOG.md`.
- FR4 (SHALL): Discussions SHALL NOT be authoritative and SHALL be stored separately from REQs.
- FR5 (SHALL): Decisions that affect interpretation/implementation SHALL be recorded as ADRs and linked from the parent REQ.

## 9. Non-Functional Requirements

- NFR1 (Clarity): REQs must be unambiguous and testable.
- NFR2 (Auditability): Changes and decisions must be traceable via git + changelog + ADRs.
- NFR3 (Separation): Requirements and generator-specific artifacts (e.g., JDL) must remain separated.

## 10. Data / Domain Rules

Not applicable (this REQ is process-oriented).

## 11. UX / API Surface (Conceptual)

Not applicable.

## 12. Acceptance Criteria (Authoritative)

- AC1: `docs/requirements/README.md` exists and describes goals, layout, workflow, and versioning.
- AC2: `docs/requirements/templates/REQ-TEMPLATE.md` exists and contains required sections (goals, non-goals, acceptance, risks, assumptions, open questions).
- AC3: `docs/requirements/templates/ADR-TEMPLATE.md` exists.
- AC4: `docs/requirements/templates/ACCEPTANCE-TEMPLATE.md` exists.
- AC5: `docs/requirements/INDEX.md` lists REQ-000 and provides a status legend.
- AC6: `docs/requirements/CHANGELOG.md` contains an entry for REQ-000 v1.0.0 with rationale and impact.

## 13. Out of Scope Edge Cases (Explicit)

- E1: Multi-repo requirements management.
- E2: Automatic cross-linking to issue trackers (GitLab/Jira) in this phase.

## 14. Dependencies

- Dep1: None.

## 15. Constraints

- C1: This repo is Codex-first; requirements docs must not depend on Claude Code features.
- C2: Keep requirements human-readable and tool-agnostic.

## 16. Risks

- R1: Overhead slows down iteration. Mitigation: keep DISCUSSION flexible; enforce structure only at REQ approval time.
- R2: Specs become stale. Mitigation: enforce versioning + changelog + acceptance updates.

## 17. Assumptions

- A1: The team agrees to treat REQ documents as authoritative once approved.
- A2: Downstream artifacts will be derived from REQs, not the other way around.

## 18. Open Questions (Must Resolve Before v1.0)

- None for this REQ (this is the baseline system).

## 19. Decisions (ADRs)

- None.

## 20. Discussion Log (Pointer)

- `docs/requirements/CONVERSATIONS/REQ-000-discussion.md` (optional)

## 21. Version History

- v1.0.0 (2026-01-28): initial system definition

