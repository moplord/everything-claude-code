param(
  [Parameter(Mandatory = $false)]
  [string]$RootPath = "requirements",

  [Parameter(Mandatory = $false)]
  [string]$LedgerRelPath = ".audit\\ledger.json"
)

$ErrorActionPreference = "Stop"

# Keep this script ASCII-only for Windows PowerShell compatibility.
$ZH_STATUS = [regex]::Unescape('\u72b6\u6001')
$ZH_VERSION = [regex]::Unescape('\u7248\u672c')
$ZH_LAST_UPDATED = [regex]::Unescape('\u6700\u540e\u66f4\u65b0')
$ZH_UPDATED_AT = [regex]::Unescape('\u66f4\u65b0\u65f6\u95f4')
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

function Get-ReqIdFromFileName {
  param([string]$name)
  $m = [regex]::Match($name, '^REQ-(\d{3})-')
  if (-not $m.Success) { return "" }
  return ("REQ-" + $m.Groups[1].Value)
}

function Get-FrontMatterLikeField {
  param([string]$text, [string[]]$fields)
  $lines = $text -split "`n"

  foreach ($line in $lines) {
    foreach ($field in $fields) {
      $fieldEsc = [regex]::Escape($field)
      $re = '^(?:\uFEFF)?\s*' + $fieldEsc + '\s*[:\uFF1A]\s*(.*)$'
      if ($line -match $re) { return $Matches[1].Trim() }
    }
  }
  return $null
}

function Changelog-HasEntry {
  param([string]$changelogText, [string]$reqId, [string]$version)
  if (-not $changelogText) { return $false }
  if (-not $reqId -or -not $version) { return $false }
  $re = '(?is)' + [regex]::Escape($reqId) + '.{0,300}' + [regex]::Escape($version)
  return [regex]::IsMatch($changelogText, $re)
}

$root = Join-Path (Get-Location) $RootPath
if (!(Test-Path $root)) { throw "RootPath does not exist: $root" }

$changelogPath = Join-Path $root "CHANGELOG.md"
if (!(Test-Path $changelogPath)) { throw "Missing CHANGELOG.md at: $changelogPath" }
$changelogText = Read-TextFile -path $changelogPath

$ledgerPath = Join-Path $root $LedgerRelPath
$ledgerDir = Split-Path -Parent $ledgerPath
if (!(Test-Path $ledgerDir)) { New-Item -ItemType Directory -Force -Path $ledgerDir | Out-Null }

$old = $null
if (Test-Path $ledgerPath) {
  try {
    $old = (Read-TextFile -path $ledgerPath) | ConvertFrom-Json
  } catch {
    throw "ledger.json exists but is not valid JSON: $ledgerPath"
  }
}

$oldEntries = $null
if ($old -and $old.entries) { $oldEntries = $old.entries }

$reqFiles = Get-ChildItem -Path $root -File -Filter "REQ-*.md" | Where-Object { $_.Name -notlike "*-appendix.md" } | Sort-Object Name
$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$errors = @()

function Add-Err { param([string]$m) $script:errors += $m }

function Get-OldEntry {
  param([string]$reqId)
  if (-not $oldEntries) { return $null }
  $prop = $oldEntries.PSObject.Properties | Where-Object { $_.Name -eq $reqId } | Select-Object -First 1
  if ($prop) { return $prop.Value }
  return $null
}

$entries = [ordered]@{}
foreach ($f in $reqFiles) {
  $rid = Get-ReqIdFromFileName -name $f.Name
  if (-not $rid) { continue }

  $reqText = Read-TextFile -path $f.FullName
  $status = Get-FrontMatterLikeField -text $reqText -fields @("Status", $ZH_STATUS)
  $version = Get-FrontMatterLikeField -text $reqText -fields @("Version", $ZH_VERSION)
  $type = Get-FrontMatterLikeField -text $reqText -fields @("Type", $ZH_TYPE)
  $service = Get-FrontMatterLikeField -text $reqText -fields @("Service", $ZH_SERVICE, $ZH_SERVICE_ALT)
  $lastUpdated = Get-FrontMatterLikeField -text $reqText -fields @("Last Updated", $ZH_LAST_UPDATED, $ZH_UPDATED_AT)

  $appendixPath = Join-Path $root (([System.IO.Path]::GetFileNameWithoutExtension($f.Name)) + "-appendix.md")
  $acceptancePath = Join-Path $root ("ACCEPTANCE\\{0}-acceptance.md" -f $rid)

  if (!(Test-Path $appendixPath)) { Add-Err ("Missing appendix for " + $rid + ": " + (Split-Path -Leaf $appendixPath)) }
  if (!(Test-Path $acceptancePath)) { Add-Err ("Missing acceptance checklist for " + $rid + ": " + (Split-Path -Leaf $acceptancePath)) }

  $reqSha = (Get-FileHash -Algorithm SHA256 -Path $f.FullName).Hash.ToLowerInvariant()
  $axSha = ""
  if (Test-Path $appendixPath) { $axSha = (Get-FileHash -Algorithm SHA256 -Path $appendixPath).Hash.ToLowerInvariant() }
  $accSha = ""
  if (Test-Path $acceptancePath) { $accSha = (Get-FileHash -Algorithm SHA256 -Path $acceptancePath).Hash.ToLowerInvariant() }

  $oldEntry = Get-OldEntry -reqId $rid
  if ($oldEntry) {
    $changed = $false
    if ($oldEntry.reqSha256 -and ($oldEntry.reqSha256.ToString().ToLowerInvariant() -ne $reqSha)) { $changed = $true }
    if ($oldEntry.appendixSha256 -and ($oldEntry.appendixSha256.ToString().ToLowerInvariant() -ne $axSha)) { $changed = $true }
    if ($oldEntry.acceptanceSha256 -and ($oldEntry.acceptanceSha256.ToString().ToLowerInvariant() -ne $accSha)) { $changed = $true }

    if ($changed) {
      if ($oldEntry.version -and ($oldEntry.version.ToString() -eq $version)) {
        Add-Err ("REQ content changed but Version not bumped: " + $rid + " (" + $version + ")")
      }
      if (-not (Changelog-HasEntry -changelogText $changelogText -reqId $rid -version $version)) {
        Add-Err ("REQ changed but CHANGELOG.md missing entry for " + $rid + " " + $version)
      }
      if ($oldEntry.lastUpdated -and ($oldEntry.lastUpdated.ToString() -eq $lastUpdated)) {
        Add-Err ("REQ changed but Last Updated not updated: " + $rid)
      }
    }
  } else {
    # New REQ: if it is already non-DRAFT, require changelog entry.
    if ($status -and ($status.Trim().ToUpperInvariant() -notlike "DRAFT*")) {
      if (-not (Changelog-HasEntry -changelogText $changelogText -reqId $rid -version $version)) {
        Add-Err ("New non-DRAFT REQ missing CHANGELOG.md entry: " + $rid + " " + $version)
      }
    }
  }

  $entries[$rid] = [ordered]@{
    id = $rid
    file = $f.Name
    appendixFile = (Split-Path -Leaf $appendixPath)
    acceptanceFile = (Split-Path -Leaf $acceptancePath)
    status = $status
    type = $type
    service = $service
    version = $version
    lastUpdated = $lastUpdated
    reqSha256 = $reqSha
    appendixSha256 = $axSha
    acceptanceSha256 = $accSha
  }
}

# If a REQ existed in the old ledger but is now missing, treat as an error (prefer DEPRECATED over deletion).
if ($oldEntries) {
  foreach ($p in $oldEntries.PSObject.Properties) {
    $rid = $p.Name
    if (-not $entries.Contains($rid)) {
      Add-Err ("REQ present in old ledger but missing from workspace: " + $rid + " (do not delete; mark as DEPRECATED instead)")
    }
  }
}

if ($errors.Count -gt 0) {
  Write-Host "FAIL: cannot update ledger due to errors"
  $errors | ForEach-Object { Write-Host ("- " + $_) }
  exit 2
}

$doc = [ordered]@{
  schema = 1
  generatedAt = $now
  entries = $entries
}

$json = $doc | ConvertTo-Json -Depth 10
Set-Content -NoNewline -Encoding UTF8 -Path $ledgerPath -Value $json
Write-Host ("Wrote ledger: " + $ledgerPath)
