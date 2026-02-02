---
name: jhipster-scaffold
description: Deterministic JHipster monolith scaffold setup (Vue3 + OIDC + Maven + PostgreSQL) by generating a reproducible scaffold plan and .yo-rc.json parameters (no guessing).
---

# JHipster Scaffold (Monolith + Vue3 + OIDC + Maven + PostgreSQL)

This skill defines how we bootstrap a new JHipster project scaffold in a deterministic way.

Goals:
- reproducible scaffold inputs (no interactive guessing),
- strictly separated from domain-model JDL and business requirements.

Non-goals:
- choose business domain model (that's `Type=domain-model` + JDL),
- implement business logic,
- add optional infra modules (Redis/MQ/etc) in this step.

## Inputs You Must Provide Per Project

These are project-specific and must be supplied at generation time:
- `BaseName` (app name)
- `PackageName` (Java package)
- `AuthProfile` (`oidc` or `local-jwt`)
- If `AuthProfile=oidc`:
  - `OidcIssuerUri` (OIDC issuer URL)
  - `OidcClientId` (client id)

Fixed defaults for the current baseline:
- monolith
- Vue3 client
- Auth:
  - `oidc` -> JHipster `oauth2`
  - `local-jwt` -> JHipster `jwt`
- Maven build
- PostgreSQL
- no i18n
- no multi-tenancy

## Outputs

This skill produces:
- a scaffold plan file (human-readable) describing the chosen baseline and required inputs
- a generated `.yo-rc.json` "parameter stub" (NOT a full guarantee of JHipster version compatibility)

## Commands

Generate a scaffold plan and `.yo-rc.json` stub into a target project folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<path-to-skill>/scripts/scaffold-plan.ps1" `
  -OutDir "<target-project-dir>" `
  -BaseName "mall" `
  -PackageName "com.company.mall" `
  -AuthProfile "oidc" `
  -OidcIssuerUri "https://idp.example.com/realms/mall" `
  -OidcClientId "mall-web"
```

Notes:
- We intentionally do NOT run the JHipster generator in this repository skill. A separate automation step can do that later.
- The `.yo-rc.json` content is a baseline stub; exact fields can differ across JHipster versions.

