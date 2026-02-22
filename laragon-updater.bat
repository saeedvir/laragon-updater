@echo off
REM Laragon Tools Updater - Batch Launcher
REM This script runs the PowerShell updater with elevated permissions if needed

cd /d "%~dp0"

echo ==============================================
echo       Laragon Tools Updater Launcher
echo ==============================================
echo.

REM Check if running as admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File \"%~dp0laragon-updater.ps1\"' -Verb RunAs"
) else (
    powershell -ExecutionPolicy Bypass -File "%~dp0laragon-updater.ps1"
)

echo.
echo Press any key to exit...
pause >nul
