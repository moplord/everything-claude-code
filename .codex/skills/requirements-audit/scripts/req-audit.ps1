param(
  [Parameter(Mandatory = $false)]
  [string]$RootPath = "requirements"
)

$ErrorActionPreference = "Stop"

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
  return Get-ChildItem -Path $root -File -Filter "REQ-*.md" | Sort-Object Name
}

function Contains-SectionHeader {
  param(
    [string]$text,
    [string]$header
  )
  # match markdown header like: "## 4. Non-Goals" or "## Non-Goals"
  $re = "(?m)^##\\s+.*" + [regex]::Escape($header) + ".*$"
  return [regex]::IsMatch($text, $re)
}

function Contains-SectionNumberHeader {
  param(
    [string]$text,
    [string]$number
  )
  # match markdown header like: "## 4." or "## 12."
  $re = "(?m)^##\\s+" + [regex]::Escape($number) + "\\."
  return [regex]::IsMatch($text, $re)
}

function Get-FrontMatterLikeField {
  param([string]$text, [string[]]$fields)
  $lines = $text -split "`n"
  foreach ($line in $lines) {
    foreach ($field in $fields) {
      $fieldEsc = [regex]::Escape($field)
      $re = '^(?:\uFEFF)?\s*' + $fieldEsc + '\s*[:\uFF1A]\s*(.+)$'
      if ($line -match $re) {
        return $Matches[1].Trim()
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
    if ($line -match "^(##\\s+.*Open Questions)") { $inOpenQuestions = $true; continue }
    if ($inOpenQuestions -and ($line -match "^##\\s+")) { $inOpenQuestions = $false }
    if ($inOpenQuestions) {
      if ($line -match "^\\s*-\\s+Q\\d+:\\s*\\S") { return $true }
    }
  }
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
    if ($line -match "^\\s*-\\s+AC\\d+:") {
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

$indexPath = Join-Path $root "INDEX.md"
$indexText = ""
if (Test-Path $indexPath) { $indexText = Get-Content -Raw -Encoding UTF8 $indexPath }

$reqFiles = Get-ReqFiles -root $root
foreach ($f in $reqFiles) {
  $p = $f.FullName
  $t = Get-Content -Raw -Encoding UTF8 $p

  $status = Get-FrontMatterLikeField -text $t -fields @("Status", "\u72b6\u6001")
  $version = Get-FrontMatterLikeField -text $t -fields @("Version", "\u7248\u672c")
  $owner = Get-FrontMatterLikeField -text $t -fields @("Owner", "\u8d1f\u8d23\u4eba")
  $updated = Get-FrontMatterLikeField -text $t -fields @("Last Updated", "\u6700\u540e\u66f4\u65b0")

  if (!$status) { Add-Issue -Severity "ERROR" -Path $p -Message "Missing 'Status:' line" }
  if (!$version) { Add-Issue -Severity "ERROR" -Path $p -Message "Missing 'Version:' line" }
  if (!$owner) { Add-Issue -Severity "ERROR" -Path $p -Message "Missing 'Owner:' line" }
  if (!$updated) { Add-Issue -Severity "ERROR" -Path $p -Message "Missing 'Last Updated:' line" }

  $hasNonGoals = ($t -match '(?m)^##\s+4\.') `
    -or ($t -match '(?m)^##\s+.*Non-Goals') `
    -or ($t -match '(?m)^##\s+.*\u975e\u76ee\u6807')
  if (-not $hasNonGoals) {
    Add-Issue -Severity "ERROR" -Path $p -Message "Missing 'Non-Goals' section"
  }
  $hasAcceptance = ($t -match '(?m)^##\s+12\.') `
    -or ($t -match '(?m)^##\s+.*Acceptance Criteria') `
    -or ($t -match '(?m)^##\s+.*\u9a8c\u6536\u6807\u51c6')
  if (-not $hasAcceptance) {
    Add-Issue -Severity "ERROR" -Path $p -Message "Missing 'Acceptance Criteria' section"
  }

  # Approved must have no open questions.
  if ($status -and ($status.ToUpperInvariant() -like "APPROVED*")) {
    if (Has-OpenQuestions -text $t) {
      Add-Issue -Severity "ERROR" -Path $p -Message "Status is APPROVED but Open Questions still contains unresolved items"
    }
  }

  # Warn on ambiguous AC language
  Check-Ambiguous-AcLanguage -path $p -text $t

  # Index coverage
  if ($indexText -and ($f.Name -notmatch "^REQ-(\\d{3})-")) {
    Add-Issue -Severity "WARN" -Path $p -Message "REQ filename does not match expected pattern REQ-###-<slug>.md"
  } else {
    if ($indexText -and ($indexText -notlike ("*" + $f.Name + "*"))) {
      Add-Issue -Severity "WARN" -Path $p -Message "REQ file not referenced in INDEX.md"
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
