@echo off
REM Wrapper stable pour le raccourci Bureau
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch-phone.ps1" %*
if errorlevel 1 pause
