param(
  [Parameter(Mandatory = $false)]
  [string]$RootPath = "requirements",

  [Parameter(Mandatory = $true)]
  [string]$ReqId,

  [Parameter(Mandatory = $false)]
  [string]$OutDir = ".packs",

  [Parameter(Mandatory = $false)]
  [switch]$IncludeReferences,

  [Parameter(Mandatory = $false)]
  [switch]$IncludeDecisions,

  [Parameter(Mandatory = $false)]
  [switch]$IncludeAcceptance = $true,

  [Parameter(Mandatory = $false)]
  [switch]$IncludeChangelog = $true
)

$ErrorActionPreference = "Stop"

function Count-ReplacementChar {
  param([string]$s)
  if (-not $s) { return 0 }
  return ([regex]::Matches($s, [string][char]0xFFFD)).Count
}

function Read-TextFile {
  param([string]$path)

  $bytes = [System.IO.File]::ReadAllBytes($path)
  if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
    return [System.Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2)
  }
  if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
    return [System.Text.Encoding]::BigEndianUnicode.GetString($bytes, 2, $bytes.Length - 2)
  }
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    return [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
  }

  $utf8 = [System.Text.Encoding]::UTF8.GetString($bytes)
  $utf8Bad = Count-ReplacementChar -s $utf8
  if ($utf8Bad -gt 0) {
    try {
      $gbk = [System.Text.Encoding]::GetEncoding(936).GetString($bytes)
      $gbkBad = Count-ReplacementChar -s $gbk
      if ($gbkBad -lt $utf8Bad) { return $gbk }
    } catch {
      # Ignore and fall back to UTF-8.
    }
  }
  return $utf8
}

function Find-ReqMainFile {
  param([string]$root, [string]$rid)
  $f = Get-ChildItem -Path $root -File -Filter "$rid-*.md" | Where-Object { $_.Name -notlike "*-appendix.md" } | Select-Object -First 1
  if ($f) { return $f.FullName }
  return ""
}

function Find-ReqAppendixFile {
  param([string]$root, [string]$mainFile)
  $nameNoExt = [System.IO.Path]::GetFileNameWithoutExtension($mainFile)
  $ax = Join-Path $root ($nameNoExt + "-appendix.md")
  if (Test-Path $ax) { return $ax }
  return ""
}

function Parse-HeaderValue {
  param([string]$text, [string]$key)
  foreach ($line in ($text -split "`n")) {
    $re = '^(?:\uFEFF)?\s*' + [regex]::Escape($key) + '\s*[:\uFF1A]\s*(.*)$'
    if ($line -match $re) { return $Matches[1].Trim() }
  }
  return ""
}

function Parse-References {
  param([string]$s)
  $ids = @()
  if (-not $s) { return $ids }
  foreach ($m in [regex]::Matches($s, 'REQ-\d{3}')) { $ids += $m.Value }
  return ($ids | Select-Object -Unique)
}

function Slug-ForFile {
  param([string]$s)
  $slug = $s.Trim()
  $slug = $slug -replace '[\\/:*?"<>|]', ''
  $slug = $slug -replace '\s+', '-'
  $slug = $slug -replace '-{2,}', '-'
  $slug = $slug.Trim("-")
  if ($slug.Length -eq 0) { $slug = "pack" }
  return $slug
}

$root = Join-Path (Get-Location) $RootPath
if (!(Test-Path $root)) { throw "RootPath does not exist: $root" }

$rid = $ReqId.Trim().ToUpperInvariant()
if ($rid -notmatch '^REQ-\d{3}$') { throw "ReqId must look like REQ-### (got: $ReqId)" }

$main = Find-ReqMainFile -root $root -rid $rid
if (-not $main) { throw "REQ not found: $rid" }
$mainText = Read-TextFile -path $main

$appendix = Find-ReqAppendixFile -root $root -mainFile $main
if (-not $appendix) { throw "Appendix not found for: $main" }
$appendixText = Read-TextFile -path $appendix

$acceptancePath = Join-Path $root ("ACCEPTANCE\\{0}-acceptance.md" -f $rid)
$acceptanceText = ""
if ($IncludeAcceptance) {
  if (Test-Path $acceptancePath) {
    $acceptanceText = Read-TextFile -path $acceptancePath
  } else {
    $acceptanceText = "(missing acceptance checklist: " + (Split-Path -Leaf $acceptancePath) + ")"
  }
}

$changelogPath = Join-Path $root "CHANGELOG.md"
$changelogText = ""
if ($IncludeChangelog -and (Test-Path $changelogPath)) {
  $changelogText = Read-TextFile -path $changelogPath
}

$refs = Parse-References -s (Parse-HeaderValue -text $mainText -key "References")

$decisions = @()
if ($IncludeDecisions) {
  $decDir = Join-Path $root "DECISIONS"
  if (Test-Path $decDir) {
    $decisions = Get-ChildItem -Path $decDir -File -Filter "$rid-ADR-*.md" | Sort-Object Name
  }
}

$refBlocks = @()
if ($IncludeReferences) {
  foreach ($r in $refs) {
    if ($r -eq $rid) { continue }
    $rm = Find-ReqMainFile -root $root -rid $r
    if (-not $rm) { continue }
    $rmText = Read-TextFile -path $rm
    $rax = Find-ReqAppendixFile -root $root -mainFile $rm
    $raxText = ""
    if ($rax) { $raxText = Read-TextFile -path $rax }

    $refBlocks += [pscustomobject]@{
      id = $r
      mainPath = $rm
      mainText = $rmText
      appendixPath = $rax
      appendixText = $raxText
    }
  }
}

$outDirPath = Join-Path $root $OutDir
if (!(Test-Path $outDirPath)) { New-Item -ItemType Directory -Force -Path $outDirPath | Out-Null }

$title = ""
if ($mainText -match '(?m)^\s*#\s*(.+)$') { $title = $Matches[1].Trim() }
$slug = Slug-ForFile -s ($rid + "-" + $title)
$outPath = Join-Path $outDirPath ($slug + ".md")

$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$out = @()
$out += "# Requirements Pack: $rid"
$out += ""
$out += "> Generated by req-pack.ps1 at $now. This file is read-only output for downstream generation/testing."
$out += ""
$out += "## 1. REQ (Main)"
$out += ""
$out += "Source: `$(Split-Path -Leaf $main)`"
$out += ""
$out += $mainText
$out += ""
$out += "## 2. REQ Appendix"
$out += ""
$out += "Source: `$(Split-Path -Leaf $appendix)`"
$out += ""
$out += $appendixText
$out += ""

if ($IncludeAcceptance) {
  $out += "## 3. Acceptance Checklist"
  $out += ""
  $out += "Source: `$(Split-Path -Leaf $acceptancePath)`"
  $out += ""
  $out += $acceptanceText
  $out += ""
}

if ($IncludeDecisions -and $decisions.Count -gt 0) {
  $out += "## 4. Decisions (ADRs)"
  $out += ""
  foreach ($d in $decisions) {
    $out += "### $(Split-Path -Leaf $d.FullName)"
    $out += ""
    $out += (Read-TextFile -path $d.FullName)
    $out += ""
  }
}

if ($IncludeReferences -and $refBlocks.Count -gt 0) {
  $out += "## 5. Referenced REQs"
  $out += ""
  foreach ($b in $refBlocks) {
    $out += "### $($b.id) (Main)"
    $out += ""
    $out += "Source: `$(Split-Path -Leaf $b.mainPath)`"
    $out += ""
    $out += $b.mainText
    $out += ""
    if ($b.appendixPath) {
      $out += "### $($b.id) (Appendix)"
      $out += ""
      $out += "Source: `$(Split-Path -Leaf $b.appendixPath)`"
      $out += ""
      $out += $b.appendixText
      $out += ""
    }
  }
}

if ($IncludeChangelog -and $changelogText) {
  $out += "## 6. CHANGELOG (Full)"
  $out += ""
  $out += "Source: `CHANGELOG.md`"
  $out += ""
  $out += $changelogText
  $out += ""
}

Set-Content -NoNewline -Encoding UTF8 -Path $outPath -Value ($out -join "`n")
Write-Host ("Wrote pack: " + $outPath)
