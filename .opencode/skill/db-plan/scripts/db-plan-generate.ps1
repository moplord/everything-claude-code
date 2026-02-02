param(
  [Parameter(Mandatory = $false)]
  [string]$RequirementsRoot = "requirements",

  [Parameter(Mandatory = $false)]
  [string[]]$ReqId = @(),

  [Parameter(Mandatory = $false)]
  [string]$OutRoot = "jdl\\generated",

  [Parameter(Mandatory = $false)]
  [switch]$Force
)

$ErrorActionPreference = "Stop"

# Keep this script ASCII-only for Windows PowerShell compatibility.
$ZH_VERSION = [regex]::Unescape('\u7248\u672c')
$ZH_TYPE = [regex]::Unescape('\u7c7b\u578b')
$ZH_SERVICE = [regex]::Unescape('\u670d\u52a1')
$ZH_SERVICE_ALT = [regex]::Unescape('\u5fae\u670d\u52a1')

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

function Get-FrontMatterLikeField {
  param([string]$text, [string[]]$fields)
  foreach ($line in ($text -split "`n")) {
    foreach ($field in $fields) {
      $re = '^(?:\uFEFF)?\s*' + [regex]::Escape($field) + '\s*[:\uFF1A]\s*(.*)$'
      if ($line -match $re) { return $Matches[1].Trim() }
    }
  }
  return $null
}

function Split-TableLine {
  param([string]$line)
  $t = $line.Trim()
  if ($t.StartsWith("|")) { $t = $t.Substring(1) }
  if ($t.EndsWith("|")) { $t = $t.Substring(0, $t.Length - 1) }
  $parts = $t -split '\|'
  return @($parts | ForEach-Object { $_.Trim() })
}

function Parse-MarkdownTablesByHeader {
  param(
    [string]$text,
    [string[]]$requiredCols
  )

  $tables = @()
  $lines = $text -split "`n"
  for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]
    if ($line -notmatch '^\s*\|') { continue }

    $hdr = Split-TableLine -line $line
    if ($hdr.Count -lt 2) { continue }
    $sepIdx = $i + 1
    if ($sepIdx -ge $lines.Length) { continue }
    if ($lines[$sepIdx] -notmatch '^\s*\|\s*[-: ]+\|') { continue }

    $hasAll = $true
    foreach ($c in $requiredCols) {
      if (-not ($hdr -contains $c)) { $hasAll = $false; break }
    }
    if (-not $hasAll) { continue }

    $colIndex = @{}
    for ($ci = 0; $ci -lt $hdr.Count; $ci++) {
      $colIndex[$hdr[$ci]] = $ci
    }

    $rows = @()
    $j = $i + 2
    while ($j -lt $lines.Length) {
      $rline = $lines[$j]
      if ($rline -notmatch '^\s*\|') { break }
      $cells = Split-TableLine -line $rline
      if ($cells.Count -lt $hdr.Count) {
        while ($cells.Count -lt $hdr.Count) { $cells += "" }
      }
      $obj = [ordered]@{}
      foreach ($k in $colIndex.Keys) {
        $obj[$k] = $cells[$colIndex[$k]]
      }
      $rows += [pscustomobject]$obj
      $j++
    }

    $tables += [pscustomobject]@{ header = $hdr; rows = $rows; startLine = $i + 1 }
  }

  return $tables
}

function Require-NonEmpty {
  param([string]$what, [string]$v)
  if (-not $v -or $v.Trim().Length -eq 0 -or $v.Trim() -match '^<.*>$') {
    throw ("Missing required value: " + $what)
  }
  return $v.Trim()
}

function Ensure-OutDir {
  param([string]$p)
  if (!(Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function Get-ReqIdFromFileName {
  param([string]$name)
  $m = [regex]::Match($name, '^REQ-(\d{3})-')
  if (-not $m.Success) { return "" }
  return ("REQ-" + $m.Groups[1].Value)
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

$reqRoot = Join-Path (Get-Location) $RequirementsRoot
if (!(Test-Path $reqRoot)) { throw ("Requirements root not found: " + $reqRoot) }

Ensure-OutDir -p $OutRoot

$targets = @()
if ($ReqId -and $ReqId.Count -gt 0) {
  foreach ($ridIn in $ReqId) {
    $rid = $ridIn.Trim().ToUpperInvariant()
    if ($rid -notmatch '^REQ-\d{3}$') { throw ("ReqId must look like REQ-### (got: " + $ridIn + ")") }
    $main = Find-ReqMainFile -root $reqRoot -rid $rid
    if (-not $main) { throw ("REQ not found: " + $rid) }
    $appendix = Find-ReqAppendixFile -root $reqRoot -mainFile $main
    if (-not $appendix) { throw ("Appendix not found for: " + $main) }
    $targets += [pscustomobject]@{ rid = $rid; main = $main; appendix = $appendix }
  }
} else {
  $files = Get-ChildItem -Path $reqRoot -File -Filter "REQ-*.md" | Where-Object { $_.Name -notlike "*-appendix.md" } | Sort-Object Name
  foreach ($f in $files) {
    $rid = Get-ReqIdFromFileName -name $f.Name
    if (-not $rid) { continue }
    $t = Read-TextFile -path $f.FullName
    $type = Get-FrontMatterLikeField -text $t -fields @("Type", $ZH_TYPE)
    if (-not $type -or $type.Trim() -ne "domain-model") { continue }
    $appendix = Find-ReqAppendixFile -root $reqRoot -mainFile $f.FullName
    if (-not $appendix) { throw ("Appendix not found for: " + $f.FullName) }
    $targets += [pscustomobject]@{ rid = $rid; main = $f.FullName; appendix = $appendix }
  }
}

if ($targets.Count -eq 0) {
  Write-Host "No Type=domain-model REQs found to generate db-plan."
  exit 0
}

foreach ($tgt in $targets) {
  $mainText = Read-TextFile -path $tgt.main
  $version = Get-FrontMatterLikeField -text $mainText -fields @("Version", $ZH_VERSION)
  $service = Get-FrontMatterLikeField -text $mainText -fields @("Service", $ZH_SERVICE, $ZH_SERVICE_ALT)
  if (-not $service -or $service.Trim().Length -eq 0) { $service = "monolith" }
  $service = $service.Trim()

  $appendixText = Read-TextFile -path $tgt.appendix

  # Parse entities and fields for reference validation in plan output.
  $entitiesTbl = Parse-MarkdownTablesByHeader -text $appendixText -requiredCols @("EntityCode(PascalCase)")
  if ($entitiesTbl.Count -eq 0) { $entitiesTbl = Parse-MarkdownTablesByHeader -text $appendixText -requiredCols @("EntityCode") }
  if ($entitiesTbl.Count -eq 0) { throw ("Missing Entities table with EntityCode column in appendix: " + $tgt.appendix) }
  $entities = @()
  foreach ($row in $entitiesTbl[0].rows) {
    $ec = $row."EntityCode(PascalCase)"; if (-not $ec) { $ec = $row.EntityCode }
    $entities += (Require-NonEmpty -what "EntityCode" -v $ec)
  }
  $entities = $entities | Select-Object -Unique

  $fieldTbls = Parse-MarkdownTablesByHeader -text $appendixText -requiredCols @("EntityCode", "FieldCode(camelCase)")
  if ($fieldTbls.Count -eq 0) { $fieldTbls = Parse-MarkdownTablesByHeader -text $appendixText -requiredCols @("EntityCode", "FieldCode") }
  if ($fieldTbls.Count -eq 0) { throw ("Missing Field Dictionary table with EntityCode+FieldCode in appendix: " + $tgt.appendix) }

  $fieldSet = @{}
  foreach ($tbl in $fieldTbls) {
    foreach ($row in $tbl.rows) {
      $ec = Require-NonEmpty -what "EntityCode" -v $row.EntityCode
      $fc = $row."FieldCode(camelCase)"; if (-not $fc) { $fc = $row.FieldCode }
      $fc = Require-NonEmpty -what ($ec + ".FieldCode") -v $fc
      $fieldSet[($ec + "." + $fc)] = $true
    }
  }

  # Optional D1/D2/D3 tables.
  $accessTbls = Parse-MarkdownTablesByHeader -text $appendixText -requiredCols @("Scenario", "Filters (EntityCode.FieldCode)", "Sort", "Pagination")
  $indexTbls = Parse-MarkdownTablesByHeader -text $appendixText -requiredCols @("Index Name", "On (EntityCode)", "Fields (FieldCode...)", "Unique")
  $cacheTbls = Parse-MarkdownTablesByHeader -text $appendixText -requiredCols @("Cache Key", "Source", "TTL", "Invalidation")

  $outDir = Join-Path $OutRoot $service
  Ensure-OutDir -p $outDir
  $outPath = Join-Path $outDir ($tgt.rid + ".db-plan.md")

  if ((Test-Path $outPath) -and (-not $Force)) {
    Write-Host ("SKIP (exists): " + $outPath)
    continue
  }

  $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $out = @()
  $out += ("# DB Plan: " + $tgt.rid)
  $out += ""
  $out += ("> Generated by db-plan-generate.ps1 at " + $now + ". DB-agnostic plan (no SQL, no Liquibase).")
  $out += ""
  $out += ("- Source REQ: " + $tgt.rid + " " + $version)
  $out += ("- Source files: " + (Split-Path -Leaf $tgt.main) + " ; " + (Split-Path -Leaf $tgt.appendix))
  $out += ("- Service: " + $service)
  $out += ""

  $out += "## 1. Entities"
  $out += ""
  foreach ($e in ($entities | Sort-Object)) { $out += ("- " + $e) }
  $out += ""

  $out += "## 2. Access Patterns (Optional)"
  $out += ""
  if ($accessTbls.Count -eq 0) {
    $out += "(none)"
  } else {
    foreach ($row in $accessTbls[0].rows) {
      $sc = Require-NonEmpty -what "Access Pattern Scenario" -v $row.Scenario
      $out += ("- " + $sc)
      $out += ("  - Filters: " + $row."Filters (EntityCode.FieldCode)")
      $out += ("  - Sort: " + $row.Sort)
      $out += ("  - Pagination: " + $row.Pagination)
    }
  }
  $out += ""

  $out += "## 3. Index Plan (Optional)"
  $out += ""
  if ($indexTbls.Count -eq 0) {
    $out += "(none)"
  } else {
    $out += "| Index Name | On (EntityCode) | Fields (FieldCode...) | Unique | Purpose | Notes |"
    $out += "|---|---|---|---:|---|---|"
    foreach ($row in $indexTbls[0].rows) {
      $on = Require-NonEmpty -what "Index On (EntityCode)" -v $row."On (EntityCode)"
      $fields = Require-NonEmpty -what ("Index Fields for " + $on) -v $row."Fields (FieldCode...)"
      # Validate referenced fields exist.
      foreach ($f in ($fields -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })) {
        $key = $on + "." + $f
        if (-not $fieldSet.ContainsKey($key)) {
          throw ("Index Plan references unknown field: " + $key)
        }
      }
      $out += ("| " + $row."Index Name" + " | " + $on + " | " + $fields + " | " + $row.Unique + " | " + $row.Purpose + " | " + $row.Notes + " |")
    }
  }
  $out += ""

  $out += "## 4. Cache Plan (Optional)"
  $out += ""
  if ($cacheTbls.Count -eq 0) {
    $out += "(none)"
  } else {
    $out += "| Cache Key | Source | TTL | Invalidation | Consistency | Notes |"
    $out += "|---|---|---|---|---|---|"
    foreach ($row in $cacheTbls[0].rows) {
      $out += ("| " + $row."Cache Key" + " | " + $row.Source + " | " + $row.TTL + " | " + $row.Invalidation + " | " + $row.Consistency + " | " + $row.Notes + " |")
    }
  }
  $out += ""

  Set-Content -NoNewline -Encoding UTF8 -Path $outPath -Value ($out -join "`n")
  Write-Host ("Wrote DB plan: " + $outPath)
}

