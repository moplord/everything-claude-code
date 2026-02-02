# REQ-XXX Appendix (Cross-Service Contract) - <Short Title>

Status: DRAFT | APPROVED | IMPLEMENTING | DONE | DEPRECATED
Version: v0.1.0
Owner: <name/team>
Last Updated: YYYY-MM-DD

# Metadata (Required)
Type: cross-service-contract
Level: <L0|L1|L2|L3|...>
Parent: <REQ-XXX-...|>
Scopes: <optional>
References: <upstream/downstream REQs + versions>
Service: cross-service

This appendix is authoritative. It defines requirements-level service-to-service contracts
without introducing implementation artifacts (no OpenAPI files, no protobuf schemas, no CI YAML).

## A. Participants

| Role | Service | Responsibility | Notes |
|---|---|---|---|

## B. Contract (API/Event) Overview

| Contract ID | Type (REST/RPC/Event) | Producer | Consumer | Purpose | Versioning Strategy | Notes |
|---|---|---|---|---|---|---|

## C. Request/Response or Event Payload (Conceptual Fields)

| Contract ID | Direction (req/resp/event) | Field | Meaning | Required | Validation/Range | PII/Sensitive | Notes |
|---|---|---|---|---:|---|---:|---|

## D. Behavior, Errors, and Idempotency

| Contract ID | Success Semantics | Error Codes/Messages | Retry Policy | Idempotency Key | Concurrency Rules | Notes |
|---|---|---|---|---|---|---|

## E. Security and Permissions

| Contract ID | AuthN (mTLS/JWT/etc) | AuthZ (who can call) | Audit Logging | Data Minimization | Notes |
|---|---|---|---|---|---|

## F. SLO/SLA and Observability (Requirements-Level)

| Contract ID | Latency SLO | Availability SLO | Rate Limits | Metrics | Tracing | Alerts | Notes |
|---|---|---|---|---|---|---|---|

## G. Backward Compatibility Rules

| Rule | Applies To | Requirement | Blocking | Notes |
|---|---|---|---:|---|

## H. AC -> Tests -> Evidence (Traceability)

| AC | Test Type (unit/integration/smoke/e2e) | Evidence Required | Notes |
|---|---|---|---|

## I. Quality Gates (Requirements-Level, no YAML)

| Gate | Requirement | Blocking | Notes |
|---|---|---:|---|

