@echo off
REM FutBolia Flutter Web — http://localhost:8080
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch-web.ps1" %*
if errorlevel 1 pause
