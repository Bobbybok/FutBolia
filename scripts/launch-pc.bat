@echo off
REM Apercu FutBolia dans le navigateur : http://localhost:8080
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch-pc.ps1" %*
if errorlevel 1 pause
