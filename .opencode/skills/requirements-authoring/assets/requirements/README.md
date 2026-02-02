# Requirements (Authority-First)

This folder is the authoritative source of truth for "what to build".

Rules:
- These documents are NOT JDL and must remain generator-agnostic.
- Do not mix implementation details into REQs.
- Every requirement must have verifiable acceptance criteria.
- Any meaning-changing edit requires a REQ version bump and a CHANGELOG entry.

Operational:
- Regenerate `INDEX.md` via `req-index.ps1` (do not hand-edit the index in large projects).
- Update `requirements/.audit/ledger.json` via `req-ledger.ps1` to prevent silent drift.
