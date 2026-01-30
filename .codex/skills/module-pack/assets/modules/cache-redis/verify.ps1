param(
  [Parameter(Mandatory = $true)]
  [string]$TargetDir
)

$ErrorActionPreference = "Stop"

$pom = Join-Path $TargetDir "pom.xml"
if (!(Test-Path $pom)) { throw "Missing pom.xml" }
$cfg = Join-Path $TargetDir "src\\main\\resources\\config\\application-codex.yml"
if (!(Test-Path $cfg)) { throw "Missing application-codex.yml" }

$t = Get-Content -Raw -Encoding UTF8 $cfg
if ($t -notmatch '(?im)codex:\s*[\r\n]+\\s*cache:\s*[\r\n]+\\s*redis:') {
  throw "Expected codex.cache.redis block not found"
}

Write-Host "PASS: cache-redis module looks applied"

