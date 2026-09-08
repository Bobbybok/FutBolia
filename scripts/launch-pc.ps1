# FutBolia — preview in the browser on this PC (hot reload)
# Usage:
#   .\scripts\launch-pc.ps1           → UI locale http://localhost:8080 + API Render
#   .\scripts\launch-pc.ps1 -Local    → UI locale + API NestJS http://localhost:3000
param(
  [switch]$Local
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$project = Join-Path $repoRoot "apps\mobile"
$webPort = 8080
$localUrl = "http://localhost:$webPort"
$renderApiDefault = "https://futbolia-api.onrender.com/api/v1"

function Resolve-Flutter {
  if ($env:FUTBOLIA_FLUTTER -and (Test-Path $env:FUTBOLIA_FLUTTER)) {
    return $env:FUTBOLIA_FLUTTER
  }

  $fromPath = Get-Command flutter.bat -ErrorAction SilentlyContinue
  if (-not $fromPath) {
    $fromPath = Get-Command flutter -ErrorAction SilentlyContinue
  }
  if ($fromPath) {
    return $fromPath.Source
  }

  $fromHome = Join-Path $env:USERPROFILE "flutter\bin\flutter.bat"
  if (Test-Path $fromHome) {
    return $fromHome
  }

  $legacy = "D:\Logiciels\flutter\bin\flutter.bat"
  if (Test-Path $legacy) {
    return $legacy
  }

  return $null
}

$flutter = Resolve-Flutter
if (-not $flutter) {
  Write-Host "[ERREUR] Flutter introuvable." -ForegroundColor Red
  Read-Host "Entree pour fermer"
  exit 1
}

if (-not (Test-Path $project)) {
  Write-Host "[ERREUR] Projet mobile introuvable : $project" -ForegroundColor Red
  Read-Host "Entree pour fermer"
  exit 1
}

Set-Location $project

if ($env:FUTBOLIA_API_BASE_URL) {
  $apiBaseUrl = $env:FUTBOLIA_API_BASE_URL.TrimEnd('/')
  if ($apiBaseUrl -notmatch '/api/v1$') {
    $apiBaseUrl = "$apiBaseUrl/api/v1"
  }
} elseif ($Local) {
  $apiBaseUrl = "http://localhost:3000/api/v1"
} else {
  $apiBaseUrl = $renderApiDefault
}

Write-Host ""
Write-Host "========================================"
Write-Host " FUTBOLIA - apercu PC (web)"
Write-Host "========================================"
Write-Host " Chrome / Edge / Firefox / Opera : $localUrl"
Write-Host " API        : $apiBaseUrl"
Write-Host "----------------------------------------"
Write-Host ""

& $flutter pub get
if ($LASTEXITCODE -ne 0) {
  Write-Host "[ERREUR] flutter pub get a echoue." -ForegroundColor Red
  Read-Host "Entree pour fermer"
  exit 1
}

# Open the default browser once the server is listening (any browser can use the same URL).
Start-Job -ScriptBlock {
  param($port, $url)
  for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 2
    try {
      $client = New-Object System.Net.Sockets.TcpClient
      $client.Connect('127.0.0.1', $port)
      $client.Close()
      Start-Process $url
      return
    } catch {
      # still compiling
    }
  }
} -ArgumentList $webPort, $localUrl | Out-Null

& $flutter run -d web-server --web-hostname localhost --web-port $webPort --dart-define="API_BASE_URL=$apiBaseUrl"
$code = $LASTEXITCODE

Write-Host ""
Write-Host "Session terminee (code $code)."
Read-Host "Entree pour fermer"
exit $code
