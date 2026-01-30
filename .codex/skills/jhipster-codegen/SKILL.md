---
name: jhipster-codegen
description: Generate a JHipster project from an application JDL + derived entity JDLs in a deterministic way (multi-file JDL, version-pinned via npx package).
---

# JHipster Codegen (From JDL -> Real Code)

This skill covers the "JDL -> generated code" step.

Principles:
- use `jhipster import-jdl` so the app scaffold + entities can be generated from JDL;
- support **multiple JDL files** (split by REQ/service) to avoid a single mega-file;
- pin JHipster generator version at execution time (no guessing).

Non-goals:
- deciding your business model (that's requirements + domain-model appendix + `jdl-derivation`);
- implementing custom business logic;
- CI pipelines / YAML.

## Inputs

You provide:
- `TargetDir`: where the code should be generated
- `JhipsterVersion`: the `generator-jhipster` npm version to run (example: `8.6.0`)
- `App JDL`:
  - either provide `-AppJdlPath`, or
  - let the script generate a minimal `app.jdl` from `BaseName/PackageName/OIDC/...`
- `Entity JDLs`: either `-JdlDir` (folder) or explicit `-JdlFiles` list

## Output

- A real JHipster project scaffold generated under `TargetDir`
- Entities generated from JDLs (and `.jhipster/*.json` metadata)

## Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<path-to-skill>/scripts/jhipster-import-jdl.ps1" `
  -TargetDir "D:\Code\my-app" `
  -JhipsterVersion "8.6.0" `
  -BaseName "mall" `
  -PackageName "com.company.mall" `
  -OidcIssuerUri "https://idp.example.com/realms/mall" `
  -OidcClientId "mall-web" `
  -JdlDir "D:\Code\specs\jdl\generated"
```

Notes:
- The script will try `jhipster` from PATH first; if missing, it runs via `npx -p generator-jhipster@<version> jhipster ...`.
- You can pass `-SkipInstall` to avoid dependency installs during generation (recommended in CI).

