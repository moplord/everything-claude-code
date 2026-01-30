param(
  [Parameter(Mandatory = $false)]
  [string]$ModulesRoot = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ModulesRoot -or $ModulesRoot.Trim().Length -eq 0) {
  $ModulesRoot = Join-Path $scriptDir "..\\assets\\modules"
}
$ModulesRoot = (Resolve-Path $ModulesRoot).Path

if (!(Test-Path $ModulesRoot)) {
  throw ("Modules root not found: " + $ModulesRoot)
}

$mods = Get-ChildItem -Path $ModulesRoot -Directory | Sort-Object Name
if ($mods.Count -eq 0) {
  Write-Host "(no modules)"
  exit 0
}

foreach ($m in $mods) {
  $manifest = Join-Path $m.FullName "manifest.json"
  $desc = ""
  if (Test-Path $manifest) {
    try {
      $o = Get-Content -Raw -Encoding UTF8 $manifest | ConvertFrom-Json
      $desc = $o.description
    } catch {
      $desc = "(invalid manifest.json)"
    }
  } else {
    $desc = "(missing manifest.json)"
  }
  Write-Host ("- " + $m.Name + " :: " + $desc)
}

