param(
  [Parameter(Mandatory = $false)]
  [string]$RootPath = "requirements",

  [Parameter(Mandatory = $true)]
  [string]$Title,

  [Parameter(Mandatory = $false)]
  [string]$Type = "consumer-feature",

  [Parameter(Mandatory = $false)]
  [string]$Level = "L3",

  [Parameter(Mandatory = $false)]
  [string]$Parent = "",

  [Parameter(Mandatory = $false)]
  [string]$Scopes = "",

  [Parameter(Mandatory = $false)]
  [string]$References = "",

  [Parameter(Mandatory = $false)]
  [string]$Service = "",

  [Parameter(Mandatory = $false)]
  [string]$Owner = "team",

  [Parameter(Mandatory = $false)]
  [string]$Locale = "en-US"
  ,
  [Parameter(Mandatory = $false)]
  [switch]$NoLedgerUpdate
)

$ErrorActionPreference = "Stop"

function Sanitize-Slug {
  param([string]$s)
  $slug = $s.Trim()
  # Remove Windows-forbidden filename characters, keep Unicode letters/digits.
  $slug = $slug -replace '[\\/:*?"<>|]', ''
  $slug = $slug -replace '\s+', '-'
  $slug = $slug -replace '-{2,}', '-'
  $slug = $slug.Trim("-")
  if ($slug.Length -eq 0) { $slug = "untitled" }
  return $slug
}

function Get-NextReqNumber {
  param([string]$root)
  $max = 0
  if (Test-Path $root) {
    Get-ChildItem -Path $root -File -Filter "REQ-*.md" | ForEach-Object {
      $m = [regex]::Match($_.Name, '^REQ-(\d{3})-')
      if ($m.Success) {
        $n = [int]$m.Groups[1].Value
        if ($n -gt $max) { $max = $n }
      }
    }
  }
  return ($max + 1)
}

$root = Join-Path (Get-Location) $RootPath
if (!(Test-Path $root)) {
  throw "RootPath does not exist: $root. Run req-init.ps1 first."
}

$reqTemplate = Join-Path $root "templates\\REQ-TEMPLATE.md"
$acceptanceTemplate = Join-Path $root "templates\\ACCEPTANCE-TEMPLATE.md"
$appendixTemplate = ""
switch ($Type) {
  "domain-model" { $appendixTemplate = Join-Path $root "templates\\APPENDIX-DOMAIN-TEMPLATE.md" }
  "consumer-feature" { $appendixTemplate = Join-Path $root "templates\\APPENDIX-CONSUMER-TEMPLATE.md" }
  "cross-service-contract" { $appendixTemplate = Join-Path $root "templates\\APPENDIX-CROSS-SERVICE-TEMPLATE.md" }
  default { $appendixTemplate = Join-Path $root "templates\\APPENDIX-GENERIC-TEMPLATE.md" }
}

# Fallback: if the target repo does not have templates yet, use the skill assets.
if (!(Test-Path $reqTemplate) -or !(Test-Path $acceptanceTemplate) -or !(Test-Path $appendixTemplate)) {
  $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
  $assetsRoot = Join-Path $scriptDir "..\\assets\\requirements"
  $localeRoot = $assetsRoot
  if ($Locale -and ($Locale.ToLowerInvariant() -ne "en-us")) {
    $localeRoot = Join-Path $assetsRoot $Locale
  }
  if (Test-Path $localeRoot) {
    $reqTemplate = Join-Path $localeRoot "templates\\REQ-TEMPLATE.md"
    $acceptanceTemplate = Join-Path $localeRoot "templates\\ACCEPTANCE-TEMPLATE.md"
    switch ($Type) {
      "domain-model" { $appendixTemplate = Join-Path $localeRoot "templates\\APPENDIX-DOMAIN-TEMPLATE.md" }
      "consumer-feature" { $appendixTemplate = Join-Path $localeRoot "templates\\APPENDIX-CONSUMER-TEMPLATE.md" }
      "cross-service-contract" { $appendixTemplate = Join-Path $localeRoot "templates\\APPENDIX-CROSS-SERVICE-TEMPLATE.md" }
      default { $appendixTemplate = Join-Path $localeRoot "templates\\APPENDIX-GENERIC-TEMPLATE.md" }
    }
  }
}

if (!(Test-Path $reqTemplate)) {
  throw "Missing REQ template: $reqTemplate"
}
if (!(Test-Path $acceptanceTemplate)) {
  throw "Missing acceptance template: $acceptanceTemplate"
}
if (!(Test-Path $appendixTemplate)) {
  throw "Missing appendix template: $appendixTemplate"
}

$n = Get-NextReqNumber -root $root
$id = ("REQ-{0:D3}" -f $n)
$slug = Sanitize-Slug -s $Title
$fileName = "$id-$slug.md"
$appendixName = "$id-$slug-appendix.md"
$outPath = Join-Path $root $fileName
if (Test-Path (Join-Path $root $appendixName)) {
  throw "Appendix already exists: $(Join-Path $root $appendixName)"
}
if (Test-Path $outPath) {
  throw "REQ already exists: $outPath"
}

$acceptanceDir = Join-Path $root "ACCEPTANCE"
if (!(Test-Path $acceptanceDir)) { New-Item -ItemType Directory -Force -Path $acceptanceDir | Out-Null }
$acceptanceName = "$id-acceptance.md"
$acceptancePath = Join-Path $acceptanceDir $acceptanceName
if (Test-Path $acceptancePath) {
  throw "Acceptance checklist already exists: $acceptancePath"
}

$today = Get-Date -Format "yyyy-MM-dd"
$cnShortTitle = [regex]::Unescape('<\u77ed\u6807\u9898>')
$content = Get-Content -Raw -Encoding UTF8 $reqTemplate
$content = $content -replace 'REQ-XXX', $id
$content = $content -replace '<Short Title>', $Title
$content = $content -replace $cnShortTitle, $Title
$content = $content -replace 'Owner: <name/team>', ("Owner: " + $Owner)
$content = $content -replace 'Last Updated: YYYY-MM-DD', ("Last Updated: " + $today)
$content = $content -replace 'v0\.1\.0', 'v0.1.0'
$content = $content -replace '(?m)^Type\s*:\s*.*$', ("Type: " + $Type)
$content = $content -replace '(?m)^Level\s*:\s*.*$', ("Level: " + $Level)
$content = $content -replace '(?m)^Parent\s*:\s*.*$', ("Parent: " + $Parent)
$content = $content -replace '(?m)^Scopes\s*:\s*.*$', ("Scopes: " + $Scopes)
$content = $content -replace '(?m)^References\s*:\s*.*$', ("References: " + $References)
$content = $content -replace '(?m)^Service\s*:\s*.*$', ("Service: " + $Service)

Set-Content -NoNewline -Encoding UTF8 -Path $outPath -Value $content

$appendixPath = Join-Path $root $appendixName
$appendix = Get-Content -Raw -Encoding UTF8 $appendixTemplate
$appendix = $appendix -replace 'REQ-XXX', $id
$appendix = $appendix -replace '<Short Title>', $Title
$appendix = $appendix -replace $cnShortTitle, $Title
$appendix = $appendix -replace 'Owner: <name/team>', ("Owner: " + $Owner)
$appendix = $appendix -replace 'Last Updated: YYYY-MM-DD', ("Last Updated: " + $today)
$appendix = $appendix -replace 'v0\.1\.0', 'v0.1.0'
$appendix = $appendix -replace '(?m)^Type\s*:\s*.*$', ("Type: " + $Type)
$appendix = $appendix -replace '(?m)^Level\s*:\s*.*$', ("Level: " + $Level)
$appendix = $appendix -replace '(?m)^Parent\s*:\s*.*$', ("Parent: " + $Parent)
$appendix = $appendix -replace '(?m)^Scopes\s*:\s*.*$', ("Scopes: " + $Scopes)
$appendix = $appendix -replace '(?m)^References\s*:\s*.*$', ("References: " + $References)
$appendix = $appendix -replace '(?m)^Service\s*:\s*.*$', ("Service: " + $Service)
Set-Content -NoNewline -Encoding UTF8 -Path $appendixPath -Value $appendix

# Create acceptance checklist for this REQ.
$acc = Get-Content -Raw -Encoding UTF8 $acceptanceTemplate
$acc = $acc -replace 'REQ-XXX', $id
$acc = $acc -replace '<Short Title>', $Title
$acc = $acc -replace $cnShortTitle, $Title
$acc = $acc -replace '<title>', $slug
# Make the source link point to the actual file name we created.
$acc = $acc -replace ([regex]::Escape(("REQ-XXX-<title>.md"))), $fileName
$acc = $acc -replace 'vX\.Y\.Z', 'v0.1.0'
Set-Content -NoNewline -Encoding UTF8 -Path $acceptancePath -Value $acc

Write-Host "Created: $outPath"
Write-Host "Created: $appendixPath"
Write-Host "Created: $acceptancePath"
Write-Host "Next:"
Write-Host "- Fill out the REQ sections."
Write-Host "- Update INDEX.md and CHANGELOG.md."

if (-not $NoLedgerUpdate) {
  $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
  $ledgerScript = Join-Path $scriptDir "req-ledger.ps1"
  if (Test-Path $ledgerScript) {
    Write-Host ""
    Write-Host "Updating ledger (requirements/.audit/ledger.json) via req-ledger.ps1..."
    powershell -NoProfile -ExecutionPolicy Bypass -File $ledgerScript -RootPath $RootPath | Out-Host
    if ($LASTEXITCODE -ne 0) {
      throw ("Ledger update failed (exit " + $LASTEXITCODE + "). Fix the errors or rerun with -NoLedgerUpdate.")
    }
  }
}
