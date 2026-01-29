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
$ZH_STATUS = [regex]::Unescape('\u72b6\u6001')
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
      if ($rline -match '^\s*\|\s*[-: ]+\|\s*$') { $j++; continue }
      $cells = Split-TableLine -line $rline
      if ($cells.Count -lt $hdr.Count) {
        # Pad missing tail cells.
        while ($cells.Count -lt $hdr.Count) { $cells += "" }
      }
      $obj = [ordered]@{}
      foreach ($k in $colIndex.Keys) {
        $obj[$k] = $cells[$colIndex[$k]]
      }
      $rows += [pscustomobject]$obj
      $j++
    }

    $tables += [pscustomobject]@{
      header = $hdr
      rows = $rows
      startLine = $i + 1
    }
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

function Normalize-YesNo {
  param([string]$s)
  if (-not $s) { return $false }
  $t = $s.Trim().ToLowerInvariant()
  return ($t -eq "y" -or $t -eq "yes" -or $t -eq "true" -or $t -eq "1" -or $t -eq "required")
}

function Normalize-Bool {
  param([string]$s)
  if (-not $s) { return $false }
  $t = $s.Trim().ToLowerInvariant()
  return ($t -eq "y" -or $t -eq "yes" -or $t -eq "true" -or $t -eq "1")
}

function Pick-JdlType {
  param([string]$raw)
  $v = Require-NonEmpty -what "Type Candidates (JDL)" -v $raw
  # If user wrote multiple candidates, force them to choose one.
  if ($v -match '[,/]') {
    throw ("Ambiguous JDL type candidates: '" + $v + "'. Provide exactly one JDL type token.")
  }
  $m = [regex]::Match($v, '^[A-Za-z][A-Za-z0-9]*')
  if (-not $m.Success) {
    throw ("Invalid JDL type candidates: '" + $v + "'.")
  }
  return $m.Value
}

function Is-Valid-Pascal {
  param([string]$s)
  return [regex]::IsMatch($s, '^[A-Z][A-Za-z0-9]*$')
}

function Is-Valid-Camel {
  param([string]$s)
  return [regex]::IsMatch($s, '^[a-z][A-Za-z0-9]*$')
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

function Build-FieldOptions {
  param(
    [string]$type,
    [bool]$required,
    [string]$uniqueIndexRaw,
    [string]$lenRaw,
    [string]$validationRaw
  )

  $opts = @()
  if ($required) { $opts += "required" }

  $u = ""
  if ($uniqueIndexRaw) { $u = $uniqueIndexRaw.Trim().ToLowerInvariant() }
  if ($u -match '\bunique\b') { $opts += "unique" }

  # Deterministic mapping: if explicit length is a single integer and the type is String -> maxlength(N).
  if ($type -eq "String" -and $lenRaw) {
    $t = $lenRaw.Trim()
    if ($t -match '^\d+$') { $opts += ("maxlength(" + $t + ")") }
  }

  if ($validationRaw) {
    $v = $validationRaw.Trim()
    if ($v.Length -gt 0 -and $v -notmatch '^<.*>$') {
      # Accept JDL-like tokens (min/max/minlength/maxlength/pattern).
      $opts += ($v -split '\s+' | Where-Object { $_ -ne "" })
    }
  }

  return $opts
}

function Emit-EntityBlock {
  param(
    [string]$entity,
    [pscustomobject[]]$fields
  )

  $out = @()
  $out += ("entity " + $entity + " {")
  foreach ($f in $fields) {
    $line = "  " + $f.fieldCode + " " + $f.jdlType
    if ($f.options -and $f.options.Count -gt 0) {
      $line += " " + ($f.options -join " ")
    }
    $out += $line
  }
  $out += "}"
  return $out
}

function Canonicalize-Cardinality {
  param([string]$c)
  $t = Require-NonEmpty -what "Cardinality" -v $c
  $t = $t.Trim().ToUpperInvariant()
  $t = $t -replace '\s+', ''
  return $t
}

function Derive-RelationshipBlock {
  param(
    [pscustomobject]$r
  )

  $a = Require-NonEmpty -what "Entity A (EntityCode)" -v $r."Entity A (EntityCode)"
  $b = Require-NonEmpty -what "Entity B (EntityCode)" -v $r."Entity B (EntityCode)"
  $card = Canonicalize-Cardinality -c $r.Cardinality

  if (-not (Is-Valid-Pascal -s $a)) { throw ("Invalid EntityCode for A: " + $a) }
  if (-not (Is-Valid-Pascal -s $b)) { throw ("Invalid EntityCode for B: " + $b) }

  $fieldA = Require-NonEmpty -what "Field On A" -v $r."Field On A"
  $fieldB = Require-NonEmpty -what "Field On B" -v $r."Field On B"

  if (-not (Is-Valid-Camel -s $fieldA)) { throw ("Invalid relationship field on A: " + $a + "." + $fieldA) }
  if (-not (Is-Valid-Camel -s $fieldB)) { throw ("Invalid relationship field on B: " + $b + "." + $fieldB) }

  $bidirectional = Normalize-Bool -s $r.Bidirectional

  # Canonicalize N:1 to 1:N by swapping.
  if ($card -eq "N:1") {
    $tmpE = $a; $a = $b; $b = $tmpE
    $tmpF = $fieldA; $fieldA = $fieldB; $fieldB = $tmpF
    $card = "1:N"
  }

  $kind = ""
  switch ($card) {
    "1:1" { $kind = "OneToOne" }
    "1:N" { $kind = "OneToMany" }
    "N:N" { $kind = "ManyToMany" }
    default { throw ("Unsupported Cardinality: " + $card + " (allowed: 1:1,1:N,N:1,N:N)") }
  }

  $left = $a + "{" + $fieldA + "}"
  $right = $b
  if ($bidirectional) {
    $right = $b + "{" + $fieldB + "}"
  }

  return [pscustomobject]@{
    kind = $kind
    line = ("relationship " + $kind + " { " + $left + " to " + $right + " }")
  }
}

$reqRoot = Join-Path (Get-Location) $RequirementsRoot
if (!(Test-Path $reqRoot)) { throw ("Requirements root not found: " + $reqRoot) }

Ensure-OutDir -p $OutRoot

# Determine which REQs to derive.
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
  Write-Host "No Type=domain-model REQs found to derive."
  exit 0
}

foreach ($tgt in $targets) {
  $mainText = Read-TextFile -path $tgt.main
  $version = Get-FrontMatterLikeField -text $mainText -fields @("Version", $ZH_VERSION)
  $service = Get-FrontMatterLikeField -text $mainText -fields @("Service", $ZH_SERVICE, $ZH_SERVICE_ALT)
  if (-not $service -or $service.Trim().Length -eq 0) { $service = "monolith" }
  $service = $service.Trim()

  $appendixText = Read-TextFile -path $tgt.appendix

  $entitiesTbl = Parse-MarkdownTablesByHeader -text $appendixText -requiredCols @("EntityCode(PascalCase)")
  if ($entitiesTbl.Count -eq 0) {
    # Accept alternate header label used in templates.
    $entitiesTbl = Parse-MarkdownTablesByHeader -text $appendixText -requiredCols @("EntityCode")
  }
  if ($entitiesTbl.Count -eq 0) { throw ("Missing Entities table with EntityCode column in appendix: " + $tgt.appendix) }

  $entities = @()
  foreach ($row in $entitiesTbl[0].rows) {
    $ec = $row."EntityCode(PascalCase)"
    if (-not $ec) { $ec = $row.EntityCode }
    $ec = Require-NonEmpty -what "EntityCode" -v $ec
    if (-not (Is-Valid-Pascal -s $ec)) { throw ("Invalid EntityCode (PascalCase required): " + $ec) }
    $entities += $ec
  }
  $entities = $entities | Select-Object -Unique

  $fieldTbls = Parse-MarkdownTablesByHeader -text $appendixText -requiredCols @("EntityCode", "FieldCode(camelCase)", "Type Candidates (JDL)")
  if ($fieldTbls.Count -eq 0) {
    # Accept alternate header label used in templates.
    $fieldTbls = Parse-MarkdownTablesByHeader -text $appendixText -requiredCols @("EntityCode", "FieldCode", "Type Candidates (JDL)")
  }
  if ($fieldTbls.Count -eq 0) { throw ("Missing Field Dictionary table with EntityCode+FieldCode in appendix: " + $tgt.appendix) }

  $fieldsByEntity = @{}
  foreach ($e in $entities) { $fieldsByEntity[$e] = @() }

  foreach ($tbl in $fieldTbls) {
    foreach ($row in $tbl.rows) {
      $ec = Require-NonEmpty -what "EntityCode" -v $row.EntityCode
      if (-not $fieldsByEntity.ContainsKey($ec)) {
        throw ("Field Dictionary references unknown EntityCode: " + $ec)
      }

      $fc = $row."FieldCode(camelCase)"
      if (-not $fc) { $fc = $row.FieldCode }
      $fc = Require-NonEmpty -what ($ec + ".FieldCode") -v $fc
      if (-not (Is-Valid-Camel -s $fc)) { throw ("Invalid FieldCode (camelCase required): " + $ec + "." + $fc) }

      $jdlType = Pick-JdlType -raw $row."Type Candidates (JDL)"
      $required = Normalize-YesNo -s $row.Required
      $opts = Build-FieldOptions -type $jdlType -required $required -uniqueIndexRaw $row."Unique/Index" -lenRaw $row."Length/Precision/Scale" -validationRaw $row."Validation/Range"

      $fieldsByEntity[$ec] += [pscustomobject]@{
        fieldCode = $fc
        jdlType = $jdlType
        options = $opts
        rawUniqueIndex = $row."Unique/Index"
      }
    }
  }

  $enumTbls = Parse-MarkdownTablesByHeader -text $appendixText -requiredCols @("Enum", "Value")
  $enums = @{}
  foreach ($tbl in $enumTbls) {
    foreach ($row in $tbl.rows) {
      $enumName = Require-NonEmpty -what "Enum" -v $row.Enum
      $val = Require-NonEmpty -what ("Enum " + $enumName + " Value") -v $row.Value
      if (-not $enums.ContainsKey($enumName)) { $enums[$enumName] = @() }
      $enums[$enumName] += $val
    }
  }

  $relTbls = Parse-MarkdownTablesByHeader -text $appendixText -requiredCols @("Entity A (EntityCode)", "Entity B (EntityCode)", "Cardinality", "Field On A", "Field On B")
  $relByKind = @{}
  foreach ($tbl in $relTbls) {
    foreach ($row in $tbl.rows) {
      $rel = Derive-RelationshipBlock -r $row
      if (-not $relByKind.ContainsKey($rel.kind)) { $relByKind[$rel.kind] = @() }
      $relByKind[$rel.kind] += $rel.line
    }
  }

  $outDir = Join-Path $OutRoot $service
  Ensure-OutDir -p $outDir
  $outPath = Join-Path $outDir ($tgt.rid + ".jdl")

  if ((Test-Path $outPath) -and (-not $Force)) {
    Write-Host ("SKIP (exists): " + $outPath)
    continue
  }

  $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $out = @()
  $out += ("// Generated by jdl-derive.ps1 at " + $now)
  $out += ("// Source REQ: " + $tgt.rid + " " + $version)
  $out += ("// Source files: " + (Split-Path -Leaf $tgt.main) + " ; " + (Split-Path -Leaf $tgt.appendix))
  $out += ""

  foreach ($e in $entities) {
    if (-not $fieldsByEntity.ContainsKey($e) -or $fieldsByEntity[$e].Count -eq 0) {
      throw ("Entity has no fields in Field Dictionary: " + $e)
    }
    $out += (Emit-EntityBlock -entity $e -fields $fieldsByEntity[$e])
    $out += ""
  }

  foreach ($enumName in ($enums.Keys | Sort-Object)) {
    $vals = $enums[$enumName] | Select-Object -Unique
    $out += ("enum " + $enumName + " { " + ($vals -join ", ") + " }")
    $out += ""
  }

  foreach ($k in @("OneToOne", "OneToMany", "ManyToMany")) {
    if ($relByKind.ContainsKey($k)) {
      foreach ($line in $relByKind[$k]) { $out += $line }
      $out += ""
    }
  }

  Set-Content -NoNewline -Encoding UTF8 -Path $outPath -Value ($out -join "`n")
  Write-Host ("Wrote JDL: " + $outPath)
}

