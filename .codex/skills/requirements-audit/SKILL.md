---
name: requirements-audit
description: Use when you need to validate that a project's requirements set is consistent, versioned, and ambiguity-resistant (REQ/ADR/AC/Index/Changelog), and to produce a deterministic pass/fail report.
---

# Requirements Audit (Deterministic Gate)

This skill provides a deterministic linter/auditor for a requirements workspace in a
target project repository.

Goal:
- prevent "quiet drift" (meaning changes without version/changelog),
- prevent missing acceptance criteria,
- reduce ambiguity that would break later JDL/code generation.

## What You Run

From the target repo root:

```powershell
powershell -ExecutionPolicy Bypass -File "<path-to-skill>/scripts/req-audit.ps1" -RootPath requirements
```

Exit codes:
- 0: no errors (warnings may still exist)
- 2: errors found (fix before approval)

## What This Audit Checks

Hard errors:
- missing baseline files: README/INDEX/CHANGELOG/templates
- REQ files missing required headers: Status/Version/Owner/Last Updated
- REQ missing Non-Goals or Acceptance Criteria
- APPROVED REQ has open questions remaining

Warnings:
- ambiguous language in acceptance criteria (e.g., "fast", "secure") without metrics
- INDEX missing entries for REQs

## How to Respond

If audit fails:
- do not proceed to downstream steps (JDL/code/CI)
- update the REQ with explicit constraints/ACs
- add ADRs for decisions that change interpretation
- bump version + update CHANGELOG if meaning changed

