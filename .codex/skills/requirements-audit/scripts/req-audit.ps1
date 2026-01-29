param(
  [Parameter(Mandatory = $false)]
  [string]$RootPath = "requirements"
)

$ErrorActionPreference = "Stop"

# Keep this script ASCII-only so it runs reliably under Windows PowerShell (which can
# mis-detect UTF-8 script encoding without a BOM). Use Regex.Unescape for zh labels.
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
$ZH_NON_GOALS = [regex]::Unescape('\u975e\u76ee\u6807')
$ZH_ACCEPTANCE = [regex]::Unescape('\u9a8c\u6536\u6807\u51c6')

function Count-ReplacementChar {
  param([string]$s)
  if (-not $s) { return 0 }
  return ([regex]::Matches($s, [string][char]0xFFFD)).Count
}

function Read-TextFile {
  param([string]$path)

  # Read bytes and decode deterministically.
  # - Supports UTF-8 (with/without BOM), UTF-16 LE/BE (BOM).
  # - Falls back to GBK (CP936) if UTF-8 decoding produces replacement chars.
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

function Add-Issue {
  param(
    [string]$Severity, # ERROR | WARN
    [string]$Path,
    [string]$Message
  )
  $script:issues += [pscustomobject]@{
    severity = $Severity
    path = $Path
    message = $Message
  }
}

function Require-File {
  param([string]$p)
  if (!(Test-Path $p)) {
    Add-Issue -Severity "ERROR" -Path $p -Message "Missing required file"
    return $false
  }
  return $true
}

function Get-ReqFiles {
  param([string]$root)
  if (!(Test-Path $root)) { return @() }
  # Only audit "main" REQ files here; appendices are validated via the main REQ.
  return Get-ChildItem -Path $root -File -Filter "REQ-*.md" `
    | Where-Object { $_.Name -notlike "*-appendix.md" } `
    | Sort-Object Name
}

function Contains-SectionHeader {
  param(
    [string]$text,
    [string]$header
  )
  # match markdown header like: "## 4. Non-Goals" or "### Non-Goals"
  $re = "(?m)^#{2,6}\s+.*" + [regex]::Escape($header) + ".*$"
  return [regex]::IsMatch($text, $re)
}

function Contains-SectionNumberHeader {
  param(
    [string]$text,
    [string]$number
  )
  # match markdown header like: "## 4." or "## 12."
  $re = "(?m)^#{2,6}\s+" + [regex]::Escape($number) + "\."
  return [regex]::IsMatch($text, $re)
}

function Get-FrontMatterLikeField {
  param([string]$text, [string[]]$fields)
  $lines = $text -split "`n"

  # 1) Plain "Key: Value" lines (supports ASCII ":" and full-width colon U+FF1A).
  foreach ($line in $lines) {
    foreach ($field in $fields) {
      $fieldEsc = [regex]::Escape($field)
      # Allow empty values so we can distinguish "missing line" (null) vs "present but empty" ("").
      $re = '^(?:\uFEFF)?\s*' + $fieldEsc + '\s*[:\uFF1A]\s*(.*)$'
      if ($line -match $re) {
        return $Matches[1].Trim()
      }
    }
  }

  # 2) Simple Markdown tables like: "| Version | v0.1.0 |"
  foreach ($line in $lines) {
    if ($line -notmatch '^\s*\|') { continue }
    $cols = $line.Trim() -split '\|'
    if ($cols.Count -lt 3) { continue }
    $k = $cols[1].Trim()
    $v = $cols[2].Trim()
    foreach ($field in $fields) {
      if ($k -eq $field) {
        return $v
      }
    }
  }

  return $null
}

function Has-OpenQuestions {
  param([string]$text)
  $inOpenQuestions = $false
  $lines = $text -split "`n"
  foreach ($line in $lines) {
    if ($line -match '^(#{2,6}\s+.*(Open Questions|\u5f85\u786e\u8ba4\u95ee\u9898|\u5f00\u653e\u95ee\u9898))') { $inOpenQuestions = $true; continue }
    if ($inOpenQuestions -and ($line -match '^#{2,6}\s+')) { $inOpenQuestions = $false }
    if ($inOpenQuestions) {
      if ($line -match '^\s*-\s+Q\d+[:\uFF1A]\s*\S') { return $true }
      if ($line -match '^\s*-\s+\u95ee\u9898\d*[:\uFF1A]\s*\S') { return $true }
    }
  }
  return $false
}

function Contains-AnyHeader {
  param(
    [string]$text,
    [string[]]$keywords
  )
  foreach ($k in $keywords) {
    $re = "(?m)^#{2,6}\s+.*" + [regex]::Escape($k) + ".*$"
    if ([regex]::IsMatch($text, $re)) { return $true }
  }
  return $false
}

function Is-PlaceholderOrEmpty {
  param([string]$v)
  if (-not $v) { return $true }
  $t = $v.Trim()
  if ($t.Length -eq 0) { return $true }
  if ($t -match '^<.*>$') { return $true }
  return $false
}

function Check-Ambiguous-AcLanguage {
  param([string]$path, [string]$text)
  $badWords = @(
    "fast", "quick", "scalable", "secure", "robust", "user friendly", "easy",
    "best effort", "asap", "efficient", "high performance"
  )

  $lines = $text -split "`n"
  foreach ($line in $lines) {
    if ($line -match '^\s*-\s+AC\d+:') {
      $lc = $line.ToLowerInvariant()
      foreach ($w in $badWords) {
        if ($lc -like ("*" + $w + "*")) {
          # If the line does not contain any digit, it's likely missing a measurable constraint.
          if ($line -notmatch "\\d") {
            Add-Issue -Severity "WARN" -Path $path -Message ("Acceptance criteria contains ambiguous word '" + $w + "' without an explicit metric: " + $line.Trim())
          }
        }
      }
    }
  }
}

$script:issues = @()
$root = Join-Path (Get-Location) $RootPath

if (!(Test-Path $root)) {
  Add-Issue -Severity "ERROR" -Path $root -Message "Requirements root folder does not exist"
}

# Baseline files
Require-File (Join-Path $root "README.md") | Out-Null
Require-File (Join-Path $root "INDEX.md") | Out-Null
Require-File (Join-Path $root "CHANGELOG.md") | Out-Null
Require-File (Join-Path $root "templates\\REQ-TEMPLATE.md") | Out-Null
Require-File (Join-Path $root "templates\\ADR-TEMPLATE.md") | Out-Null
Require-File (Join-Path $root "templates\\ACCEPTANCE-TEMPLATE.md") | Out-Null
Require-File (Join-Path $root "templates\\APPENDIX-DOMAIN-TEMPLATE.md") | Out-Null
Require-File (Join-Path $root "templates\\APPENDIX-CONSUMER-TEMPLATE.md") | Out-Null
Require-File (Join-Path $root "templates\\APPENDIX-GENERIC-TEMPLATE.md") | Out-Null
Require-File (Join-Path $root "templates\\APPENDIX-CROSS-SERVICE-TEMPLATE.md") | Out-Null

$indexPath = Join-Path $root "INDEX.md"
$indexText = ""
if (Test-Path $indexPath) { $indexText = Read-TextFile -path $indexPath }
if ($indexText -and ($indexText -notlike "*Generated by req-index.ps1*")) {
  Add-Issue -Severity "WARN" -Path $indexPath -Message "INDEX.md does not appear to be generated (missing marker: 'Generated by req-index.ps1'). Consider generating via req-index.ps1."
}

$ledgerPath = Join-Path $root ".audit\\ledger.json"

$reqFiles = Get-ReqFiles -root $root

function Get-ReqIdFromFileName {
  param([string]$name)
  $m = [regex]::Match($name, '^REQ-(\d{3})-')
  if (-not $m.Success) { return "" }
  return ("REQ-" + $m.Groups[1].Value)
}

function Extract-ReqIdsFromText {
  param([string]$s)
  $ids = @()
  if (-not $s) { return $ids }
  foreach ($m in [regex]::Matches($s, 'REQ-\d{3}')) {
    $ids += $m.Value
  }
  return ($ids | Select-Object -Unique)
}

function Parse-References {
  param([string]$s)
  $out = @()
  if (-not $s) { return $out }
  $matches = [regex]::Matches($s, 'REQ-\d{3}')
  foreach ($m in $matches) {
    $rid = $m.Value
    $tail = $s.Substring($m.Index)
    if ($tail.Length -gt 60) { $tail = $tail.Substring(0, 60) }
    $vm = [regex]::Match($tail, 'v\d+\.\d+\.\d+')
    $ver = ""
    if ($vm.Success) { $ver = $vm.Value }
    $out += [pscustomobject]@{ id = $rid; version = $ver }
  }

  # De-duplicate by id (keep the first version we saw).
  $uniq = @()
  $seen = @{}
  foreach ($r in $out) {
    if (-not $seen.ContainsKey($r.id)) {
      $seen[$r.id] = $true
      $uniq += $r
    }
  }
  return $uniq
}

function Get-AcIds {
  param([string]$text)
  $acs = @()
  if (-not $text) { return $acs }
  foreach ($m in [regex]::Matches($text, '(?m)^\s*-\s*AC(\d+)\s*[:\uFF1A]')) {
    $acs += ("AC" + $m.Groups[1].Value)
  }
  return ($acs | Select-Object -Unique)
}

function Status-IsDraft {
  param([string]$s)
  if (-not $s) { return $true }
  return ($s.Trim().ToUpperInvariant() -like "DRAFT*")
}

# Pre-scan: build a lookup map for cross-file validations (references, parent cycles, service consistency).
$reqById = @{}
foreach ($f in $reqFiles) {
  $rid = Get-ReqIdFromFileName -name $f.Name
  if (-not $rid) { continue }
  $txt = Read-TextFile -path $f.FullName
  $reqById[$rid] = [pscustomobject]@{
    id = $rid
    path = $f.FullName
    name = $f.Name
    status = (Get-FrontMatterLikeField -text $txt -fields @("Status", $ZH_STATUS))
    version = (Get-FrontMatterLikeField -text $txt -fields @("Version", $ZH_VERSION))
    type = (Get-FrontMatterLikeField -text $txt -fields @("Type", $ZH_TYPE))
    service = (Get-FrontMatterLikeField -text $txt -fields @("Service", $ZH_SERVICE, $ZH_SERVICE_ALT))
    parent = (Get-FrontMatterLikeField -text $txt -fields @("Parent", $ZH_PARENT, $ZH_PARENT_ALT))
  }
}

$microserviceMode = $false
foreach ($id in $reqById.Keys) {
  $svc = $reqById[$id].service
  if ($svc -and ($svc.Trim().Length -gt 0)) {
    $v = $svc.Trim().ToLowerInvariant()
    if (($v -ne "monolith") -and ($v -ne "cross-service")) { $microserviceMode = $true }
  }
}

# Parent cycle detection (best-effort). We treat any cycle as a hard error.
foreach ($id in $reqById.Keys) {
  $seen = @{}
  $chain = @()
  $cur = $id
  while ($true) {
    if ($seen.ContainsKey($cur)) {
      $chain += $cur
      Add-Issue -Severity "ERROR" -Path $reqById[$id].path -Message ("Parent cycle detected: " + ($chain -join " -> "))
      break
    }
    $seen[$cur] = $true
    $chain += $cur
    $p = $reqById[$cur].parent
    if (-not $p) { break }
    if ($p -notmatch 'REQ-\d{3}') { break }
    $next = $Matches[0]
    if (-not $reqById.ContainsKey($next)) { break }
    $cur = $next
  }
}

if ((Test-Path $ledgerPath) -eq $false) {
  if ($reqById.Keys.Count -gt 0) {
    Add-Issue -Severity "ERROR" -Path $ledgerPath -Message "Missing ledger.json. Run req-ledger.ps1 to create/update the ledger."
  }
}

$ledger = $null
if (Test-Path $ledgerPath) {
  try {
    $ledger = (Read-TextFile -path $ledgerPath) | ConvertFrom-Json
  } catch {
    Add-Issue -Severity "ERROR" -Path $ledgerPath -Message "Failed to parse ledger.json (invalid JSON)"
    $ledger = $null
  }
}

foreach ($f in $reqFiles) {
  $p = $f.FullName
  $t = Read-TextFile -path $p
  $rid = Get-ReqIdFromFileName -name $f.Name

  # Guardrail: REQ must not contain generator syntax or CI YAML (requirements-level only).
  if ($t -match '(?im)^\s*```(yaml|yml)\s*$') {
    Add-Issue -Severity "ERROR" -Path $p -Message "REQ contains YAML code fence. Keep requirements generator-agnostic."
  }
  if ($t -match '(?im)\bentity\b\s+\w+\s*\{|\bapplication\b\s*\{|\bstages\s*:\b|\bscript\s*:\b') {
    Add-Issue -Severity "ERROR" -Path $p -Message "REQ contains implementation/generator syntax (JDL/CI YAML). Keep it requirements-level."
  }
  if ($t -match '(?im)\b(table_name|column_name)\b') {
    Add-Issue -Severity "WARN" -Path $p -Message "REQ appears to include physical naming (table_name/column_name). Prefer concept identifiers (EntityCode/FieldCode) in requirements."
  }

  $status = Get-FrontMatterLikeField -text $t -fields @("Status", $ZH_STATUS)
  $version = Get-FrontMatterLikeField -text $t -fields @("Version", $ZH_VERSION)
  $owner = Get-FrontMatterLikeField -text $t -fields @("Owner", $ZH_OWNER)
  $updated = Get-FrontMatterLikeField -text $t -fields @("Last Updated", $ZH_LAST_UPDATED, $ZH_UPDATED_AT)

  $type = Get-FrontMatterLikeField -text $t -fields @("Type", $ZH_TYPE)
  $level = Get-FrontMatterLikeField -text $t -fields @("Level", $ZH_LEVEL)
  $parent = Get-FrontMatterLikeField -text $t -fields @("Parent", $ZH_PARENT, $ZH_PARENT_ALT)
  $scopes = Get-FrontMatterLikeField -text $t -fields @("Scopes", $ZH_SCOPES, $ZH_SCOPES_ALT)
  $refs = Get-FrontMatterLikeField -text $t -fields @("References", $ZH_REFERENCES, $ZH_REFERENCES_ALT)
  $service = Get-FrontMatterLikeField -text $t -fields @("Service", $ZH_SERVICE, $ZH_SERVICE_ALT)

  if (!$status) { Add-Issue -Severity "ERROR" -Path $p -Message "Missing 'Status:' line" }
  if (!$version) { Add-Issue -Severity "ERROR" -Path $p -Message "Missing 'Version:' line" }
  if (!$owner) { Add-Issue -Severity "ERROR" -Path $p -Message "Missing 'Owner:' line" }
  if (!$updated) { Add-Issue -Severity "ERROR" -Path $p -Message "Missing 'Last Updated:' line" }

  if (!$type) { Add-Issue -Severity "ERROR" -Path $p -Message "Missing 'Type:' line" }
  if (!$level) { Add-Issue -Severity "ERROR" -Path $p -Message "Missing 'Level:' line" }
  if ($null -eq $parent) { Add-Issue -Severity "ERROR" -Path $p -Message "Missing 'Parent:' line (may be empty, but must exist)" }
  if ($null -eq $scopes) { Add-Issue -Severity "ERROR" -Path $p -Message "Missing 'Scopes:' line (may be empty for some types, but must exist)" }
  if ($null -eq $refs) { Add-Issue -Severity "ERROR" -Path $p -Message "Missing 'References:' line (may be empty for some types, but must exist)" }
  if ($null -eq $service) { Add-Issue -Severity "ERROR" -Path $p -Message "Missing 'Service:' line (may be empty, but must exist)" }

  $hasNonGoals = Contains-AnyHeader -text $t -keywords @("Non-Goals", $ZH_NON_GOALS)
  if (-not $hasNonGoals) {
    Add-Issue -Severity "ERROR" -Path $p -Message "Missing 'Non-Goals' section"
  }
  $hasAcceptance = Contains-AnyHeader -text $t -keywords @("Acceptance Criteria", $ZH_ACCEPTANCE)
  if (-not $hasAcceptance) {
    Add-Issue -Severity "ERROR" -Path $p -Message "Missing 'Acceptance Criteria' section"
  }

  $acIds = Get-AcIds -text $t

  # Acceptance checklist is required (1:1 with ACs).
  if ($rid) {
    $acceptancePath = Join-Path $root ("ACCEPTANCE\\{0}-acceptance.md" -f $rid)
    if (!(Test-Path $acceptancePath)) {
      Add-Issue -Severity "ERROR" -Path $p -Message ("Missing acceptance checklist: " + (Split-Path -Leaf $acceptancePath))
    } else {
      $accText = Read-TextFile -path $acceptancePath
      foreach ($ac in $acIds) {
        # Allow either checklist form "- [ ] AC1:" or plain bullet "- AC1:".
        if ($accText -notmatch ("(?im)^\s*-\s*(\[[ xX]\]\s*)?" + [regex]::Escape($ac) + "\b")) {
          Add-Issue -Severity "ERROR" -Path $acceptancePath -Message ("Acceptance checklist missing item for " + $ac)
        }
      }
    }
  }

  # Consumer-facing requirements must not be ambiguous about consumers and model references.
  if ($type -and ($type.Trim() -eq "consumer-feature")) {
    if (Is-PlaceholderOrEmpty -v $scopes) { Add-Issue -Severity "ERROR" -Path $p -Message "Type=consumer-feature requires non-empty 'Scopes:'" }
    if (Is-PlaceholderOrEmpty -v $refs) { Add-Issue -Severity "ERROR" -Path $p -Message "Type=consumer-feature requires non-empty 'References:' (must point to a domain-model REQ + version)" }
    if ($refs -and ($refs -notmatch 'REQ-\d{3}')) { Add-Issue -Severity "WARN" -Path $p -Message "References does not appear to include a REQ-### id" }
    if ($refs -and ($refs -notmatch 'v\d')) { Add-Issue -Severity "WARN" -Path $p -Message "References does not appear to include a version (e.g., v1.2.3)" }
  }

  # Strong reference validation: referenced REQs must exist; if a version is stated, it must match.
  $refObjs = Parse-References -s $refs
  $refDomainModels = @()
  foreach ($r in $refObjs) {
    if (-not $reqById.ContainsKey($r.id)) {
      Add-Issue -Severity "ERROR" -Path $p -Message ("References " + $r.id + " but no matching REQ file exists in requirements root")
      continue
    }
    $rt = $reqById[$r.id].type
    if ($rt -and ($rt.Trim() -eq "domain-model")) { $refDomainModels += $r.id }

    if ($r.version -and ($r.version.Trim().Length -gt 0)) {
      $actual = $reqById[$r.id].version
      if ($actual -and ($actual.Trim() -ne $r.version.Trim())) {
        Add-Issue -Severity "ERROR" -Path $p -Message ("References " + $r.id + " at " + $r.version + " but the current Version is " + $actual)
      }
    }
  }

  if ($type -and ($type.Trim() -eq "consumer-feature")) {
    if ($refDomainModels.Count -lt 1) {
      Add-Issue -Severity "ERROR" -Path $p -Message "Type=consumer-feature must reference at least one Type=domain-model REQ in References:"
    }
    foreach ($dm in $refDomainModels) {
      $ro = $refObjs | Where-Object { $_.id -eq $dm } | Select-Object -First 1
      if ($ro -and (-not $ro.version -or $ro.version.Trim().Length -eq 0)) {
        Add-Issue -Severity "ERROR" -Path $p -Message ("Type=consumer-feature must pin a version for domain-model reference: " + $dm + " (e.g., " + $dm + " (v1.2.3))")
      }
    }
  }

  # Optional microservice enforcement: if any REQ uses a non-monolith Service, enforce consistency.
  if ($microserviceMode) {
    if (Is-PlaceholderOrEmpty -v $service) {
      Add-Issue -Severity "ERROR" -Path $p -Message "Microservice mode detected but 'Service:' is empty. Set Service: monolith|<service-name>|cross-service."
    }
  }
  if ($type -and ($type.Trim() -eq "cross-service-contract")) {
    if ($service -and ($service.Trim().ToLowerInvariant() -ne "cross-service")) {
      Add-Issue -Severity "ERROR" -Path $p -Message "Type=cross-service-contract requires Service: cross-service"
    }
  }
  if ($type -and ($type.Trim() -eq "consumer-feature") -and ($refDomainModels.Count -eq 1) -and ($service)) {
    $dmId = $refDomainModels[0]
    $dmSvc = $reqById[$dmId].service
    if ($dmSvc -and ($dmSvc.Trim().Length -gt 0)) {
      $sv = $service.Trim().ToLowerInvariant()
      $dv = $dmSvc.Trim().ToLowerInvariant()
      if (($sv -ne "cross-service") -and ($dv -ne "cross-service") -and ($sv -ne $dv)) {
        Add-Issue -Severity "ERROR" -Path $p -Message ("Service mismatch: consumer-feature Service=" + $service + " but referenced domain-model " + $dmId + " Service=" + $dmSvc)
      }
    }
  }

  # Parent validation (best-effort): if Parent references REQ-###, ensure a matching file exists.
  if ($parent -and ($parent -match 'REQ-\d{3}')) {
    $parentReqId = $Matches[0]
    $parentMatch = Get-ChildItem -Path $root -File -Filter "$parentReqId-*.md" | Where-Object { $_.Name -notlike '*-appendix.md' } | Select-Object -First 1
    if (-not $parentMatch) {
      Add-Issue -Severity "ERROR" -Path $p -Message ("Parent references " + $parentReqId + " but no matching REQ file exists in requirements root")
    }
  }

  # Appendix file is required (dual-file authoritative spec).
  $appendixName = [System.IO.Path]::GetFileNameWithoutExtension($f.Name) + "-appendix.md"
  $appendixPath = Join-Path $root $appendixName
  if (!(Test-Path $appendixPath)) {
    Add-Issue -Severity "ERROR" -Path $p -Message ("Missing appendix file: " + $appendixName)
  } else {
    $ax = Read-TextFile -path $appendixPath
    $axType = Get-FrontMatterLikeField -text $ax -fields @("Type", $ZH_TYPE)

    if ($ax -match '(?im)^\s*```(yaml|yml)\s*$') {
      Add-Issue -Severity "ERROR" -Path $appendixPath -Message "Appendix contains YAML code fence. Keep requirements generator-agnostic."
    }
    if ($ax -match '(?im)\b(table_name|column_name)\b') {
      Add-Issue -Severity "WARN" -Path $appendixPath -Message "Appendix appears to include physical naming (table_name/column_name). Prefer concept identifiers (EntityCode/FieldCode) in requirements."
    }

    # Basic appendix structure gates (Type-specific templates).
    if ($axType -and ($axType.Trim() -eq "domain-model")) {
      if ($ax -notmatch '(?m)^##\s+A\.') { Add-Issue -Severity "ERROR" -Path $appendixPath -Message "Appendix missing section A" }
      if ($ax -notmatch '(?m)^##\s+B\.') { Add-Issue -Severity "ERROR" -Path $appendixPath -Message "Appendix missing section B (files/images contract; use N/A if not applicable)" }
      if ($ax -notmatch '(?m)^##\s+D\.') { Add-Issue -Severity "ERROR" -Path $appendixPath -Message "Appendix missing section D (verification/quality contract)" }

      # Require presence of concept code identifiers: EntityCode / FieldCode.
      if (($ax -notmatch '(?m)^\|\s*Entity\b.*\|\s*EntityCode\b') -and ($ax -notmatch '(?m)^\|\s*\u5b9e\u4f53.*\|\s*EntityCode\b')) {
        Add-Issue -Severity "WARN" -Path $appendixPath -Message "Domain-model appendix does not appear to include an Entities table with EntityCode column"
      }
      if (($ax -notmatch '(?m)^\|\s*Field\b.*\|\s*FieldCode\b') -and ($ax -notmatch '(?m)^\|\s*\u5b57\u6bb5.*\|\s*FieldCode\b')) {
        Add-Issue -Severity "WARN" -Path $appendixPath -Message "Domain-model appendix does not appear to include a Field Dictionary table header"
      }
      if (($ax -notmatch '(?m)^\|\s*Name\s*\|\s*Entity A\b.*\|\s*Entity B\b.*\|') -and ($ax -notmatch '(?m)^\|\s*\u5173\u7cfb\u540d\s*\|')) {
        Add-Issue -Severity "WARN" -Path $appendixPath -Message "Domain-model appendix does not appear to include a Relationships table header"
      }
    } elseif ($axType -and ($axType.Trim() -eq "consumer-feature")) {
      foreach ($sec in @("A","B","C","D","E","F")) {
        if ($ax -notmatch ("(?m)^##\s+" + $sec + "\.")) {
          Add-Issue -Severity "ERROR" -Path $appendixPath -Message ("Appendix missing section " + $sec + " (use N/A rows if not applicable)")
        }
      }

      if ($ax -notmatch '(?m)^\|\s*Scope\s*\|\s*EntityCode\.FieldCode') {
        Add-Issue -Severity "WARN" -Path $appendixPath -Message "Consumer-feature appendix does not appear to include a Field Projection table header"
      }
      if (($ax -notmatch '(?m)^\|\s*Scope\s*\|\s*Action\s*\|') -and ($ax -notmatch '(?m)^\|\s*Scope\s*\|\s*\u64cd\u4f5c\s*\|')) {
        Add-Issue -Severity "WARN" -Path $appendixPath -Message "Consumer-feature appendix does not appear to include an Interaction/Actions table header"
      }

      # Guardrail: consumer-feature appendix must NOT redefine domain model (types/relationships/enums).
      if ($ax -match '(?m)^\|\s*Field\b.*\|\s*FieldCode\b.*\|\s*Meaning\b.*\|\s*Type Candidates') {
        Add-Issue -Severity "ERROR" -Path $appendixPath -Message "consumer-feature appendix appears to include a domain-model Field Dictionary table header. Domain model must live only in Type=domain-model."
      }
      if ($ax -match '(?m)^\|\s*\u5b57\u6bb5.*\|\s*FieldCode.*\|\s*\u4e1a\u52a1\u542b\u4e49.*\|\s*\u7c7b\u578b\u5019\u9009') {
        Add-Issue -Severity "ERROR" -Path $appendixPath -Message "consumer-feature appendix appears to include a domain-model Field Dictionary table header. Domain model must live only in Type=domain-model."
      }
    } elseif ($axType -and ($axType.Trim() -eq "cross-service-contract")) {
      foreach ($sec in @("A","B","C","D","E","F","G","H","I")) {
        if ($ax -notmatch ("(?m)^##\s+" + $sec + "\.")) {
          Add-Issue -Severity "ERROR" -Path $appendixPath -Message ("Appendix missing section " + $sec + " (use N/A rows if not applicable)")
        }
      }
    } else {
      # Generic appendix: at minimum require a verifiable quality/verification section.
      if ($ax -notmatch '(?m)^##\s+[A-Z]\.') {
        Add-Issue -Severity "WARN" -Path $appendixPath -Message "Appendix does not appear to include any structured sections"
      }
    }

    # Require key tables/sections in appendix to prevent "guessing" later.
    # Guardrail: appendix must not contain generator syntax or CI YAML keys.
    if ($ax -match '(?im)\bentity\b\s*\{|\bapplication\b\s*\{|\bstages\s*:\b|\bscript\s*:\b') {
      Add-Issue -Severity "ERROR" -Path $appendixPath -Message "Appendix contains implementation/generator syntax (JDL/CI YAML). Keep it requirements-level."
    }

    # AC -> test -> evidence traceability: every AC in the REQ should appear in the appendix tables.
    foreach ($ac in $acIds) {
      if ($ax -notmatch ("(?im)^\|\s*" + [regex]::Escape($ac) + "\s*\|")) {
        if ($status -and (-not (Status-IsDraft -s $status))) {
          Add-Issue -Severity "ERROR" -Path $appendixPath -Message ("Appendix missing traceability row for " + $ac)
        } else {
          Add-Issue -Severity "WARN" -Path $appendixPath -Message ("Appendix appears to be missing traceability row for " + $ac)
        }
      }
    }
  }

  # Ledger match (deterministic): if ledger exists, it must match file hashes (prevents untracked drift).
  if ($ledger -and $rid) {
    $entries = $ledger.entries
    $entry = $null
    if ($entries) {
      $prop = $entries.PSObject.Properties | Where-Object { $_.Name -eq $rid } | Select-Object -First 1
      if ($prop) { $entry = $prop.Value }
    }

    if (-not $entry) {
      Add-Issue -Severity "ERROR" -Path $ledgerPath -Message ("Ledger missing entry for REQ: " + $rid + ". Run req-ledger.ps1.")
    } else {
      $reqHash = (Get-FileHash -Algorithm SHA256 -Path $p).Hash.ToLowerInvariant()
      $axHash = ""
      if (Test-Path $appendixPath) { $axHash = (Get-FileHash -Algorithm SHA256 -Path $appendixPath).Hash.ToLowerInvariant() }
      $accPath = Join-Path $root ("ACCEPTANCE\\{0}-acceptance.md" -f $rid)
      $accHash = ""
      if (Test-Path $accPath) { $accHash = (Get-FileHash -Algorithm SHA256 -Path $accPath).Hash.ToLowerInvariant() }

      if ($entry.reqSha256 -and ($reqHash -ne ($entry.reqSha256.ToString().ToLowerInvariant()))) {
        Add-Issue -Severity "ERROR" -Path $ledgerPath -Message ("Ledger mismatch for " + $rid + " (REQ). Run req-ledger.ps1.")
      }
      if ($entry.appendixSha256 -and ($axHash -ne ($entry.appendixSha256.ToString().ToLowerInvariant()))) {
        Add-Issue -Severity "ERROR" -Path $ledgerPath -Message ("Ledger mismatch for " + $rid + " (appendix). Run req-ledger.ps1.")
      }
      if ($entry.acceptanceSha256 -and ($accHash -ne ($entry.acceptanceSha256.ToString().ToLowerInvariant()))) {
        Add-Issue -Severity "ERROR" -Path $ledgerPath -Message ("Ledger mismatch for " + $rid + " (acceptance checklist). Run req-ledger.ps1.")
      }
    }
  }

  # Approved must have no open questions.
  if ($status -and ($status.ToUpperInvariant() -like "APPROVED*")) {
    foreach ($kv in @(
      @{ k = "Status"; v = $status },
      @{ k = "Version"; v = $version },
      @{ k = "Owner"; v = $owner },
      @{ k = "Last Updated"; v = $updated },
      @{ k = "Type"; v = $type },
      @{ k = "Level"; v = $level }
    )) {
      if (Is-PlaceholderOrEmpty -v $kv.v) {
        Add-Issue -Severity "ERROR" -Path $p -Message ("Status=APPROVED but '" + $kv.k + "' is empty or still a placeholder")
      }
    }

    if (Has-OpenQuestions -text $t) {
      Add-Issue -Severity "ERROR" -Path $p -Message "Status is APPROVED but Open Questions still contains unresolved items"
    }
  }

  # Warn on ambiguous AC language
  Check-Ambiguous-AcLanguage -path $p -text $t

  # Index coverage
  if ($indexText) {
    $m = [regex]::Match($f.Name, '^REQ-(\d{3})-')
    if (-not $m.Success) {
      Add-Issue -Severity "WARN" -Path $p -Message "REQ filename does not match expected pattern REQ-###-<slug>.md"
    } else {
      $rid = ("REQ-" + $m.Groups[1].Value)
      if ($indexText -notlike ("*" + $rid + "*")) {
        Add-Issue -Severity "WARN" -Path $p -Message ("REQ id not referenced in INDEX.md: " + $rid)
      }
    }
  }
}

Write-Host "Requirements audit root: $root"
Write-Host ""

if ($script:issues.Count -eq 0) {
  Write-Host "PASS: no issues found"
  exit 0
}

$errors = $script:issues | Where-Object { $_.severity -eq "ERROR" }
$warns = $script:issues | Where-Object { $_.severity -eq "WARN" }

if ($errors.Count -gt 0) {
  Write-Host ("ERRORS: " + $errors.Count)
  $errors | ForEach-Object { Write-Host ("- [" + $_.severity + "] " + $_.path + " :: " + $_.message) }
  Write-Host ""
}
if ($warns.Count -gt 0) {
  Write-Host ("WARNINGS: " + $warns.Count)
  $warns | ForEach-Object { Write-Host ("- [" + $_.severity + "] " + $_.path + " :: " + $_.message) }
  Write-Host ""
}

if ($errors.Count -gt 0) { exit 2 }
exit 0
