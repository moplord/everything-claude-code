# REQ-XXX Appendix (Consumer Feature) - <Short Title>

Status: DRAFT | APPROVED | IMPLEMENTING | DONE | DEPRECATED
Version: v0.1.0
Owner: <name/team>
Last Updated: YYYY-MM-DD

# Metadata (Required)
Type: consumer-feature
Level: <L0|L1|L2|L3|...>
Parent: <REQ-XXX-...|>
Scopes: <comma-separated; required>
References: <domain-model REQ + version; required>
Service: <monolith|service-name|optional>

This appendix is authoritative. It defines how the feature consumes the shared model and how it
can be verified. It MUST NOT redefine DB model types/relationships (those come from References).

## A. Model Snapshot (Read-Only, Minimal)

Source: the referenced `domain-model` REQ version.

### A1. Entities/Fields Used

| Entity (Display) | EntityCode | Field (Display) | FieldCode | Purpose | Notes |
|---|---|---|---|---|---|

### A2. Relationships Used

| Name | Entity A (EntityCode) | Entity B (EntityCode) | Cardinality | Purpose | Notes |
|---|---|---|---|---|---|

## B. Field Projection (Visibility/Editability)

Naming: reference model fields as `EntityCode.FieldCode` (e.g. `Product.mainImage`).

| Scope | EntityCode.FieldCode | Visible | Editable | Hidden/Read-only Rationale | Notes |
|---|---|---:|---:|---|---|

## C. Interaction & State Machines (Business-Level)

### C1. Actions/Buttons

| Scope | Action | Preconditions | Inputs | State Change | Success Feedback | Failure Feedback | Audit Log | Notes |
|---|---|---|---|---|---|---|---|---|

### C2. State Machine (If applicable)

| EntityCode.FieldCode | From | Event (Action/Button) | Guard (Condition) | To | Side Effects | Notes |
|---|---|---|---|---|---|---|

## D. Files (If applicable)

| Scope | Scenario | Binds To (EntityCode.FieldCode / Assoc) | Formats | Max Size | Replace Rule | Permission | Failure Rollback | Download/Preview |
|---|---|---|---|---|---|---|---|---|

## E. AC -> Tests -> Evidence (Traceability)

| AC | Scope | Test Type (unit/integration/smoke/e2e) | Evidence Required (CI link/log/screenshot) | Notes |
|---|---|---|---|---|

## F. Quality Gates (Requirements-Level, no YAML)

| Gate | Requirement | Blocking | Notes |
|---|---|---:|---|
