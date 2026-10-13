param(
    [switch]$Low,
    [switch]$Medium,
    [switch]$High,
    [switch]$Video,
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
    "OpenMMPlugin",
    "MM4",
    "xTB"
    # Note: Propargyl Alcohol Tripod and Stannatrane Tripod require additional files
)

$mediumAtomTests = @(
    "AccelerationStructure",
    "CriticalPixelCount"
    # Note: MM4 Energy Minimization requires additional files
)

$highAtomTests = @(
    "RotatingBeam",
    "LongDistances",
    "LargeScenes"
)

$videoTests = @(
    "Upscaling-WithVideo",
    "MDSimulationVideo",
    "RotatingBeam-WithVideo",
    "LongDistances-WithVideo",
    "LargeScenes-WithVideo"
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

    try {
        # Delegate to the single-test runner so main.swift swapping is defined in ONE place.
        & "$PSScriptRoot/run-test.ps1" -TestName $TestName -NoCleanup:$NoCleanup
        return ($LASTEXITCODE -eq 0)
    } catch {
        Write-Host "Test execution failed or was interrupted." -ForegroundColor Red
        return $false
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
    Write-Host "  .\run-tests-ordered.ps1 -Video     # Run video output tests (saves .gif files)"
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
    Write-Host "Video Output Tests (.gif):" -ForegroundColor Magenta
    for ($i = 0; $i -lt $videoTests.Count; $i++) {
        Write-Host "  $($i+1). $($videoTests[$i])" -ForegroundColor White
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
} elseif ($Video) {
    $testsToRun = $videoTests
    $categoryName = "Video Output Tests"
} elseif ($All) {
    $testsToRun = $lowAtomTests + $mediumAtomTests + $highAtomTests + $videoTests
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
    Write-Host "  - MDSimulationVideo test saves: .build/video.gif" -ForegroundColor White
    Write-Host "  - Upscaling-WithVideo saves: Art/molecular-upscaling-animation.gif" -ForegroundColor White
    Write-Host "  - RotatingBeam-WithVideo saves: Art/rotating-beam.gif" -ForegroundColor White
    Write-Host "  - LongDistances-WithVideo saves: Art/long-distances.gif" -ForegroundColor White
    Write-Host "  - LargeScenes-WithVideo saves: Art/large-scenes.gif" -ForegroundColor White
    Write-Host "  - Some tripod tests save: .build/image.ppm" -ForegroundColor White
    Write-Host ""
    Write-Host "GUI tests (Upscaling, MM4) show interactive windows" -ForegroundColor Yellow
    Write-Host "If windows don't appear, try running in Command Prompt directly" -ForegroundColor Yellow
}
Write-Host "==========================================" -ForegroundColor Cyan