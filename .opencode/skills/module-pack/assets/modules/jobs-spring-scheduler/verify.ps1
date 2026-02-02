param(
  [Parameter(Mandatory = $true)]
  [string]$TargetDir
)

$ErrorActionPreference = "Stop"

$cfg = Join-Path $TargetDir "src\\main\\resources\\config\\application-codex.yml"
if (!(Test-Path $cfg)) { throw "Missing application-codex.yml" }

$t = Get-Content -Raw -Encoding UTF8 $cfg
if ($t -notmatch '(?im)codex:\s*[\r\n]+\\s*jobs:\s*') { throw "Expected codex.jobs block not found" }

Write-Host "PASS: jobs-spring-scheduler module looks applied"

