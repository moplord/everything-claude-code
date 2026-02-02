param(
  [Parameter(Mandatory = $true)]
  [string]$TargetDir,

  # generator-jhipster npm version (used when jhipster is not installed globally)
  [Parameter(Mandatory = $true)]
  [string]$JhipsterVersion,

  # Authentication profile selection:
  # - oidc: external OIDC provider (e.g. Keycloak)
  # - local-jwt: built-in JHipster JWT auth (users/roles in DB)
  [Parameter(Mandatory = $false)]
  [ValidateSet("oidc", "local-jwt")]
  [string]$AuthProfile = "oidc",

  # Either provide AppJdlPath, or let the script generate a minimal app.jdl from the inputs below.
  [Parameter(Mandatory = $false)]
  [string]$AppJdlPath = "",

  [Parameter(Mandatory = $false)]
  [string]$BaseName = "",

  [Parameter(Mandatory = $false)]
  [string]$PackageName = "",

  # Required only when AuthProfile=oidc (and AppJdlPath is not provided).
  [Parameter(Mandatory = $false)]
  [string]$OidcIssuerUri = "",

  [Parameter(Mandatory = $false)]
  [string]$OidcClientId = "",

  # Provide either JdlDir or JdlFiles. JdlFiles is a comma-separated list.
  [Parameter(Mandatory = $false)]
  [string]$JdlDir = "",

  [Parameter(Mandatory = $false)]
  [string]$JdlFiles = "",

  [Parameter(Mandatory = $false)]
  [switch]$SkipInstall,

  [Parameter(Mandatory = $false)]
  [switch]$Force,

  [Parameter(Mandatory = $false)]
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Ensure-Dir {
  param([string]$p)
  if (!(Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function Require-NonEmpty {
  param([string]$value, [string]$name)
  if ([string]::IsNullOrWhiteSpace($value)) { throw ("Missing required input: " + $name) }
}

function Find-JdlFiles {
  param([string]$dir)
  if (!(Test-Path $dir)) { throw ("JdlDir not found: " + $dir) }
  return (Get-ChildItem -Path $dir -Recurse -File | Where-Object { $_.Name -match '\.(jdl|jh)$' } | ForEach-Object { $_.FullName })
}

function Write-AppJdl {
  param(
    [string]$path,
    [string]$baseName,
    [string]$packageName,
    [string]$authProfile,
    [string]$issuerUri,
    [string]$clientId
  )

  $nl = "`n"
  $t = @()
  $t += "// Auto-generated application JDL (baseline: monolith + vue + maven + postgresql)"
  $t += "application {"
  $t += "  config {"
  $t += ("    baseName " + $baseName)
  $t += ("    packageName " + $packageName)
  $t += "    applicationType monolith"
  if ($authProfile -eq "local-jwt") {
    $t += "    authenticationType jwt"
  } else {
    $t += "    authenticationType oauth2"
  }
  $t += "    databaseType sql"
  $t += "    devDatabaseType postgresql"
  $t += "    prodDatabaseType postgresql"
  $t += "    buildTool maven"
  $t += "    clientFramework vue"
  $t += "    enableTranslation false"
  $t += "  }"
  $t += "}"
  if ($authProfile -eq "oidc") {
    $t += ""
    $t += "// OIDC parameters are recorded for humans/automation; provider wiring is applied post-generation."
    $t += ("// issuerUri: " + $issuerUri)
    $t += ("// clientId: " + $clientId)
  }

  Set-Content -NoNewline -Encoding UTF8 -Path $path -Value ($t -join $nl)
}

function Invoke-Jhipster {
  param([string[]]$JhipsterArgs, [string]$version, [switch]$dryRun)

  $cmd = Get-Command jhipster -ErrorAction SilentlyContinue
  if ($cmd) {
    if ($dryRun) {
      Write-Host ("DRYRUN: jhipster " + ($JhipsterArgs -join " "))
      return
    }
    & $cmd.Source @JhipsterArgs
    return
  }

  $npx = Get-Command npx -ErrorAction SilentlyContinue
  if (-not $npx) { throw "Neither 'jhipster' nor 'npx' found in PATH." }

  # Run jhipster from the generator-jhipster package (version-pinned).
  $npxArgs = @("-y", "-p", ("generator-jhipster@" + $version), "jhipster") + $JhipsterArgs
  if ($dryRun) {
    Write-Host ("DRYRUN: npx " + ($npxArgs -join " "))
    return
  }
  & $npx.Source @npxArgs
}

$targetAbs = (Resolve-Path -LiteralPath $TargetDir -ErrorAction SilentlyContinue)
if (-not $targetAbs) {
  Ensure-Dir -p $TargetDir
  $targetAbs = (Resolve-Path -LiteralPath $TargetDir).Path
} else {
  $targetAbs = $targetAbs.Path
}

# Prepare JDL input list
$appInput = ""
$entityInputs = @()

if (-not [string]::IsNullOrWhiteSpace($AppJdlPath)) {
  if (!(Test-Path $AppJdlPath)) { throw ("AppJdlPath not found: " + $AppJdlPath) }
  $appInput = (Resolve-Path -LiteralPath $AppJdlPath).Path
} else {
  Require-NonEmpty -value $BaseName -name "BaseName"
  Require-NonEmpty -value $PackageName -name "PackageName"
  if ($AuthProfile -eq "oidc") {
    Require-NonEmpty -value $OidcIssuerUri -name "OidcIssuerUri"
    Require-NonEmpty -value $OidcClientId -name "OidcClientId"
  }

  $genAppJdl = Join-Path $targetAbs "app.jdl"
  if (-not $DryRun) {
    Write-AppJdl -path $genAppJdl -baseName $BaseName -packageName $PackageName -authProfile $AuthProfile -issuerUri $OidcIssuerUri -clientId $OidcClientId
  } else {
    Write-Host ("DRYRUN: would write app JDL: " + $genAppJdl)
  }
  $appInput = $genAppJdl
}

if (-not [string]::IsNullOrWhiteSpace($JdlFiles)) {
  $items = $JdlFiles -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
  foreach ($p in $items) {
    if (!(Test-Path $p)) { throw ("JDL file not found: " + $p) }
    $entityInputs += (Resolve-Path -LiteralPath $p).Path
  }
} elseif (-not [string]::IsNullOrWhiteSpace($JdlDir)) {
  $entityInputs += (Find-JdlFiles -dir $JdlDir)
} else {
  throw "Provide either -JdlDir or -JdlFiles (entity JDL inputs)."
}

if ([string]::IsNullOrWhiteSpace($appInput)) { throw "Missing app JDL input." }
if ($entityInputs.Count -lt 1) { throw "Need at least one entity JDL input." }

# Ensure stable order for deterministic runs (app first, then sorted entities).
$inputs = @($appInput) + ($entityInputs | Sort-Object)

Push-Location $targetAbs
try {
  $args = @("import-jdl") + $inputs
  $jhipsterArgs = @("import-jdl") + $inputs
  if ($SkipInstall) { $jhipsterArgs += "--skip-install" }
  if ($Force) { $jhipsterArgs += "--force" }

  Invoke-Jhipster -JhipsterArgs $jhipsterArgs -version $JhipsterVersion -dryRun:$DryRun
} finally {
  Pop-Location
}

Write-Host ("DONE: JHipster import-jdl invoked in " + $targetAbs)
