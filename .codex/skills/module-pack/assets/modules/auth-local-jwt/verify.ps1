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
Assert ($t -like "*CODEX_JWT_BASE64_SECRET*") "Missing CODEX_JWT_BASE64_SECRET placeholder"
Assert ($t -like "*jhipster:*") "Missing jhipster: root"

Write-Host "PASS: auth-local-jwt verify"

