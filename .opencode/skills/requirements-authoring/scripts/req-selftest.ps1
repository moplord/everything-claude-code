param(
  [Parameter(Mandatory = $false)]
  [string]$ReqLocale = "en-US"
)

$ErrorActionPreference = "Stop"

function Assert-ExitCode {
  param([int]$Expected, [string]$What)
  if ($LASTEXITCODE -ne $Expected) {
    throw ("Selftest failed: " + $What + " expected exit " + $Expected + " but got " + $LASTEXITCODE)
  }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$auditScript = Join-Path $scriptDir "..\\..\\requirements-audit\\scripts\\req-audit.ps1"
$auditScript = (Resolve-Path $auditScript).Path

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

$tmp = Join-Path $env:TEMP ("req-selftest-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

try {
  Push-Location $tmp

  Run-PSFile -File (Join-Path $scriptDir "req-init.ps1") -ScriptArgs @("-RootPath","requirements","-Locale",$ReqLocale) -What "req-init"

  Run-PSFile -File (Join-Path $scriptDir "req-new.ps1") -ScriptArgs @("-RootPath","requirements","-Title","Domain Model","-Type","domain-model","-Level","L2","-Owner","team","-Locale",$ReqLocale) -What "req-new domain-model"

  Run-PSFile -File (Join-Path $scriptDir "req-new.ps1") -ScriptArgs @("-RootPath","requirements","-Title","Consumer Feature","-Type","consumer-feature","-Level","L3","-Scopes","web","-References","REQ-001 (v0.1.0)","-Owner","team","-Locale",$ReqLocale) -What "req-new consumer-feature"

  Run-PSFile -File (Join-Path $scriptDir "req-new.ps1") -ScriptArgs @("-RootPath","requirements","-Title","Cross Service Contract","-Type","cross-service-contract","-Level","L2","-Service","cross-service","-Owner","team","-Locale",$ReqLocale) -What "req-new cross-service-contract"

  Run-PSFile -File (Join-Path $scriptDir "req-index.ps1") -ScriptArgs @("-RootPath","requirements") -What "req-index"

  # Ledger is required by audit. Ensure it exists and is up to date.
  Run-PSFile -File (Join-Path $scriptDir "req-ledger.ps1") -ScriptArgs @("-RootPath","requirements") -What "req-ledger (baseline)"

  Run-PSFile -File $auditScript -ScriptArgs @("-RootPath","requirements") -What "req-audit (baseline)"

  # Change tracking: modify a REQ without bumping Version, then ledger update must fail.
  $req1 = Get-ChildItem -Path requirements -File -Filter "REQ-001-*.md" | Where-Object { $_.Name -notlike "*-appendix.md" } | Select-Object -First 1
  if (-not $req1) { throw "Selftest failed: cannot find REQ-001 main file" }
  Add-Content -Encoding UTF8 -Path $req1.FullName -Value "`n<!-- selftest touch -->`n"

  $argList = @("-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $scriptDir "req-ledger.ps1"),"-RootPath","requirements")
  & powershell @argList | Out-Host
  if ($LASTEXITCODE -ne 2) { throw ("Selftest failed: req-ledger should fail after change without version/changelog (got exit " + $LASTEXITCODE + ")") }

  Write-Host "PASS: requirements skills selftest"
} finally {
  Pop-Location
  Remove-Item -Recurse -Force $tmp
}
