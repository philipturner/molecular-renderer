@echo off
setlocal enabledelayedexpansion

REM Change to the script directory
cd /d "%~dp0"

echo Molecular Renderer - Ordered Test Runner
echo ========================================
echo.
echo Select test category:
echo.
echo 1. Low Atom Count (10-100 atoms)
echo 2. Medium Atom Count (10,000-100,000 atoms)
echo 3. High Atom Count (1,000,000-100,000,000 atoms)
echo 4. All Tests (run in order)
echo.
set /p choice="Enter choice (1-4): "

if "%choice%"=="1" (
    set "category=-Low"
    set "categoryName=Low Atom Count"
) else if "%choice%"=="2" (
    set "category=-Medium"
    set "categoryName=Medium Atom Count"
) else if "%choice%"=="3" (
    set "category=-High"
    set "categoryName=High Atom Count"
) else if "%choice%"=="4" (
    set "category=-All"
    set "categoryName=All Tests"
) else (
    echo Invalid choice.
    pause
    exit /b 1
)

echo.
echo Starting %categoryName% tests...
echo.

REM Run the PowerShell script
powershell -ExecutionPolicy Bypass -File "%~dp0run-tests-ordered.ps1" %category%

pause