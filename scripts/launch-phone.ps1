# FutBolia — launch on connected Android phone
# Usage:
#   .\scripts\launch-phone.ps1              → API Render (défaut app)
#   .\scripts\launch-phone.ps1 -Local       → API LAN (PC NestJS)
#   $env:FUTBOLIA_API_BASE_URL = "https://..." ; .\scripts\launch-phone.ps1
param(
  [switch]$Local,
  [switch]$Remote
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$project = Join-Path $repoRoot "apps\mobile"
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
  Write-Host "Ajoute Flutter au PATH, ou definis FUTBOLIA_FLUTTER (chemin vers flutter.bat)."
  Read-Host "Entree pour fermer"
  exit 1
}

if (-not (Test-Path $project)) {
  Write-Host "[ERREUR] Projet mobile introuvable : $project" -ForegroundColor Red
  Read-Host "Entree pour fermer"
  exit 1
}

Set-Location $project

Write-Host ""
Write-Host "========================================"
Write-Host " FUTBOLIA - lancement telephone"
Write-Host "========================================"

if ($env:FUTBOLIA_API_BASE_URL) {
  $apiBaseUrl = $env:FUTBOLIA_API_BASE_URL.TrimEnd('/')
  if ($apiBaseUrl -notmatch '/api/v1$') {
    $apiBaseUrl = "$apiBaseUrl/api/v1"
  }
} elseif ($Local) {
  # Detect LAN IP (prefer 192.168.x)
  $ip = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -like '192.168.*' -and $_.PrefixOrigin -ne 'WellKnown' } |
    Select-Object -First 1 -ExpandProperty IPAddress

  if (-not $ip) {
    $ip = Get-NetIPAddress -AddressFamily IPv4 |
      Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
      Select-Object -First 1 -ExpandProperty IPAddress
  }

  if (-not $ip) {
    Write-Host "[ERREUR] Impossible de detecter l'IP Wi-Fi du PC." -ForegroundColor Red
    Read-Host "Entree pour fermer"
    exit 1
  }

  $apiBaseUrl = "http://${ip}:3000/api/v1"
} else {
  # Default + -Remote: online Render API
  $apiBaseUrl = $renderApiDefault
}

Write-Host " API : $apiBaseUrl"

# Detect Android device (first physical/android device)
$devicesOutput = & $flutter devices --machine 2>$null | Out-String
$deviceId = $null
try {
  $devices = $devicesOutput | ConvertFrom-Json
  $android = $devices | Where-Object { $_.targetPlatform -like 'android*' -and $_.id -ne 'windows' } | Select-Object -First 1
  if ($android) { $deviceId = $android.id }
} catch {
  # Fallback: parse text list
  $line = (& $flutter devices) | Where-Object { $_ -match '•\s+(\S+)\s+•\s+android-' } | Select-Object -First 1
  if ($line -match '•\s+(\S+)\s+•\s+android-') { $deviceId = $Matches[1] }
}

if (-not $deviceId) {
  Write-Host "[ERREUR] Aucun telephone Android detecte." -ForegroundColor Red
  Write-Host "Branche le USB, active le debogage USB, accepte l'empreinte PC."
  & $flutter devices
  Read-Host "Entree pour fermer"
  exit 1
}

Write-Host " Device : $deviceId"
Write-Host "----------------------------------------"
Write-Host " Build en cours..."
Write-Host "========================================"
Write-Host ""

& $flutter pub get
if ($LASTEXITCODE -ne 0) {
  Write-Host "[ERREUR] flutter pub get a echoue." -ForegroundColor Red
  Read-Host "Entree pour fermer"
  exit 1
}

& $flutter run -d $deviceId --dart-define="API_BASE_URL=$apiBaseUrl"
$code = $LASTEXITCODE

Write-Host ""
Write-Host "Session terminee (code $code)."
Read-Host "Entree pour fermer"
exit $code
