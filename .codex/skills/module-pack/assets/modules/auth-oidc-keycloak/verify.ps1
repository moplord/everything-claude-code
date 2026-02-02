param(
  [Parameter(Mandatory = $true)]
  [string]$TargetDir
)

$ErrorActionPreference = "Stop"

function Assert {
  param([bool]$Cond, [string]$Msg)
  if (-not $Cond) { throw $Msg }
}

$p = Join-Path $TargetDir "src\\main\\resources\\config\\application-codex.yml"
Assert (Test-Path $p) ("Missing: " + $p)

$t = Get-Content -Raw -Encoding UTF8 $p
Assert ($t -like "*CODEX_OIDC_ISSUER_URI*") "Missing CODEX_OIDC_ISSUER_URI placeholder"
Assert ($t -like "*spring:*") "Missing spring: root"

Write-Host "PASS: auth-oidc-keycloak verify"

