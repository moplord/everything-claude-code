# Requirements Changelog

Keep this file append-only.

Format:
- Date (YYYY-MM-DD)
- REQ ID + version bump
- What changed (short)
- Why (rationale)
- Impact (downstream: acceptance/tests/JDL/code/CI)

---

## 2026-01-28

- REQ-000 v1.0.0
  - Added requirements authoring system (templates + workflow + index)
  - Rationale: establish an authority-first requirements layer before JDL generation
  - Impact: future REQs must follow the template; JDL is explicitly deferred

