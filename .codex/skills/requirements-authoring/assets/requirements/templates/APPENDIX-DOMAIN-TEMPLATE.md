# REQ-XXX Appendix (Domain Model) - <Short Title>

Status: DRAFT | APPROVED | IMPLEMENTING | DONE | DEPRECATED
Version: v0.1.0
Owner: <name/team>
Last Updated: YYYY-MM-DD

# Metadata (Required)
Type: domain-model
Level: <L0|L1|L2|L3|...>
Parent: <REQ-XXX-...|>
Scopes: <optional; usually "all">
References: <other REQs if needed>
Service: <monolith|service-name|>

This appendix is authoritative. It expresses derivation-ready constraints so downstream
artifacts can be generated WITHOUT guessing. Do not paste JDL or CI YAML here.

## A. Domain Model (Derivation-Ready)

### A1. Entities

| Entity | Description | Auditing Fields | Soft Delete | Optimistic Lock | Notes |
|---|---|---|---|---|---|

### A2. Field Dictionary (per Entity)

| Field | Meaning | Type Candidates (JDL) | Required | Default | Length/Precision/Scale | Validation/Range | Unique/Index | System-Managed | Notes | Example |
|---|---|---|---:|---|---|---|---|---:|---|---|

### A3. Enums

| Enum | Value | Meaning | Default | Notes |
|---|---|---|---|---|

### A4. Relationships

| Name | Entity A | Entity B | Cardinality | Owner Side | Required | Bidirectional | Join/Fields | Delete/Cascade | Notes |
|---|---|---|---|---|---:|---:|---|---|---|

### A5. Invariants (Must Hold)

| Invariant | Meaning | Failure Handling (error/message) |
|---|---|---|

## B. Files (Upload/Download Contract)

| Scenario | Field/Association | Storage Strategy | Formats | Max Size | Max Dimensions | Replace Rule | Delete Old Rule | Permission | Failure Rollback | Download/Preview |
|---|---|---|---|---|---|---|---|---|---|---|

## C. Domain Events / API Contracts (Requirements-Level)

| Contract | Trigger | Inputs | Outputs | Idempotency/Concurrency | Errors | Notes |
|---|---|---|---|---|---|---|

## D. Verification & Quality (Requirements-Level)

| Gate | Requirement | Blocking | Notes |
|---|---|---:|---|

