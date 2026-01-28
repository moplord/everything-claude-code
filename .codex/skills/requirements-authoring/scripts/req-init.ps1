param(
  [Parameter(Mandatory = $false)]
  [string]$RootPath = "requirements",

  [Parameter(Mandatory = $false)]
  [switch]$Force
)

$ErrorActionPreference = "Stop"

function Copy-FileSafe {
  param(
    [string]$From,
    [string]$To
  )
  $destDir = Split-Path -Parent $To
  if (!(Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir | Out-Null
  }

  if ((Test-Path $To) -and (-not $Force)) {
    Write-Host "SKIP (exists): $To"
    return
  }

  Copy-Item -Force -Path $From -Destination $To
  Write-Host "COPY: $To"
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$assetsRoot = Join-Path $scriptDir "..\\assets\\requirements"
$assetsRoot = (Resolve-Path $assetsRoot).Path

$root = Join-Path (Get-Location) $RootPath

New-Item -ItemType Directory -Force -Path $root | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $root "templates") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $root "CONVERSATIONS") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $root "DECISIONS") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $root "ACCEPTANCE") | Out-Null

Copy-FileSafe -From (Join-Path $assetsRoot "README.md") -To (Join-Path $root "README.md")
Copy-FileSafe -From (Join-Path $assetsRoot "INDEX.md") -To (Join-Path $root "INDEX.md")
Copy-FileSafe -From (Join-Path $assetsRoot "CHANGELOG.md") -To (Join-Path $root "CHANGELOG.md")

Copy-FileSafe -From (Join-Path $assetsRoot "templates\\REQ-TEMPLATE.md") -To (Join-Path $root "templates\\REQ-TEMPLATE.md")
Copy-FileSafe -From (Join-Path $assetsRoot "templates\\ADR-TEMPLATE.md") -To (Join-Path $root "templates\\ADR-TEMPLATE.md")
Copy-FileSafe -From (Join-Path $assetsRoot "templates\\ACCEPTANCE-TEMPLATE.md") -To (Join-Path $root "templates\\ACCEPTANCE-TEMPLATE.md")

Write-Host ""
Write-Host "Initialized requirements workspace at: $root"
Write-Host "Next: create a REQ via req-new.ps1"

