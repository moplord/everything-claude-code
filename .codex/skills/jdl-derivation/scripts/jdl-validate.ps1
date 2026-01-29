param(
  [Parameter(Mandatory = $false)]
  [string]$RequirementsRoot = "requirements",

  [Parameter(Mandatory = $false)]
  [string[]]$ReqId = @(),

  [Parameter(Mandatory = $false)]
  [string]$OutRoot = "jdl\\generated"
)

$ErrorActionPreference = "Stop"

function Fail {
  param([string]$msg)
  Write-Host ("FAIL: " + $msg)
  exit 2
}

$reqRoot = Join-Path (Get-Location) $RequirementsRoot
if (!(Test-Path $reqRoot)) { Fail ("Requirements root not found: " + $reqRoot) }
if (!(Test-Path $OutRoot)) { Fail ("OutRoot not found: " + (Join-Path (Get-Location) $OutRoot)) }

# Basic validation: ensure derived file exists for each selected domain-model REQ.
function Get-ReqIdFromFileName {
  param([string]$name)
  $m = [regex]::Match($name, '^REQ-(\d{3})-')
  if (-not $m.Success) { return "" }
  return ("REQ-" + $m.Groups[1].Value)
}

function Read-TextFile {
  param([string]$path)
  $bytes = [System.IO.File]::ReadAllBytes($path)
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    return [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
  }
  return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Get-FrontMatterLikeField {
  param([string]$text, [string]$field)
  foreach ($line in ($text -split "`n")) {
    $re = '^(?:\uFEFF)?\s*' + [regex]::Escape($field) + '\s*[:\uFF1A]\s*(.*)$'
    if ($line -match $re) { return $Matches[1].Trim() }
  }
  return ""
}

$reqFiles = @()
if ($ReqId -and $ReqId.Count -gt 0) {
  foreach ($ridIn in $ReqId) {
    $rid = $ridIn.Trim().ToUpperInvariant()
    $f = Get-ChildItem -Path $reqRoot -File -Filter "$rid-*.md" | Where-Object { $_.Name -notlike "*-appendix.md" } | Select-Object -First 1
    if (-not $f) { Fail ("REQ not found: " + $rid) }
    $reqFiles += $f
  }
} else {
  $reqFiles = Get-ChildItem -Path $reqRoot -File -Filter "REQ-*.md" | Where-Object { $_.Name -notlike "*-appendix.md" } | Sort-Object Name
}

$domainReqs = @()
foreach ($f in $reqFiles) {
  $txt = Read-TextFile -path $f.FullName
  $type = Get-FrontMatterLikeField -text $txt -field "Type"
  if ($type -and $type.Trim() -eq "domain-model") { $domainReqs += $f }
}

if ($domainReqs.Count -eq 0) {
  Write-Host "No Type=domain-model REQs found to validate."
  exit 0
}

$missing = @()
foreach ($f in $domainReqs) {
  $rid = Get-ReqIdFromFileName -name $f.Name
  if (-not $rid) { continue }
  # We cannot infer service here robustly without decoding; just search for any matching output.
  $matches = Get-ChildItem -Path $OutRoot -Recurse -File -Filter ($rid + ".jdl") -ErrorAction SilentlyContinue
  if (-not $matches -or $matches.Count -eq 0) {
    $missing += $rid
  }
}

if ($missing.Count -gt 0) {
  Fail ("Missing derived JDL files for: " + ($missing -join ", ") + ". Run jdl-derive.ps1 first.")
}

Write-Host "PASS: JDL outputs exist for all selected domain-model REQs."
exit 0

