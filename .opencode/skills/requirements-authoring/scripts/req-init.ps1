param(
  [Parameter(Mandatory = $false)]
  [string]$RootPath = "requirements",

  [Parameter(Mandatory = $false)]
  [string]$Locale = "zh-CN",

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
$localeRoot = $assetsRoot
if ($Locale -and ($Locale.ToLowerInvariant() -ne "en-us")) {
  $localeRoot = Join-Path $assetsRoot $Locale
}
$localeRoot = (Resolve-Path $localeRoot).Path

$root = Join-Path (Get-Location) $RootPath

New-Item -ItemType Directory -Force -Path $root | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $root "templates") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $root "CONVERSATIONS") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $root "DECISIONS") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $root "ACCEPTANCE") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $root ".audit") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $root ".packs") | Out-Null

Copy-FileSafe -From (Join-Path $localeRoot "README.md") -To (Join-Path $root "README.md")
Copy-FileSafe -From (Join-Path $localeRoot "INDEX.md") -To (Join-Path $root "INDEX.md")
Copy-FileSafe -From (Join-Path $localeRoot "CHANGELOG.md") -To (Join-Path $root "CHANGELOG.md")

Copy-FileSafe -From (Join-Path $localeRoot "templates\\REQ-TEMPLATE.md") -To (Join-Path $root "templates\\REQ-TEMPLATE.md")
Copy-FileSafe -From (Join-Path $localeRoot "templates\\ADR-TEMPLATE.md") -To (Join-Path $root "templates\\ADR-TEMPLATE.md")
Copy-FileSafe -From (Join-Path $localeRoot "templates\\ACCEPTANCE-TEMPLATE.md") -To (Join-Path $root "templates\\ACCEPTANCE-TEMPLATE.md")
Copy-FileSafe -From (Join-Path $localeRoot "templates\\APPENDIX-DOMAIN-TEMPLATE.md") -To (Join-Path $root "templates\\APPENDIX-DOMAIN-TEMPLATE.md")
Copy-FileSafe -From (Join-Path $localeRoot "templates\\APPENDIX-CONSUMER-TEMPLATE.md") -To (Join-Path $root "templates\\APPENDIX-CONSUMER-TEMPLATE.md")
Copy-FileSafe -From (Join-Path $localeRoot "templates\\APPENDIX-GENERIC-TEMPLATE.md") -To (Join-Path $root "templates\\APPENDIX-GENERIC-TEMPLATE.md")
Copy-FileSafe -From (Join-Path $localeRoot "templates\\APPENDIX-CROSS-SERVICE-TEMPLATE.md") -To (Join-Path $root "templates\\APPENDIX-CROSS-SERVICE-TEMPLATE.md")

Write-Host ""
Write-Host "Initialized requirements workspace at: $root (locale: $Locale)"
Write-Host "Next: create a REQ via req-new.ps1"
