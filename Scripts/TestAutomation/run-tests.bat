@echo off
setlocal enabledelayedexpansion

REM Change to the script directory
cd /d "%~dp0"

echo Molecular Renderer Test Runner
echo ===============================
echo.

echo Available tests:
echo.

set /a count=1
for %%f in (Documentation\Tests\*.swift) do (
    set "test[!count!]=%%~nf"
    echo !count!. %%~nf
    set /a count+=1
)

echo.
set /p choice="Enter test number or name (or 'q' to quit): "

if /i "%choice%"=="q" goto :eof
if "%choice%"=="" goto :eof

REM Check if input is a number
echo %choice%| findstr /r "^[0-9][0-9]*$" >nul
if %errorlevel%==0 (
    REM Input is a number, get the corresponding test name
    set "test_name=!test[%choice%]!"
    if "!test_name!"=="" (
        echo Invalid test number.
        pause
        goto :eof
    )
) else (
    REM Input is a name, use it directly
    set "test_name=%choice%"
)

REM Check if the test file exists
if not exist "Documentation\Tests\%test_name%.swift" (
    echo Test "%test_name%" not found.
    echo.
    echo Available tests:
    for %%f in (Documentation\Tests\*.swift) do echo   %%~nf
    echo.
    pause
    goto :eof
)

echo.
echo Running test: %test_name%
echo.

REM Run the PowerShell script
powershell -ExecutionPolicy Bypass -File "%~dp0run-test.ps1" -TestName "%test_name%"

pause