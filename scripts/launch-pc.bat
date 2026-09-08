@echo off
REM Apercu FutBolia : http://localhost:8080 (tous les navigateurs)
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch-pc.ps1" %*
if errorlevel 1 pause
