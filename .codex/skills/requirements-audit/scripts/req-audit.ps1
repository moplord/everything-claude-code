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
      if ($line -match '^\s*-\s+Q\d+:\s*\S') { return $true }
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

$indexPath = Join-Path $root "INDEX.md"
$indexText = ""
if (Test-Path $indexPath) { $indexText = Get-Content -Raw -Encoding UTF8 $indexPath }

$reqFiles = Get-ReqFiles -root $root
foreach ($f in $reqFiles) {
  $p = $f.FullName
  $t = Get-Content -Raw -Encoding UTF8 $p

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

  # Consumer-facing requirements must not be ambiguous about consumers and model references.
  if ($type -and ($type.Trim() -eq "consumer-feature")) {
    if (Is-PlaceholderOrEmpty -v $scopes) { Add-Issue -Severity "ERROR" -Path $p -Message "Type=consumer-feature requires non-empty 'Scopes:'" }
    if (Is-PlaceholderOrEmpty -v $refs) { Add-Issue -Severity "ERROR" -Path $p -Message "Type=consumer-feature requires non-empty 'References:' (must point to a domain-model REQ + version)" }
    if ($refs -and ($refs -notmatch 'REQ-\d{3}')) { Add-Issue -Severity "WARN" -Path $p -Message "References does not appear to include a REQ-### id" }
    if ($refs -and ($refs -notmatch 'v\d')) { Add-Issue -Severity "WARN" -Path $p -Message "References does not appear to include a version (e.g., v1.2.3)" }
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
    $ax = Get-Content -Raw -Encoding UTF8 $appendixPath
    $axType = Get-FrontMatterLikeField -text $ax -fields @("Type", $ZH_TYPE)

    # Basic appendix structure gates (Type-specific templates).
    if ($axType -and ($axType.Trim() -eq "domain-model")) {
      if ($ax -notmatch '(?m)^##\s+A\.') { Add-Issue -Severity "ERROR" -Path $appendixPath -Message "Appendix missing section A" }
      if ($ax -notmatch '(?m)^##\s+B\.') { Add-Issue -Severity "ERROR" -Path $appendixPath -Message "Appendix missing section B (files/images contract; use N/A if not applicable)" }
      if ($ax -notmatch '(?m)^##\s+D\.') { Add-Issue -Severity "ERROR" -Path $appendixPath -Message "Appendix missing section D (verification/quality contract)" }

      if ($ax -notmatch '(?m)^\|\s*\u5b57\u6bb5\s*\|\s*\u4e1a\u52a1\u542b\u4e49') {
        Add-Issue -Severity "WARN" -Path $appendixPath -Message "Domain-model appendix does not appear to include a Field Dictionary table header"
      }
      if ($ax -notmatch '(?m)^\|\s*\u5173\u7cfb\u540d\s*\|') {
        Add-Issue -Severity "WARN" -Path $appendixPath -Message "Domain-model appendix does not appear to include a Relationships table header"
      }
    } elseif ($axType -and ($axType.Trim() -eq "consumer-feature")) {
      foreach ($sec in @("A","B","C","D","E","F")) {
        if ($ax -notmatch ("(?m)^##\s+" + $sec + "\.")) {
          Add-Issue -Severity "ERROR" -Path $appendixPath -Message ("Appendix missing section " + $sec + " (use N/A rows if not applicable)")
        }
      }

      if ($ax -notmatch '(?m)^\|\s*Scope\s*\|\s*\u5b9e\u4f53\.?\u5b57\u6bb5') {
        Add-Issue -Severity "WARN" -Path $appendixPath -Message "Consumer-feature appendix does not appear to include a Field Projection table header"
      }
      if ($ax -notmatch '(?m)^\|\s*Scope\s*\|\s*\u64cd\u4f5c\s*\|') {
        Add-Issue -Severity "WARN" -Path $appendixPath -Message "Consumer-feature appendix does not appear to include an Interaction/Actions table header"
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
