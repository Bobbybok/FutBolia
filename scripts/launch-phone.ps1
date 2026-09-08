# FutBolia — launch on connected Android phone
$ErrorActionPreference = "Stop"

$project = "D:\Logiciels\Developpement App Partouche\FutBolia\apps\mobile"
$flutter = "D:\Logiciels\flutter\bin\flutter.bat"

Set-Location $project

Write-Host ""
Write-Host "========================================"
Write-Host " FUTBOLIA - lancement telephone"
Write-Host "========================================"

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
Write-Host " Build Phase 2 (auth) en cours..."
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
