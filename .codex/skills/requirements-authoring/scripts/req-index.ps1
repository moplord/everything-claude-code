param(
  [Parameter(Mandatory = $false)]
  [string]$RootPath = "requirements",

  [Parameter(Mandatory = $false)]
  [string]$OutFile = ""
)

$ErrorActionPreference = "Stop"

# Keep this script ASCII-only for Windows PowerShell compatibility.
$ZH_STATUS = [regex]::Unescape('\u72b6\u6001')
$ZH_VERSION = [regex]::Unescape('\u7248\u672c')
$ZH_OWNER = [regex]::Unescape('\u8d1f\u8d23\u4eba')
$ZH_LAST_UPDATED = [regex]::Unescape('\u6700\u540e\u66f4\u65b0')
$ZH_UPDATED_AT = [regex]::Unescape('\u66f4\u65b0\u65f6\u95f4')
$ZH_TYPE = [regex]::Unescape('\u7c7b\u578b')
$ZH_LEVEL = [regex]::Unescape('\u5c42\u7ea7')
$ZH_PARENT = [regex]::Unescape('\u7236\u9700\u6c42')
$ZH_PARENT_ALT = [regex]::Unescape('\u4e0a\u7ea7\u9700\u6c42')
$ZH_SCOPES = [regex]::Unescape('\u8303\u56f4')
$ZH_SCOPES_ALT = [regex]::Unescape('\u7aef')
$ZH_REFERENCES = [regex]::Unescape('\u5f15\u7528')
$ZH_REFERENCES_ALT = [regex]::Unescape('\u53c2\u8003')
$ZH_SERVICE = [regex]::Unescape('\u670d\u52a1')
$ZH_SERVICE_ALT = [regex]::Unescape('\u5fae\u670d\u52a1')

function Count-ReplacementChar {
  param([string]$s)
  if (-not $s) { return 0 }
  return ([regex]::Matches($s, [string][char]0xFFFD)).Count
}

function Read-TextFile {
  param([string]$path)

  # Decode markdown robustly across common Windows editors.
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

function Get-FrontMatterLikeField {
  param([string]$text, [string[]]$fields)
  $lines = $text -split "`n"

  foreach ($line in $lines) {
    foreach ($field in $fields) {
      $fieldEsc = [regex]::Escape($field)
      $re = '^(?:\uFEFF)?\s*' + $fieldEsc + '\s*[:\uFF1A]\s*(.*)$'
      if ($line -match $re) {
        return $Matches[1].Trim()
      }
    }
  }

  foreach ($line in $lines) {
    if ($line -notmatch '^\s*\|') { continue }
    $cols = $line.Trim() -split '\|'
    if ($cols.Count -lt 3) { continue }
    $k = $cols[1].Trim()
    $v = $cols[2].Trim()
    foreach ($field in $fields) {
      if ($k -eq $field) { return $v }
    }
  }

  return $null
}

function Extract-Title {
  param([string]$text, [string]$id)
  $lines = $text -split "`n"
  foreach ($line in $lines) {
    if ($line -match '^\s*#\s*(.+)$') {
      $h = $Matches[1].Trim()
      # Common: "REQ-001 - Title" or "REQ-001 Title"
      $re1 = '^(?:' + [regex]::Escape($id) + ')\s*[-\u2013\u2014]\s*(.+)$'
      if ($h -match $re1) { return $Matches[1].Trim() }
      $re2 = '^(?:' + [regex]::Escape($id) + ')\s+(.+)$'
      if ($h -match $re2) { return $Matches[1].Trim() }
      return $h
    }
  }
  return ""
}

function Normalize-Scopes {
  param([string]$s)
  if (-not $s) { return "" }
  $t = $s.Trim()
  if ($t.Length -eq 0) { return "" }
  $parts = $t -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
  return ($parts -join ",")
}

$root = Join-Path (Get-Location) $RootPath
if (!(Test-Path $root)) {
  throw "Requirements root folder does not exist: $root"
}

$outPath = $OutFile
if (-not $outPath -or $outPath.Trim().Length -eq 0) {
  $outPath = Join-Path $root "INDEX.md"
}

$reqFiles = Get-ChildItem -Path $root -File -Filter "REQ-*.md" | Where-Object { $_.Name -notlike "*-appendix.md" } | Sort-Object Name
$items = @()
foreach ($f in $reqFiles) {
  $t = Read-TextFile -path $f.FullName
  if ($f.Name -notmatch '^REQ-(\d{3})-') { continue }
  $id = ("REQ-{0}" -f $Matches[1])

  $status = Get-FrontMatterLikeField -text $t -fields @("Status", $ZH_STATUS)
  $version = Get-FrontMatterLikeField -text $t -fields @("Version", $ZH_VERSION)
  $owner = Get-FrontMatterLikeField -text $t -fields @("Owner", $ZH_OWNER)
  $updated = Get-FrontMatterLikeField -text $t -fields @("Last Updated", $ZH_LAST_UPDATED, $ZH_UPDATED_AT)
  $type = Get-FrontMatterLikeField -text $t -fields @("Type", $ZH_TYPE)
  $level = Get-FrontMatterLikeField -text $t -fields @("Level", $ZH_LEVEL)
  $parent = Get-FrontMatterLikeField -text $t -fields @("Parent", $ZH_PARENT, $ZH_PARENT_ALT)
  $scopes = Normalize-Scopes -s (Get-FrontMatterLikeField -text $t -fields @("Scopes", $ZH_SCOPES, $ZH_SCOPES_ALT))
  $refs = Get-FrontMatterLikeField -text $t -fields @("References", $ZH_REFERENCES, $ZH_REFERENCES_ALT)
  $service = Get-FrontMatterLikeField -text $t -fields @("Service", $ZH_SERVICE, $ZH_SERVICE_ALT)
  $title = Extract-Title -text $t -id $id

  $items += [pscustomobject]@{
    id = $id
    title = $title
    type = $type
    level = $level
    parent = $parent
    scopes = $scopes
    references = $refs
    service = $service
    status = $status
    version = $version
    owner = $owner
    updated = $updated
    filename = $f.Name
  }
}

function Parent-IdOrEmpty {
  param([string]$p)
  if (-not $p) { return "" }
  if ($p -match 'REQ-\d{3}') { return $Matches[0] }
  return ""
}

$childrenByParent = @{}
foreach ($it in $items) {
  $parentKey = Parent-IdOrEmpty -p $it.parent
  if (-not $childrenByParent.ContainsKey($parentKey)) { $childrenByParent[$parentKey] = @() }
  $childrenByParent[$parentKey] += $it
}

function Emit-Tree {
  param(
    [string]$parentId,
    [int]$depth
  )
  if (-not $childrenByParent.ContainsKey($parentId)) { return @() }
  $lines = @()
  $kids = $childrenByParent[$parentId] | Sort-Object id
  foreach ($k in $kids) {
    $indent = ("  " * $depth)
    $meta = @()
    if ($k.type) { $meta += $k.type }
    if ($k.status) { $meta += $k.status }
    if ($k.version) { $meta += $k.version }
    $metaStr = ""
    if ($meta.Count -gt 0) { $metaStr = " (" + ($meta -join " ") + ")" }
    $lines += ($indent + "- " + $k.id + " " + $k.title + $metaStr)
    $lines += Emit-Tree -parentId $k.id -depth ($depth + 1)
  }
  return $lines
}

function Scopes-Map {
  param($items)
  $map = @{}
  foreach ($it in $items) {
    if (-not $it.scopes) { continue }
    foreach ($s in ($it.scopes -split ',')) {
      $k = $s.Trim()
      if ($k.Length -eq 0) { continue }
      if (-not $map.ContainsKey($k)) { $map[$k] = @() }
      $map[$k] += $it
    }
  }
  return $map
}

$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$out = @()
$out += "# Requirements Index"
$out += ""
$out += "> Generated by req-index.ps1 at $now. Edit REQ files; regenerate this index."
$out += ""
$out += "## Table"
$out += ""
$out += "| ID | Title | Type | Level | Service | Scopes | Status | Version | Owner | Last Updated | Parent | File |"
$out += "|---|---|---|---|---|---|---|---|---|---|---|---|"
foreach ($it in ($items | Sort-Object id)) {
  $out += ("| " + $it.id + " | " + $it.title + " | " + $it.type + " | " + $it.level + " | " + $it.service + " | " + $it.scopes + " | " + $it.status + " | " + $it.version + " | " + $it.owner + " | " + $it.updated + " | " + $it.parent + " | " + $it.filename + " |")
}
$out += ""
$out += "## Hierarchy (by Parent)"
$out += ""
$out += (Emit-Tree -parentId "" -depth 0)
$out += ""
$out += "## By Scope"
$out += ""
$scopeMap = Scopes-Map -items $items
foreach ($k in ($scopeMap.Keys | Sort-Object)) {
  $out += ("### " + $k)
  $out += ""
  foreach ($it in ($scopeMap[$k] | Sort-Object id)) {
    $out += ("- " + $it.id + " " + $it.title)
  }
  $out += ""
}

Set-Content -NoNewline -Encoding UTF8 -Path $outPath -Value ($out -join "`n")
Write-Host "Wrote index: $outPath"
