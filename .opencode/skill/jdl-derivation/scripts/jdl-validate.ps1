param(
  [Parameter(Mandatory = $false)]
  [string]$RequirementsRoot = "requirements",

  [Parameter(Mandatory = $false)]
  [string[]]$ReqId = @(),

  [Parameter(Mandatory = $false)]
  [string]$OutRoot = "jdl\\generated"
)

$ErrorActionPreference = "Stop"

# Keep this script ASCII-only for Windows PowerShell compatibility.
$ZH_VERSION = [regex]::Unescape('\u7248\u672c')
$ZH_TYPE = [regex]::Unescape('\u7c7b\u578b')
$ZH_SERVICE = [regex]::Unescape('\u670d\u52a1')
$ZH_SERVICE_ALT = [regex]::Unescape('\u5fae\u670d\u52a1')
$ZH_ENTITY = [regex]::Unescape('\u5b9e\u4f53')
$ZH_ENTITY_CN = [regex]::Unescape('\u5b9e\u4f53(\u4e2d\u6587)')
$ZH_CARDINALITY = [regex]::Unescape('\u57fa\u6570')
$ZH_TYPE_CANDIDATES = [regex]::Unescape('\u7c7b\u578b\u5019\u9009(JDL)')
$ZH_TYPE_CANDIDATES_ALT = [regex]::Unescape('\u7c7b\u578b\u5019\u9009 (JDL)')
$ZH_REQUIRED = [regex]::Unescape('\u5fc5\u586b')
$ZH_UNIQUE_INDEX = [regex]::Unescape('\u552f\u4e00/\u7d22\u5f15')
$ZH_LEN_PREC_SCALE = [regex]::Unescape('\u957f\u5ea6/\u7cbe\u5ea6/Scale')
$ZH_VALIDATION_RANGE = [regex]::Unescape('\u6821\u9a8c/\u8303\u56f4')
$ZH_ENUM_NAME = [regex]::Unescape('\u679a\u4e3e\u540d')
$ZH_VALUE = [regex]::Unescape('\u503c')
$ZH_A_ENTITY = [regex]::Unescape('A \u5b9e\u4f53(EntityCode)')
$ZH_B_ENTITY = [regex]::Unescape('B \u5b9e\u4f53(EntityCode)')
$ZH_A_FIELD = [regex]::Unescape('A \u4fa7\u5b57\u6bb5(FieldCode)')
$ZH_A_FIELD_ALT = [regex]::Unescape('A\u4fa7\u5b57\u6bb5(FieldCode)')
$ZH_B_FIELD = [regex]::Unescape('B \u4fa7\u5b57\u6bb5(FieldCode)')
$ZH_B_FIELD_ALT = [regex]::Unescape('B\u4fa7\u5b57\u6bb5(FieldCode)')
$ZH_BIDIRECTIONAL = [regex]::Unescape('\u662f\u5426\u53cc\u5411')

function Fail {
  param([string]$msg)
  Write-Host ("FAIL: " + $msg)
  exit 2
}

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
  return ""
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

function Split-TableLine {
  param([string]$line)
  $t = $line.Trim()
  if ($t.StartsWith("|")) { $t = $t.Substring(1) }
  if ($t.EndsWith("|")) { $t = $t.Substring(0, $t.Length - 1) }
  $parts = $t -split '\|'
  return @($parts | ForEach-Object { $_.Trim() })
}

function Parse-AllMarkdownTables {
  param([string]$text)
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
      foreach ($k in $colIndex.Keys) { $obj[$k] = $cells[$colIndex[$k]] }
      $rows += [pscustomobject]$obj
      $j++
    }

    $tables += [pscustomobject]@{ header = $hdr; rows = $rows; startLine = $i + 1 }
  }
  return $tables
}

function Table-HasColumnGroups {
  param([string[]]$header, [object[]]$groups)
  foreach ($g in $groups) {
    $ok = $false
    foreach ($name in $g) {
      if ($header -contains $name) { $ok = $true; break }
    }
    if (-not $ok) { return $false }
  }
  return $true
}

function Find-TableByColumnGroups {
  param([pscustomobject[]]$tables, [object[]]$groups)
  foreach ($t in $tables) {
    if (Table-HasColumnGroups -header $t.header -groups $groups) { return $t }
  }
  return $null
}

function Get-Cell {
  param([pscustomobject]$row, [string[]]$names)
  foreach ($n in $names) {
    $prop = $row.PSObject.Properties | Where-Object { $_.Name -eq $n } | Select-Object -First 1
    if ($prop -and $prop.Value -ne $null) {
      $v = $prop.Value.ToString()
      if ($v.Trim().Length -gt 0) { return $v }
    }
  }
  return ""
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
  if ($v -match '[,/]') { throw ("Ambiguous JDL type candidates: '" + $v + "'. Provide exactly one JDL type token.") }
  $m = [regex]::Match($v, '^[A-Za-z][A-Za-z0-9]*')
  if (-not $m.Success) { throw ("Invalid JDL type candidates: '" + $v + "'.") }
  return $m.Value
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
  if ($type -eq "String" -and $lenRaw) {
    $t = $lenRaw.Trim()
    if ($t -match '^\d+$') { $opts += ("maxlength(" + $t + ")") }
  }
  if ($validationRaw) {
    $v = $validationRaw.Trim()
    if ($v.Length -gt 0 -and $v -notmatch '^<.*>$') {
      $opts += ($v -split '\s+' | Where-Object { $_ -ne "" })
    }
  }
  return ($opts | Select-Object -Unique)
}

function Canonicalize-Cardinality {
  param([string]$c)
  $t = Require-NonEmpty -what "Cardinality" -v $c
  $t = $t.Trim().ToUpperInvariant()
  $t = $t -replace '\s+', ''
  return $t
}

function Derive-RelationshipStruct {
  param([pscustomobject]$r)

  $a = Require-NonEmpty -what "Entity A (EntityCode)" -v (Get-Cell -row $r -names @("Entity A (EntityCode)", $ZH_A_ENTITY))
  $b = Require-NonEmpty -what "Entity B (EntityCode)" -v (Get-Cell -row $r -names @("Entity B (EntityCode)", $ZH_B_ENTITY))
  $card = Canonicalize-Cardinality -c (Get-Cell -row $r -names @("Cardinality", $ZH_CARDINALITY))

  $fieldA = Require-NonEmpty -what "Field On A" -v (Get-Cell -row $r -names @("Field On A", $ZH_A_FIELD, $ZH_A_FIELD_ALT))
  $fieldB = Require-NonEmpty -what "Field On B" -v (Get-Cell -row $r -names @("Field On B", $ZH_B_FIELD, $ZH_B_FIELD_ALT))
  $bidirectional = Normalize-Bool -s (Get-Cell -row $r -names @("Bidirectional", $ZH_BIDIRECTIONAL))

  # Canonicalize N:1 to 1:N by swapping sides.
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
    default { throw ("Unsupported Cardinality: " + $card) }
  }

  return [pscustomobject]@{
    kind = $kind
    leftEntity = $a
    leftField = $fieldA
    rightEntity = $b
    rightField = $fieldB
    bidirectional = $bidirectional
  }
}

function Parse-Jdl {
  param([string]$text)

  $entities = @{}
  $enums = @{}
  $rels = @()

  $lines = $text -split "`n"
  $inEntity = $false
  $curEntity = ""

  for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]
    if ($line -match '^\s*//') { continue }
    if (-not $inEntity) {
      if ($line -match '^\s*entity\s+([A-Za-z][A-Za-z0-9]*)\s*\{\s*$') {
        $inEntity = $true
        $curEntity = $Matches[1]
        if ($entities.ContainsKey($curEntity)) { throw ("Duplicate entity in JDL: " + $curEntity) }
        $entities[$curEntity] = @{}
        continue
      }

      # enum NAME { A, B }
      if ($line -match '^\s*enum\s+([A-Za-z][A-Za-z0-9]*)\s*\{\s*(.*?)\s*\}\s*$') {
        $name = $Matches[1]
        $vals = $Matches[2].Trim()
        $arr = @()
        if ($vals.Length -gt 0) {
          $arr = $vals -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        }
        $enums[$name] = ($arr | Select-Object -Unique)
        continue
      }

      # relationship Kind { A{a} to B{b} }
      if ($line -match '^\s*relationship\s+(OneToOne|OneToMany|ManyToMany)\s*\{\s*([A-Za-z][A-Za-z0-9]*)\s*\{\s*([a-z][A-Za-z0-9]*)\s*\}\s*to\s*([A-Za-z][A-Za-z0-9]*)(?:\s*\{\s*([a-z][A-Za-z0-9]*)\s*\})?\s*\}\s*$') {
        $rels += [pscustomobject]@{
          kind = $Matches[1]
          leftEntity = $Matches[2]
          leftField = $Matches[3]
          rightEntity = $Matches[4]
          rightField = $Matches[5]
          bidirectional = ($Matches[5] -ne $null -and $Matches[5].ToString().Trim().Length -gt 0)
        }
        continue
      }

      continue
    }

    # Inside entity block
    if ($line -match '^\s*\}\s*$') {
      $inEntity = $false
      $curEntity = ""
      continue
    }

    $t = $line.Trim()
    if ($t.Length -eq 0) { continue }
    if ($t -match '^//') { continue }

    # fieldName Type [options...]
    $parts = $t -split '\s+' | Where-Object { $_ -ne "" }
    if ($parts.Count -lt 2) { continue }
    $fn = $parts[0]
    $ft = $parts[1]
    $opt = @()
    if ($parts.Count -gt 2) { $opt = $parts[2..($parts.Count - 1)] }

    $entities[$curEntity][$fn] = [pscustomobject]@{
      type = $ft
      options = ($opt | Select-Object -Unique)
    }
  }

  return [pscustomobject]@{
    entities = $entities
    enums = $enums
    relationships = $rels
  }
}

function Compare-Set {
  param([string]$what, [string[]]$expected, [string[]]$actual)
  $e = @($expected | Sort-Object -Unique)
  $a = @($actual | Sort-Object -Unique)
  $missing = @()
  foreach ($x in $e) { if (-not ($a -contains $x)) { $missing += $x } }
  $extra = @()
  foreach ($x in $a) { if (-not ($e -contains $x)) { $extra += $x } }
  if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
    $m = @()
    if ($missing.Count -gt 0) { $m += ("missing: " + ($missing -join ", ")) }
    if ($extra.Count -gt 0) { $m += ("extra: " + ($extra -join ", ")) }
    throw ($what + " mismatch (" + ($m -join "; ") + ")")
  }
}

$reqRoot = Join-Path (Get-Location) $RequirementsRoot
if (!(Test-Path $reqRoot)) { Fail ("Requirements root not found: " + $reqRoot) }
$outAbs = Join-Path (Get-Location) $OutRoot
if (!(Test-Path $outAbs)) { Fail ("OutRoot not found: " + $outAbs) }

$targets = @()
if ($ReqId -and $ReqId.Count -gt 0) {
  foreach ($ridIn in $ReqId) {
    $rid = $ridIn.Trim().ToUpperInvariant()
    if ($rid -notmatch '^REQ-\d{3}$') { Fail ("ReqId must look like REQ-### (got: " + $ridIn + ")") }
    $main = Find-ReqMainFile -root $reqRoot -rid $rid
    if (-not $main) { Fail ("REQ not found: " + $rid) }
    $t = Read-TextFile -path $main
    $type = Get-FrontMatterLikeField -text $t -fields @("Type", $ZH_TYPE)
    if ($type.Trim() -ne "domain-model") { continue }
    $appendix = Find-ReqAppendixFile -root $reqRoot -mainFile $main
    if (-not $appendix) { Fail ("Appendix not found for: " + $main) }
    $targets += [pscustomobject]@{ rid = $rid; main = $main; appendix = $appendix }
  }
} else {
  $files = Get-ChildItem -Path $reqRoot -File -Filter "REQ-*.md" | Where-Object { $_.Name -notlike "*-appendix.md" } | Sort-Object Name
  foreach ($f in $files) {
    $rid = Get-ReqIdFromFileName -name $f.Name
    if (-not $rid) { continue }
    $t = Read-TextFile -path $f.FullName
    $type = Get-FrontMatterLikeField -text $t -fields @("Type", $ZH_TYPE)
    if ($type.Trim() -ne "domain-model") { continue }
    $appendix = Find-ReqAppendixFile -root $reqRoot -mainFile $f.FullName
    if (-not $appendix) { Fail ("Appendix not found for: " + $f.FullName) }
    $targets += [pscustomobject]@{ rid = $rid; main = $f.FullName; appendix = $appendix }
  }
}

if ($targets.Count -eq 0) {
  Write-Host "No Type=domain-model REQs found to validate."
  exit 0
}

foreach ($tgt in $targets) {
  $mainText = Read-TextFile -path $tgt.main
  $service = Get-FrontMatterLikeField -text $mainText -fields @("Service", $ZH_SERVICE, $ZH_SERVICE_ALT)
  if (-not $service -or $service.Trim().Length -eq 0) { $service = "monolith" }
  $service = $service.Trim()

  $jdlPath = Join-Path (Join-Path $outAbs $service) ($tgt.rid + ".jdl")
  if (!(Test-Path $jdlPath)) { Fail ("Missing derived JDL: " + $jdlPath) }

  $axText = Read-TextFile -path $tgt.appendix
  $tables = Parse-AllMarkdownTables -text $axText

  $entitiesTbl = Find-TableByColumnGroups -tables $tables -groups @(
    @("Entity (Display)", $ZH_ENTITY_CN, $ZH_ENTITY),
    @("EntityCode (PascalCase)", "EntityCode(PascalCase)", "EntityCode")
  )
  if (-not $entitiesTbl) { Fail ("Cannot find Entities table in appendix: " + $tgt.appendix) }

  $expectedEntities = @()
  foreach ($row in $entitiesTbl.rows) {
    $ec = Require-NonEmpty -what "EntityCode" -v (Get-Cell -row $row -names @("EntityCode (PascalCase)", "EntityCode(PascalCase)", "EntityCode"))
    $expectedEntities += $ec
  }
  $expectedEntities = $expectedEntities | Select-Object -Unique

  $fieldTbl = Find-TableByColumnGroups -tables $tables -groups @(
    @("EntityCode"),
    @("FieldCode(camelCase)", "FieldCode (camelCase)", "FieldCode"),
    @("Type Candidates (JDL)", $ZH_TYPE_CANDIDATES, $ZH_TYPE_CANDIDATES_ALT)
  )
  if (-not $fieldTbl) { Fail ("Cannot find Field Dictionary table in appendix: " + $tgt.appendix) }

  $expectedFields = @{} # entity -> field -> {type, options}
  foreach ($e in $expectedEntities) { $expectedFields[$e] = @{} }
  foreach ($row in $fieldTbl.rows) {
    $ec = Require-NonEmpty -what "EntityCode" -v (Get-Cell -row $row -names @("EntityCode"))
    if (-not $expectedFields.ContainsKey($ec)) { Fail ("Field Dictionary references unknown EntityCode: " + $ec) }
    $fc = Require-NonEmpty -what ($ec + ".FieldCode") -v (Get-Cell -row $row -names @("FieldCode(camelCase)", "FieldCode (camelCase)", "FieldCode"))
    $typeRaw = Get-Cell -row $row -names @("Type Candidates (JDL)", $ZH_TYPE_CANDIDATES, $ZH_TYPE_CANDIDATES_ALT)
    $jdlType = Pick-JdlType -raw $typeRaw

    $requiredRaw = Get-Cell -row $row -names @("Required", $ZH_REQUIRED)
    $required = Normalize-YesNo -s $requiredRaw
    $uniqueIndexRaw = Get-Cell -row $row -names @("Unique/Index", $ZH_UNIQUE_INDEX)
    $lenRaw = Get-Cell -row $row -names @("Length/Precision/Scale", $ZH_LEN_PREC_SCALE)
    $valRaw = Get-Cell -row $row -names @("Validation/Range", $ZH_VALIDATION_RANGE)
    $opts = Build-FieldOptions -type $jdlType -required $required -uniqueIndexRaw $uniqueIndexRaw -lenRaw $lenRaw -validationRaw $valRaw

    $expectedFields[$ec][$fc] = [pscustomobject]@{ type = $jdlType; options = $opts }
  }

  $enumTbl = Find-TableByColumnGroups -tables $tables -groups @(
    @("Enum", $ZH_ENUM_NAME),
    @("Value", $ZH_VALUE)
  )
  $expectedEnums = @{}
  if ($enumTbl) {
    foreach ($row in $enumTbl.rows) {
      $enumName = Require-NonEmpty -what "Enum" -v (Get-Cell -row $row -names @("Enum", $ZH_ENUM_NAME))
      $val = Require-NonEmpty -what ("Enum " + $enumName + " Value") -v (Get-Cell -row $row -names @("Value", $ZH_VALUE))
      if (-not $expectedEnums.ContainsKey($enumName)) { $expectedEnums[$enumName] = @() }
      $expectedEnums[$enumName] += $val
    }
    foreach ($k in @($expectedEnums.Keys)) { $expectedEnums[$k] = ($expectedEnums[$k] | Select-Object -Unique) }
  }

  $relTbl = Find-TableByColumnGroups -tables $tables -groups @(
    @("Entity A (EntityCode)", $ZH_A_ENTITY),
    @("Entity B (EntityCode)", $ZH_B_ENTITY),
    @("Cardinality", $ZH_CARDINALITY),
    @("Field On A", $ZH_A_FIELD, $ZH_A_FIELD_ALT),
    @("Field On B", $ZH_B_FIELD, $ZH_B_FIELD_ALT)
  )
  $expectedRels = @()
  if ($relTbl) {
    foreach ($row in $relTbl.rows) { $expectedRels += (Derive-RelationshipStruct -r $row) }
  }

  $actual = Parse-Jdl -text (Read-TextFile -path $jdlPath)

  # Entities set must match.
  Compare-Set -what ("Entities for " + $tgt.rid) -expected $expectedEntities -actual @($actual.entities.Keys)

  # Fields must match per entity; type and options must match.
  foreach ($e in $expectedEntities) {
    if (-not $actual.entities.ContainsKey($e)) { throw ("Missing entity in JDL: " + $e) }
    $expFieldNames = @($expectedFields[$e].Keys)
    $actFieldNames = @($actual.entities[$e].Keys)
    Compare-Set -what ("Fields for " + $e) -expected $expFieldNames -actual $actFieldNames

    foreach ($fn in $expFieldNames) {
      $exp = $expectedFields[$e][$fn]
      $act = $actual.entities[$e][$fn]
      if ($act.type -ne $exp.type) {
        throw ("Type mismatch for " + $e + "." + $fn + " expected=" + $exp.type + " actual=" + $act.type)
      }
      Compare-Set -what ("Options for " + $e + "." + $fn) -expected @($exp.options) -actual @($act.options)
    }
  }

  # Enums must match exactly (if any).
  Compare-Set -what ("Enums for " + $tgt.rid) -expected @($expectedEnums.Keys) -actual @($actual.enums.Keys)
  foreach ($ek in @($expectedEnums.Keys)) {
    Compare-Set -what ("Enum values for " + $ek) -expected @($expectedEnums[$ek]) -actual @($actual.enums[$ek])
  }

  # Relationships: compare as canonical structs.
  if ($expectedRels.Count -ne $actual.relationships.Count) {
    throw ("Relationships count mismatch for " + $tgt.rid + " expected=" + $expectedRels.Count + " actual=" + $actual.relationships.Count)
  }
  foreach ($er in $expectedRels) {
    $found = $false
    foreach ($ar in $actual.relationships) {
      if ($ar.kind -ne $er.kind) { continue }
      if ($ar.leftEntity -ne $er.leftEntity) { continue }
      if ($ar.leftField -ne $er.leftField) { continue }
      if ($ar.rightEntity -ne $er.rightEntity) { continue }
      if (($er.bidirectional -eq $true) -and ($ar.bidirectional -ne $true)) { continue }
      if (($er.bidirectional -eq $false) -and ($ar.bidirectional -ne $false)) { continue }
      if ($er.bidirectional -and ($ar.rightField -ne $er.rightField)) { continue }
      $found = $true
      break
    }
    if (-not $found) {
      throw ("Missing relationship in JDL for " + $tgt.rid + ": " + $er.kind + " " + $er.leftEntity + "{" + $er.leftField + "} -> " + $er.rightEntity)
    }
  }

  Write-Host ("PASS: JDL matches domain-model requirements for " + $tgt.rid + " (" + $service + ")")
}

exit 0
