param(
  [Parameter(Mandatory = $true)]
  [string]$TargetDir
)

$ErrorActionPreference = "Stop"

$p = Join-Path $TargetDir "sonar-project.properties"
if (!(Test-Path $p)) { throw "Missing sonar-project.properties" }

Write-Host "PASS: quality-sonarqube module looks applied"

