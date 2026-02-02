param(
  [Parameter(Mandatory = $false)]
  [string]$ReqLocale = "zh-CN"
)

$ErrorActionPreference = "Stop"

function Assert-ExitCode {
  param([int]$Expected, [string]$What)
  if ($LASTEXITCODE -ne $Expected) {
    throw ("Selftest failed: " + $What + " expected exit " + $Expected + " but got " + $LASTEXITCODE)
  }
}

function Run-PSFile {
  param(
    [string]$File,
    [string[]]$ScriptArgs,
    [string]$What
  )
  $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $File) + $ScriptArgs
  & powershell @argList | Out-Host
  Assert-ExitCode -Expected 0 -What $What
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..\\..\\..\\..")).Path
$reqSkillScripts = Join-Path $repoRoot ".codex\\skills\\requirements-authoring\\scripts"
$reqInit = Join-Path $reqSkillScripts "req-init.ps1"
$reqNew = Join-Path $reqSkillScripts "req-new.ps1"
$reqIndex = Join-Path $reqSkillScripts "req-index.ps1"
$reqLedger = Join-Path $reqSkillScripts "req-ledger.ps1"
$reqAudit = Join-Path $repoRoot ".codex\\skills\\requirements-audit\\scripts\\req-audit.ps1"

$gen = Join-Path $scriptDir "db-plan-generate.ps1"
$val = Join-Path $scriptDir "db-plan-validate.ps1"

$tmp = Join-Path $env:TEMP ("dbplan-selftest-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

try {
  Push-Location $tmp

  Run-PSFile -File $reqInit -ScriptArgs @("-RootPath","requirements","-Locale",$ReqLocale) -What "req-init"
  Run-PSFile -File $reqNew -ScriptArgs @("-RootPath","requirements","-Title","Catalog Domain","-Type","domain-model","-Level","L2","-Owner","team","-Locale",$ReqLocale) -What "req-new domain-model"
  Run-PSFile -File $reqIndex -ScriptArgs @("-RootPath","requirements") -What "req-index"
  Run-PSFile -File $reqLedger -ScriptArgs @("-RootPath","requirements") -What "req-ledger"
  & powershell -NoProfile -ExecutionPolicy Bypass -File $reqAudit -RootPath requirements | Out-Host
  Assert-ExitCode -Expected 0 -What "req-audit"

  $main = Get-ChildItem -Path requirements -File -Filter "REQ-001-*.md" | Where-Object { $_.Name -notlike "*-appendix.md" } | Select-Object -First 1
  if (-not $main) { throw "Selftest failed: cannot find REQ-001 main file" }
  $appendix = Join-Path "requirements" (([System.IO.Path]::GetFileNameWithoutExtension($main.Name)) + "-appendix.md")
  if (!(Test-Path $appendix)) { throw ("Selftest failed: missing appendix " + $appendix) }

  $ax = @()
  $ax += "# REQ-001 Appendix (Domain Model) - Catalog Domain"
  $ax += ""
  $ax += "Status: DRAFT"
  $ax += "Version: v0.1.0"
  $ax += "Owner: team"
  $ax += "Last Updated: 2026-01-29"
  $ax += ""
  $ax += "# Metadata (Required)"
  $ax += "Type: domain-model"
  $ax += "Level: L2"
  $ax += "Parent: "
  $ax += "Scopes: all"
  $ax += "References: "
  $ax += "Service: monolith"
  $ax += ""
  $ax += "## A. Domain Model (Derivation-Ready)"
  $ax += ""
  $ax += "### A1. Entities"
  $ax += ""
  $ax += "| Entity (Display) | EntityCode(PascalCase) | Description | Auditing Fields | Soft Delete | Optimistic Lock | Notes |"
  $ax += "|---|---|---|---|---|---|---|"
  $ax += "| Product | Product | Product master | createdBy/createdAt | yes | yes | |"
  $ax += ""
  $ax += "### A2. Field Dictionary (Global)"
  $ax += ""
  $ax += "| EntityCode | Field (Display) | FieldCode(camelCase) | Meaning | Type Candidates (JDL) | Required | Default | Length/Precision/Scale | Validation/Range | Unique/Index | System-Managed | Notes | Example |"
  $ax += "|---|---|---|---|---|---:|---|---|---|---|---:|---|---|"
  $ax += "| Product | Name | name | Product name | String | yes |  | 100 |  | unique | no |  | Coffee |"
  $ax += "| Product | Main Image | mainImage | Primary image url | String | no |  | 500 |  | index | no |  | https://... |"
  $ax += ""
  $ax += "## D. Verification & Quality (Requirements-Level)"
  $ax += ""
  $ax += "### D1. Access Patterns (DB-agnostic)"
  $ax += ""
  $ax += "| Scenario | Filters (EntityCode.FieldCode) | Sort | Pagination | Expected Cardinality | Latency Budget | Notes |"
  $ax += "|---|---|---|---|---|---|---|"
  $ax += "| Search products | Product.name | Product.name asc | page/size | 1e5 | p95<200ms | |"
  $ax += ""
  $ax += "### D2. Index Plan (DB-agnostic)"
  $ax += ""
  $ax += "| Index Name | On (EntityCode) | Fields (FieldCode...) | Unique | Purpose | Notes |"
  $ax += "|---|---|---|---:|---|---|"
  $ax += "| idx_product_name | Product | name | yes | search by name | |"
  $ax += "| idx_product_mainImage | Product | mainImage | no | list preview | |"
  $ax += ""
  $ax += "### D3. Cache Plan (Optional)"
  $ax += ""
  $ax += "| Cache Key | Source | TTL | Invalidation | Consistency | Notes |"
  $ax += "|---|---|---|---|---|---|"
  $ax += "| product:{id} | Product | 60s | on product update | eventual | |"
  $ax += ""
  $ax += "| Gate | Requirement | Blocking | Notes |"
  $ax += "|---|---|---:|---|"
  $ax += "| plan | db-plan generated | yes | |"
  Set-Content -NoNewline -Encoding UTF8 -Path $appendix -Value ($ax -join "`n")

  Run-PSFile -File $gen -ScriptArgs @("-RequirementsRoot","requirements","-OutRoot","jdl\\generated") -What "db-plan-generate"
  Run-PSFile -File $val -ScriptArgs @("-RequirementsRoot","requirements","-OutRoot","jdl\\generated") -What "db-plan-validate"

  Write-Host "PASS: db-plan selftest"
} finally {
  Pop-Location
  Remove-Item -Recurse -Force $tmp
}

