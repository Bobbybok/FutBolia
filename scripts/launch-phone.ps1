# FutBolia — launch on connected Android phone
# Usage:
#   .\scripts\launch-phone.ps1              → API Render, install Wi‑Fi si possible
#   .\scripts\launch-phone.ps1 -Local       → API LAN (PC NestJS)
#   .\scripts\launch-phone.ps1 -Usb         → forcer le cable
#   .\scripts\launch-phone.ps1 -PhoneIp 192.168.1.20
#   $env:FUTBOLIA_API_BASE_URL = "https://..." ; .\scripts\launch-phone.ps1
param(
  [switch]$Local,
  [switch]$Remote,
  [switch]$Usb,
  [string]$PhoneIp,
  [int]$AdbPort = 5555
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

function Resolve-Adb {
  if ($env:FUTBOLIA_ADB -and (Test-Path $env:FUTBOLIA_ADB)) {
    return $env:FUTBOLIA_ADB
  }

  $sdkRoots = @(
    $env:ANDROID_HOME,
    $env:ANDROID_SDK_ROOT,
    (Join-Path $env:LOCALAPPDATA "Android\Sdk")
  ) | Where-Object { $_ }

  foreach ($root in $sdkRoots) {
    $candidate = Join-Path $root "platform-tools\adb.exe"
    if (Test-Path $candidate) {
      return $candidate
    }
  }

  $fromPath = Get-Command adb.exe -ErrorAction SilentlyContinue
  if ($fromPath) {
    return $fromPath.Source
  }

  return $null
}

function Get-AdbSerials([string]$adb) {
  $serials = @()
  $lines = & $adb devices 2>$null
  foreach ($line in $lines) {
    if ($line -match '^(\S+)\s+device(\s|$)') {
      $serials += $Matches[1]
    }
  }
  return $serials
}

function Get-PhoneWlanIp([string]$adb, [string]$serial) {
  $text = (& $adb -s $serial shell "ip -f inet addr show" 2>$null | Out-String)
  if ($text -match 'wlan\d*[\s\S]*?inet\s+(\d+\.\d+\.\d+\.\d+)') {
    return $Matches[1]
  }
  if ($text -match 'inet\s+(192\.168\.\d+\.\d+)') {
    return $Matches[1]
  }
  if ($text -match 'inet\s+(10\.\d+\.\d+\.\d+)') {
    return $Matches[1]
  }
  $prop = ((& $adb -s $serial shell getprop dhcp.wlan0.ipaddress 2>$null) | Out-String).Trim()
  if ($prop -match '^\d+\.\d+\.\d+\.\d+$') {
    return $prop
  }
  return $null
}

function Connect-PhoneOverWifi([string]$adb, [string]$ip, [int]$port) {
  $target = "${ip}:${port}"
  Write-Host " ADB Wi-Fi : connexion $target ..."
  $out = & $adb connect $target 2>&1 | Out-String
  Write-Host $out.Trim()
  Start-Sleep -Seconds 1
  $serials = Get-AdbSerials $adb
  if ($serials -contains $target) {
    return $target
  }
  return $null
}

function Enable-PhoneWifiAdb([string]$adb, [int]$port, [string]$forcedIp) {
  if ($forcedIp) {
    return Connect-PhoneOverWifi $adb $forcedIp $port
  }

  $serials = Get-AdbSerials $adb
  $existingWifi = $serials | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+:\d+$' } | Select-Object -First 1
  if ($existingWifi) {
    Write-Host " ADB Wi-Fi deja connecte : $existingWifi"
    return $existingWifi
  }

  $usb = $serials | Where-Object { $_ -notmatch ':' } | Select-Object -First 1
  if (-not $usb) {
    return $null
  }

  Write-Host " Passage USB → Wi-Fi (port $port)..."
  $phoneIp = Get-PhoneWlanIp $adb $usb
  if (-not $phoneIp) {
    Write-Host "[INFO] IP Wi-Fi du telephone introuvable. On reste en USB." -ForegroundColor Yellow
    return $null
  }

  & $adb -s $usb tcpip $port | Out-Host
  Start-Sleep -Seconds 2

  return Connect-PhoneOverWifi $adb $phoneIp $port
}

function Resolve-FlutterAndroidId([string]$flutterBin, [string]$preferId) {
  $devicesOutput = & $flutterBin devices --machine 2>$null | Out-String
  try {
    $devices = $devicesOutput | ConvertFrom-Json
    $android = @($devices | Where-Object {
      $_.targetPlatform -like 'android*' -and $_.id -ne 'windows'
    })
    if ($preferId) {
      $match = $android | Where-Object { $_.id -eq $preferId } | Select-Object -First 1
      if ($match) { return $match.id }
    }
    $wifi = $android | Where-Object { $_.id -match '^\d+\.\d+\.\d+\.\d+:' } | Select-Object -First 1
    if ($wifi) { return $wifi.id }
    if ($android.Count -gt 0) { return $android[0].id }
  } catch {
    $line = (& $flutterBin devices) | Where-Object { $_ -match '•\s+(\S+)\s+•\s+android-' } | Select-Object -First 1
    if ($line -match '•\s+(\S+)\s+•\s+android-') { return $Matches[1] }
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

$preferDevice = $null
if (-not $Usb) {
  $adb = Resolve-Adb
  if (-not $adb) {
    Write-Host "[INFO] adb introuvable : install USB classique (pas de Wi-Fi)." -ForegroundColor Yellow
  } else {
    try {
      $preferDevice = Enable-PhoneWifiAdb $adb $AdbPort $PhoneIp
      if ($preferDevice) {
        Write-Host " Device Wi-Fi : $preferDevice"
        Write-Host " Tu peux debrancher le cable."
      }
    } catch {
      Write-Host "[INFO] ADB Wi-Fi impossible : $($_.Exception.Message)" -ForegroundColor Yellow
    }
  }
} else {
  Write-Host " Mode USB force."
}

$deviceId = Resolve-FlutterAndroidId $flutter $preferDevice

if (-not $deviceId) {
  Write-Host "[ERREUR] Aucun telephone Android detecte." -ForegroundColor Red
  Write-Host "1ere fois : USB + debogage USB, accepte l'empreinte PC."
  Write-Host "Ensuite le raccourci passe en Wi-Fi (meme box). Ou : -PhoneIp 192.168.x.x"
  if ($Usb) {
    Write-Host "Mode -Usb : laisse le cable branche."
  }
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
