param(
  [Parameter(Mandatory = $false)]
  [string]$RootPath = "requirements",

  [Parameter(Mandatory = $true)]
  [string]$Title,

  [Parameter(Mandatory = $false)]
  [string]$Owner = "team",

  [Parameter(Mandatory = $false)]
  [string]$Locale = "en-US"
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
      if ($_.Name -match "^REQ-(\\d{3})-") {
        $n = [int]$Matches[1]
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

$template = Join-Path $root "templates\\REQ-TEMPLATE.md"
if ($Locale -and ($Locale.ToLowerInvariant() -ne "en-us")) {
  $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
  $assetsRoot = Join-Path $scriptDir "..\\assets\\requirements"
  $localeRoot = Join-Path $assetsRoot $Locale
  if (Test-Path $localeRoot) {
    $template = Join-Path $localeRoot "templates\\REQ-TEMPLATE.md"
  }
}
if (!(Test-Path $template)) {
  throw "Missing template: $template"
}

$n = Get-NextReqNumber -root $root
$id = ("REQ-{0:D3}" -f $n)
$slug = Sanitize-Slug -s $Title
$fileName = "$id-$slug.md"
$outPath = Join-Path $root $fileName
if (Test-Path $outPath) {
  throw "REQ already exists: $outPath"
}

$today = Get-Date -Format "yyyy-MM-dd"
$content = Get-Content -Raw -Encoding UTF8 $template
$content = $content -replace 'REQ-XXX', $id
$content = $content -replace '<Short Title>', $Title
$content = $content -replace 'Owner: <name/team>', ("Owner: " + $Owner)
$content = $content -replace 'Last Updated: YYYY-MM-DD', ("Last Updated: " + $today)
$content = $content -replace 'v0\.1\.0', 'v0.1.0'

Set-Content -NoNewline -Encoding UTF8 -Path $outPath -Value $content

Write-Host "Created: $outPath"
Write-Host "Next:"
Write-Host "- Fill out the REQ sections."
Write-Host "- Create acceptance checklist in ACCEPTANCE/."
Write-Host "- Update INDEX.md and CHANGELOG.md."
