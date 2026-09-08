# FutBolia — Flutter Web (navigateur)
# Usage:
#   .\scripts\launch-web.ps1           → API Render
#   .\scripts\launch-web.ps1 -Local    → API NestJS locale :3000
param(
  [switch]$Local
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $scriptDir "launch-pc.ps1") @PSBoundParameters
exit $LASTEXITCODE
