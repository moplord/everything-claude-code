---
name: requirements-elicitation
description: Use when you want to discuss a new feature/problem and extract a complete, ambiguity-resistant requirements packet (scope, non-goals, assumptions, risks, open questions, acceptance criteria) before writing an authoritative REQ file.
---

# Requirements Elicitation

This skill turns an unstructured conversation into a structured "elicitation packet".
It does NOT write generator-specific artifacts (e.g., JDL) and does NOT finalize an
authoritative requirement. Its job is to reduce ambiguity and surface unknowns.

Language:
- Produce the packet in the user's requested language (e.g., Chinese) unless told otherwise.

## Output Contract (What You Produce)

Produce a single Markdown section titled `Elicitation Packet` containing:
- Summary (1-3 sentences)
- Goals (must-have)
- Non-goals (explicit)
- Stakeholders
- Glossary (terms that could be interpreted differently)
- User stories (as-needed)
- Functional requirements (SHALL/SHOULD/MAY)
- Non-functional requirements (measurable where possible)
- Data/domain rules (conceptual only)
- Primary flows + error flows (conceptual)
- Acceptance criteria (testable, numbered)
- Dependencies + constraints
- Risks (impact/likelihood + mitigations)
- Assumptions
- Open questions (must resolve before approval)

If anything is unknown, do NOT invent. Put it under Open Questions or Assumptions.

## Elicitation Procedure (Deterministic)

### Step 1: Establish Context

Ask for:
- Product goal (why this exists)
- Users/roles (who is affected)
- Current behavior (what happens today)
- Desired outcome (what changes)
- Hard constraints (time, compliance, platform, integrations)

### Step 2: Freeze Scope Boundaries Early

Ask explicit boundary questions:
- What is in scope for v1?
- What is out of scope (non-goals)?
- What is explicitly NOT promised?

### Step 3: Define Acceptance Criteria First

Convert intent into verifiable statements:
- Each AC must be independently verifiable.
- Avoid vague adjectives ("fast", "secure", "scalable") without metrics.
- Prefer "Given/When/Then" phrasing if it clarifies.

### Step 4: Identify Unknowns and Kill Ambiguity

For each requirement, ask:
- What are the failure modes?
- What is the default behavior?
- What happens when dependencies are down?
- What are the edge cases we explicitly do NOT support?
- What is the data source of truth?

### Step 5: Risk & Security Pass (Lightweight)

Ask at minimum:
- Does it handle secrets, auth, PII, payment, admin actions, or file upload?
- What audit logs are required?
- What permissions model is assumed?

### Step 6: Produce the Elicitation Packet

Write the packet in a compact, structured format. Keep it implementation-agnostic.

## Hand-off

Once the elicitation packet is accepted, use `$requirements-authoring` to turn it
into an authoritative REQ + acceptance checklist + changelog/index updates in the
target project repository.
