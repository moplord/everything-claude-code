# REQ-XXX Appendix - <Short Title>

Status: DRAFT | APPROVED | IMPLEMENTING | DONE | DEPRECATED
Version: v0.1.0
Owner: <name/team>
Last Updated: YYYY-MM-DD

This appendix is authoritative. It contains structured constraints that enable downstream
artifacts (e.g., JDL/tests/CI) to be derived WITHOUT guessing. Do not paste JDL or CI YAML.

## A. Domain Model (Derivation-Ready)

### A1. Entities

| Entity | Description | Auditing Fields | Soft Delete | Optimistic Lock | Notes |
|---|---|---|---|---|---|

### A2. Field Dictionary (per Entity)

Create one table per entity.

| Field | Meaning | Type Candidates | Required | Default | Length/Precision/Scale | Validation/Range | Unique/Index | Visible (UI) | Editable | System-Managed | Example |
|---|---|---|---:|---|---|---|---|---:|---:|---:|---|

### A3. Enums

| Enum | Value | Meaning | Extensible | Default |
|---|---|---|---:|---|

### A4. Relationships

| Name | Entity A | Entity B | Cardinality | Owner Side | Required | Bidirectional | Join/Fields | Delete/Cascade | Notes |
|---|---|---|---|---|---:|---:|---|---|---|

### A5. State Machines

| Entity.Field | From | Event (Action/Button) | Guard (Condition) | To | Side Effects | Audit |
|---|---|---|---|---|---|---|

## B. Files (Upload/Download Contract)

| Scenario | Field/Association | Storage Strategy | Formats | Max Size | Max Dimensions | Replace Rule | Delete Old Rule | Permission | Failure Rollback | Download/Preview |
|---|---|---|---|---|---|---|---|---|---|---|

## C. API & Behavior Contract (Conceptual)

| Use Case | Role | Inputs (Fields) | Outputs (Fields) | Validation | Error Codes/Messages | Idempotency/Concurrency | Notes |
|---|---|---|---|---|---|---|---|

## D. Verification & Quality Contract (Requirements-Level)

### D1. Acceptance-to-Test Traceability

| AC | Test Type (unit/integration/smoke/e2e) | Evidence Required | Notes |
|---|---|---|---|

### D2. Quality Gates (No YAML Here)

| Gate | Requirement | Blocking | Notes |
|---|---|---:|---|

