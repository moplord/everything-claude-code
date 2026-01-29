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
$appendixTemplate = Join-Path $root "templates\\APPENDIX-TEMPLATE.md"
if ($Locale -and ($Locale.ToLowerInvariant() -ne "en-us")) {
  $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
  $assetsRoot = Join-Path $scriptDir "..\\assets\\requirements"
  $localeRoot = Join-Path $assetsRoot $Locale
  if (Test-Path $localeRoot) {
    $template = Join-Path $localeRoot "templates\\REQ-TEMPLATE.md"
    $appendixTemplate = Join-Path $localeRoot "templates\\APPENDIX-TEMPLATE.md"
  }
}
if (!(Test-Path $template)) {
  throw "Missing template: $template"
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

$today = Get-Date -Format "yyyy-MM-dd"
$content = Get-Content -Raw -Encoding UTF8 $template
$content = $content -replace 'REQ-XXX', $id
$content = $content -replace '<Short Title>', $Title
$content = $content -replace '<短标题>', $Title
$content = $content -replace 'Owner: <name/team>', ("Owner: " + $Owner)
$content = $content -replace 'Last Updated: YYYY-MM-DD', ("Last Updated: " + $today)
$content = $content -replace 'v0\.1\.0', 'v0.1.0'

Set-Content -NoNewline -Encoding UTF8 -Path $outPath -Value $content

$appendixPath = Join-Path $root $appendixName
$appendix = Get-Content -Raw -Encoding UTF8 $appendixTemplate
$appendix = $appendix -replace 'REQ-XXX', $id
$appendix = $appendix -replace '<Short Title>', $Title
$appendix = $appendix -replace '<短标题>', $Title
$appendix = $appendix -replace 'Owner: <name/team>', ("Owner: " + $Owner)
$appendix = $appendix -replace 'Last Updated: YYYY-MM-DD', ("Last Updated: " + $today)
$appendix = $appendix -replace 'v0\.1\.0', 'v0.1.0'
Set-Content -NoNewline -Encoding UTF8 -Path $appendixPath -Value $appendix

Write-Host "Created: $outPath"
Write-Host "Created: $appendixPath"
Write-Host "Next:"
Write-Host "- Fill out the REQ sections."
Write-Host "- Create acceptance checklist in ACCEPTANCE/."
Write-Host "- Update INDEX.md and CHANGELOG.md."
