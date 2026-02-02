param(
  [Parameter(Mandatory = $false)]
  [string]$Modules = "storage-s3-compatible,cache-redis,quality-sonarqube,jobs-spring-scheduler"
)

$ErrorActionPreference = "Stop"

function Assert {
  param([bool]$Cond, [string]$Msg)
  if (-not $Cond) { throw $Msg }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$apply = Join-Path $scriptDir "modules-apply.ps1"
$list = Join-Path $scriptDir "modules-list.ps1"

$tmp = Join-Path $env:TEMP ("module-pack-selftest-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

try {
  # Minimal fake JHipster-like repo layout
  New-Item -ItemType Directory -Force -Path (Join-Path $tmp "src\\main\\resources\\config") | Out-Null
  Set-Content -NoNewline -Encoding UTF8 -Path (Join-Path $tmp "src\\main\\resources\\config\\application.yml") -Value "jhipster:`n  clientApp:`n    name: test`n"

  # Minimal pom.xml with dependencies section (namespaced).
  $pom = @()
  $pom += '<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">'
  $pom += "  <modelVersion>4.0.0</modelVersion>"
  $pom += "  <groupId>com.example</groupId>"
  $pom += "  <artifactId>demo</artifactId>"
  $pom += "  <version>0.0.1-SNAPSHOT</version>"
  $pom += "  <dependencies>"
  $pom += "  </dependencies>"
  $pom += "</project>"
  Set-Content -NoNewline -Encoding UTF8 -Path (Join-Path $tmp "pom.xml") -Value ($pom -join "`n")

  & powershell -NoProfile -ExecutionPolicy Bypass -File $list | Out-Host

  & powershell -NoProfile -ExecutionPolicy Bypass -File $apply -TargetDir $tmp -Modules $Modules | Out-Host
  Assert ($LASTEXITCODE -eq 0) "modules-apply failed"

  # Re-apply must be idempotent.
  & powershell -NoProfile -ExecutionPolicy Bypass -File $apply -TargetDir $tmp -Modules $Modules | Out-Host
  Assert ($LASTEXITCODE -eq 0) "modules-apply second run failed"

  # Ensure codex config file exists and contains multiple module markers.
  $codexYaml = Join-Path $tmp "src\\main\\resources\\config\\application-codex.yml"
  Assert (Test-Path $codexYaml) "Missing application-codex.yml"
  $t = Get-Content -Raw -Encoding UTF8 $codexYaml
  Assert ($t -like "*# BEGIN CODEX MODULE storage-s3-compatible*") "Missing marker for storage-s3-compatible"
  Assert ($t -like "*# BEGIN CODEX MODULE cache-redis*") "Missing marker for cache-redis"

  # Verify sonar file copied
  Assert (Test-Path (Join-Path $tmp "sonar-project.properties")) "Missing sonar-project.properties"

  Write-Host "PASS: module-pack selftest"
} finally {
  Remove-Item -Recurse -Force $tmp
}
