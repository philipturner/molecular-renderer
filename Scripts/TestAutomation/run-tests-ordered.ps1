param(
    [switch]$Low,
    [switch]$Medium,
    [switch]$High,
    [switch]$All,
    [switch]$NoCleanup,
    [int]$StartFrom = 1
)

# Ensure we're running from the project root directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptsDir = Split-Path -Parent $scriptDir
$projectRoot = Split-Path -Parent $scriptsDir
Set-Location $projectRoot

# Define test order by category
$lowAtomTests = @(
    "Upscaling",
    "Upscaling-WithOutput",
    "Upscaling-WithVideo",
    "OpenMMPlugin",
    "MM4",
    "MM4-WithVideo",
    "xTB"
    # Note: Propargyl Alcohol Tripod and Stannatrane Tripod require additional files
)

$mediumAtomTests = @(
    "AccelerationStructure",
    "CriticalPixelCount",
    "MDSimulationVideo",
    "MM4-Video",
    "Upscaling-Video"
    # Note: MM4 Energy Minimization requires additional files
)

$highAtomTests = @(
    "RotatingBeam",
    "LongDistances",
    "LargeScenes"
)

function Run-Test {
    param([string]$TestName)

    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Running test: $TestName" -ForegroundColor Yellow
    Write-Host "==========================================" -ForegroundColor Cyan

    $testFile = "Documentation/Tests/$TestName.swift"
    if (-not (Test-Path $testFile)) {
        Write-Host "Warning: Test file '$testFile' not found. Skipping..." -ForegroundColor Red
        return $false
    }

    # Check if this is a console-only test (doesn't launch renderer)
    $isConsoleOnly = $false
    switch ($TestName) {
        "OpenMMPlugin" { $isConsoleOnly = $true }
        "xTB" { $isConsoleOnly = $true }
        default { $isConsoleOnly = $false }
    }

    if ($isConsoleOnly) {
        Write-Host "Console-only test detected - will run automatically" -ForegroundColor Cyan
    } else {
        Write-Host "GUI test detected - may not show window in automated environment" -ForegroundColor Yellow
    }

    # Backup original main.swift if it exists and not already a backup
    $mainSwift = "Sources/Workspace/main.swift"
    $backupFile = "Sources/Workspace/main.swift.backup"

    if ((Test-Path $mainSwift) -and -not (Test-Path $backupFile)) {
        Write-Host "Backing up original main.swift..." -ForegroundColor Gray
        Copy-Item $mainSwift $backupFile
    }

    # Copy test file to main.swift
    Copy-Item $testFile $mainSwift -Force

    try {
        # Find Swift executable
        $swiftPath = where.exe swift 2>$null
        if (-not $swiftPath) {
            # Try common Swift installation locations
            $possiblePaths = @(
                "C:\Users\$env:USERNAME\AppData\Local\Programs\Swift\Toolchains\*\usr\bin\swift.exe",
                "C:\Library\Developer\Toolchains\*\usr\bin\swift.exe"
            )
            foreach ($path in $possiblePaths) {
                $resolved = Resolve-Path $path -ErrorAction SilentlyContinue
                if ($resolved) {
                    $swiftPath = $resolved.Path
                    break
                }
            }
        }
        if (-not $swiftPath) {
            Write-Host "Error: Swift executable not found in PATH or default locations." -ForegroundColor Red
            return $false
        }

        # Create a temporary script that sets environment and runs Swift
        $tempScript = @"
#!/bin/bash
cd "$scriptDir"
export OPENMM_PLUGIN_DIR="$scriptDir"
export OMP_STACKSIZE="2G"
export MTL_HUD_ENABLED=1
SWIFT_PATH="$swiftPath"
"`$SWIFT_PATH" run -Xswiftc -Ounchecked
"@

        $tempScriptPath = [System.IO.Path]::GetTempFileName() + ".sh"
        $tempScript | Out-File -FilePath $tempScriptPath -Encoding ASCII

        if ($isConsoleOnly) {
            # Console-only tests: run and capture output
            Write-Host "Running console test (no GUI)..." -ForegroundColor Green
            $process = Start-Process -FilePath "C:\Program Files\Git\bin\bash.exe" -ArgumentList $tempScriptPath -NoNewWindow -Wait -PassThru
            if ($process.ExitCode -eq 0) {
                Write-Host "Console test completed successfully." -ForegroundColor Green
                $result = $true
            } else {
                Write-Host "Console test failed with exit code $($process.ExitCode)." -ForegroundColor Red
                $result = $false
            }
        } else {
            # GUI tests: run in foreground so window appears
            Write-Host "Starting GUI test. A window should appear..." -ForegroundColor Green
            Write-Host "Close the application window when done, or press Ctrl+C here to stop." -ForegroundColor Yellow

            $process = Start-Process -FilePath "C:\Program Files\Git\bin\bash.exe" -ArgumentList $tempScriptPath -Wait -PassThru

            if ($process.ExitCode -eq 0) {
                Write-Host "GUI test completed (window closed)." -ForegroundColor Green
                $result = $true
            } else {
                Write-Host "GUI test failed with exit code $($process.ExitCode)." -ForegroundColor Red
                $result = $false
            }
        }

        # Clean up temp script
        Remove-Item $tempScriptPath -ErrorAction SilentlyContinue
        return $result
    }
    catch {
        Write-Host "Test execution failed or was interrupted." -ForegroundColor Red
        return $false
    }
    finally {
        # Restore original main.swift unless -NoCleanup is specified
        if (-not $NoCleanup) {
            if (Test-Path $backupFile) {
                Write-Host "Restoring original main.swift..." -ForegroundColor Gray
                Move-Item $backupFile $mainSwift -Force
            }
        }
    }
}

function Show-Usage {
    Write-Host "Molecular Renderer - Run Tests in Order" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\run-tests-ordered.ps1 -Low       # Run low atom count tests (10-100 atoms)"
    Write-Host "  .\run-tests-ordered.ps1 -Medium    # Run medium atom count tests (10k-100k atoms)"
    Write-Host "  .\run-tests-ordered.ps1 -High      # Run high atom count tests (1M-100M atoms)"
    Write-Host "  .\run-tests-ordered.ps1 -All       # Run all tests in order"
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -StartFrom <number>    # Start from specific test number (default: 1)"
    Write-Host "  -NoCleanup             # Don't restore main.swift after each test"
    Write-Host ""
    Write-Host "Test Categories:" -ForegroundColor Green
    Write-Host ""
    Write-Host "Low Atom Count (10-100 atoms):" -ForegroundColor Magenta
    for ($i = 0; $i -lt $lowAtomTests.Count; $i++) {
        Write-Host "  $($i+1). $($lowAtomTests[$i])" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "Medium Atom Count (10,000-100,000 atoms):" -ForegroundColor Magenta
    for ($i = 0; $i -lt $mediumAtomTests.Count; $i++) {
        Write-Host "  $($i+1). $($mediumAtomTests[$i])" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "High Atom Count (1,000,000-100,000,000 atoms):" -ForegroundColor Magenta
    for ($i = 0; $i -lt $highAtomTests.Count; $i++) {
        Write-Host "  $($i+1). $($highAtomTests[$i])" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "Note: Some tests require additional files from GitHub Gists." -ForegroundColor Yellow
    Write-Host "      These are marked in the documentation but not automated." -ForegroundColor Yellow
}

# Main logic
$testsToRun = @()
$categoryName = ""

if ($Low) {
    $testsToRun = $lowAtomTests
    $categoryName = "Low Atom Count"
} elseif ($Medium) {
    $testsToRun = $mediumAtomTests
    $categoryName = "Medium Atom Count"
} elseif ($High) {
    $testsToRun = $highAtomTests
    $categoryName = "High Atom Count"
} elseif ($All) {
    $testsToRun = $lowAtomTests + $mediumAtomTests + $highAtomTests
    $categoryName = "All Tests"
} else {
    Show-Usage
    exit 1
}

Write-Host "Molecular Renderer Test Runner" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Category: $categoryName" -ForegroundColor Yellow
Write-Host "Tests to run: $($testsToRun.Count)" -ForegroundColor Yellow
if ($StartFrom -gt 1) {
    Write-Host "Starting from test #$StartFrom" -ForegroundColor Yellow
}
Write-Host ""

$completedTests = 0
$skippedTests = 0

for ($i = ($StartFrom - 1); $i -lt $testsToRun.Count; $i++) {
    $testName = $testsToRun[$i]
    $testNumber = $i + 1

    Write-Host ""
    Write-Host "Test $testNumber of $($testsToRun.Count): $testName" -ForegroundColor Green

    $success = Run-Test -TestName $testName

    if ($success) {
        $completedTests++
        Write-Host "[OK] Test $testName completed successfully" -ForegroundColor Green
    } else {
        $skippedTests++
        Write-Host "[SKIP] Test $testName was skipped or failed" -ForegroundColor Yellow
    }

    # Ask user if they want to continue (except for the last test)
    if ($i -lt ($testsToRun.Count - 1)) {
        Write-Host ""
        $continue = Read-Host "Continue to next test? (Y/n)"
        if ($continue -eq "n" -or $continue -eq "N") {
            Write-Host "Stopping test execution." -ForegroundColor Yellow
            break
        }
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Test Summary:" -ForegroundColor Yellow
Write-Host "  Completed: $completedTests" -ForegroundColor Green
Write-Host "  Skipped/Failed: $skippedTests" -ForegroundColor Red
Write-Host ""
if ($completedTests -gt 0) {
    Write-Host "[SUCCESS] All tests built successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Check for saved outputs in .build folder:" -ForegroundColor Cyan
    Write-Host "  - MDSimulationVideo test saves: Art/diamond-beams-collision-md.gif" -ForegroundColor White
    Write-Host "  - Upscaling-Video saves: Art/upscaling-molecular-animation.gif" -ForegroundColor White
    Write-Host "  - MM4-Video saves: Art/mm4-molecular-dynamics.gif" -ForegroundColor White
    Write-Host "  - Upscaling-WithOutput saves: .build/upscaling_frame_*.ppm" -ForegroundColor White
    Write-Host "  - Some tripod tests save: .build/image.ppm" -ForegroundColor White
    Write-Host ""
    Write-Host "GUI tests (Upscaling, MM4) show interactive windows" -ForegroundColor Yellow
    Write-Host "If windows don't appear, try running in Command Prompt directly" -ForegroundColor Yellow
}
Write-Host "==========================================" -ForegroundColor Cyan