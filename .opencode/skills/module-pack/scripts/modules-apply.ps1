param(
  [Parameter(Mandatory = $true)]
  [string]$TargetDir,

  [Parameter(Mandatory = $true)]
  [string]$Modules,

  [Parameter(Mandatory = $false)]
  [string]$ModulesRoot = "",

  [Parameter(Mandatory = $false)]
  [switch]$Force
)

$ErrorActionPreference = "Stop"

function Ensure-Dir {
  param([string]$p)
  if (!(Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function Read-TextFileUtf8 {
  param([string]$path)
  return (Get-Content -Raw -Encoding UTF8 $path)
}

function Write-TextFileUtf8 {
  param([string]$path, [string]$text)
  Set-Content -NoNewline -Encoding UTF8 -Path $path -Value $text
}

function Copy-Tree {
  param([string]$fromDir, [string]$toDir)
  if (!(Test-Path $fromDir)) { return }
  $files = Get-ChildItem -Path $fromDir -File -Recurse
  foreach ($f in $files) {
    $rel = $f.FullName.Substring($fromDir.Length).TrimStart('\','/')
    $dest = Join-Path $toDir $rel
    $destDir = Split-Path -Parent $dest
    Ensure-Dir -p $destDir
    if ((Test-Path $dest) -and (-not $Force)) { continue }
    Copy-Item -Force -Path $f.FullName -Destination $dest
  }
}

function Ensure-YamlImportForCodex {
  param([string]$targetConfigDir)

  $appYaml = Join-Path $targetConfigDir "application.yml"
  if (!(Test-Path $appYaml)) { return }
  $t = Read-TextFileUtf8 -path $appYaml

  # Ensure the app imports config/application-codex.yml via spring.config.import.
  if ($t -match '(?im)^\s*spring\s*:\s*$' -and $t -match '(?im)^\s*spring\s*:\s*(?:\r?\n)+\s*config\s*:\s*(?:\r?\n)+\s*import\s*:') {
    return
  }

  if ($t -match '(?im)^\s*spring\s*:\s*$') {
    # Insert under existing spring: (best-effort: add config/import immediately after first spring:).
    $lines = $t -split "`n"
    $out = @()
    $inserted = $false
    for ($i = 0; $i -lt $lines.Length; $i++) {
      $out += $lines[$i]
      if (-not $inserted -and $lines[$i] -match '^\s*spring\s*:\s*$') {
        $out += "  config:"
        $out += "    import: optional:classpath:config/application-codex.yml"
        $inserted = $true
      }
    }
    Write-TextFileUtf8 -path $appYaml -text ($out -join "`n")
    return
  }

  # No spring: root -> append at end.
  $t2 = $t.TrimEnd() + "`n`n" + "spring:" + "`n" + "  config:" + "`n" + "    import: optional:classpath:config/application-codex.yml" + "`n"
  Write-TextFileUtf8 -path $appYaml -text $t2
}

function Ensure-CodexConfigFile {
  param([string]$targetConfigDir)
  Ensure-Dir -p $targetConfigDir
  $codexYaml = Join-Path $targetConfigDir "application-codex.yml"
  if (!(Test-Path $codexYaml)) {
    Write-TextFileUtf8 -path $codexYaml -text "# Codex module config (generated)\n"
  }
  return $codexYaml
}

function Append-BlockIfMissing {
  param(
    [string]$path,
    [string]$marker,
    [string]$blockText
  )
  $t = ""
  if (Test-Path $path) { $t = Read-TextFileUtf8 -path $path }
  if ($t -like ("*" + $marker + "*")) { return }
  $newText = $t.TrimEnd() + "`n`n" + $marker + "`n" + $blockText.TrimEnd() + "`n" + ("# END " + $marker.TrimStart('#').Trim()) + "`n"
  Write-TextFileUtf8 -path $path -text $newText
}

function Add-MavenDependencies {
  param(
    [string]$pomPath,
    [pscustomobject[]]$deps
  )
  if (!(Test-Path $pomPath)) { throw ("pom.xml not found: " + $pomPath) }
  [xml]$xml = Get-Content -Raw -Encoding UTF8 $pomPath

  $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
  $ns.AddNamespace("m", $xml.DocumentElement.NamespaceURI) | Out-Null

  $depsNode = $xml.SelectSingleNode("//m:project/m:dependencies", $ns)
  if (-not $depsNode) { throw "Cannot find <dependencies> in pom.xml" }

  foreach ($d in $deps) {
    $gid = $d.groupId
    $aid = $d.artifactId
    $ver = $d.version
    $scope = $d.scope

    $exists = $xml.SelectSingleNode("//m:dependency[m:groupId='" + $gid + "' and m:artifactId='" + $aid + "']", $ns)
    if ($exists) { continue }

    $dep = $xml.CreateElement("dependency", $xml.DocumentElement.NamespaceURI)
    $g = $xml.CreateElement("groupId", $xml.DocumentElement.NamespaceURI); $g.InnerText = $gid; $dep.AppendChild($g) | Out-Null
    $a = $xml.CreateElement("artifactId", $xml.DocumentElement.NamespaceURI); $a.InnerText = $aid; $dep.AppendChild($a) | Out-Null
    if ($ver -and $ver.Trim().Length -gt 0) {
      $v = $xml.CreateElement("version", $xml.DocumentElement.NamespaceURI); $v.InnerText = $ver; $dep.AppendChild($v) | Out-Null
    }
    if ($scope -and $scope.Trim().Length -gt 0) {
      $s = $xml.CreateElement("scope", $xml.DocumentElement.NamespaceURI); $s.InnerText = $scope; $dep.AppendChild($s) | Out-Null
    }
    $depsNode.AppendChild($dep) | Out-Null
  }

  $xml.Save($pomPath)
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ModulesRoot -or $ModulesRoot.Trim().Length -eq 0) {
  $ModulesRoot = Join-Path $scriptDir "..\\assets\\modules"
}
$ModulesRoot = (Resolve-Path $ModulesRoot).Path

$targetAbs = (Resolve-Path $TargetDir -ErrorAction SilentlyContinue)
if (-not $targetAbs) { throw ("TargetDir not found: " + $TargetDir) }
$targetAbs = $targetAbs.Path

$mods = $Modules.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
if ($mods.Count -eq 0) { throw "No modules specified" }

$configDir = Join-Path $targetAbs "src\\main\\resources\\config"
Ensure-Dir -p $configDir
Ensure-YamlImportForCodex -targetConfigDir $configDir
$codexYaml = Ensure-CodexConfigFile -targetConfigDir $configDir

$pomPath = Join-Path $targetAbs "pom.xml"

foreach ($m in $mods) {
  $mDir = Join-Path $ModulesRoot $m
  if (!(Test-Path $mDir)) { throw ("Unknown module: " + $m + " (missing dir " + $mDir + ")") }

  $manifestPath = Join-Path $mDir "manifest.json"
  if (!(Test-Path $manifestPath)) { throw ("Missing manifest.json for module: " + $m) }
  $manifest = Get-Content -Raw -Encoding UTF8 $manifestPath | ConvertFrom-Json

  Write-Host ("Applying module: " + $m)

  # 1) Copy templates (new files)
  $templatesDir = Join-Path $mDir "templates"
  Copy-Tree -fromDir $templatesDir -toDir $targetAbs

  # 2) Patch pom.xml deps (safe, idempotent)
  if ($manifest.mavenDependencies) {
    $deps = @()
    foreach ($d in $manifest.mavenDependencies) {
      $deps += [pscustomobject]@{
        groupId = $d.groupId
        artifactId = $d.artifactId
        version = $d.version
        scope = $d.scope
      }
    }
    if ($deps.Count -gt 0) {
      Add-MavenDependencies -pomPath $pomPath -deps $deps
    }
  }

  # 3) Append config blocks into application-codex.yml (safe, idempotent)
  $cfgPath = Join-Path $mDir "patches\\application-codex.yml"
  if (Test-Path $cfgPath) {
    $marker = "# BEGIN CODEX MODULE " + $m
    $block = Read-TextFileUtf8 -path $cfgPath
    Append-BlockIfMissing -path $codexYaml -marker $marker -blockText $block
  }

  # 4) Optional module verify script (not executed automatically here).
  $verify = Join-Path $mDir "verify.ps1"
  if (Test-Path $verify) {
    Write-Host ("Module verify available: " + $verify)
  }
}

Write-Host "DONE: modules applied"
