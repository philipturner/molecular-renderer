param(
    [Parameter(Mandatory=$true)]
    [string]$TestName,

    [switch]$NoCleanup
)

# Ensure we're running from the project root directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptsDir = Split-Path -Parent $scriptDir
$projectRoot = Split-Path -Parent $scriptsDir
Set-Location $projectRoot

# Function to show usage
function Show-Usage {
    Write-Host "Usage: .\run-test.ps1 -TestName <TestName>" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Available tests:" -ForegroundColor Cyan
    $testFiles = Get-ChildItem "Documentation/Tests/*.swift" | Select-Object -ExpandProperty BaseName
    foreach ($test in $testFiles) {
        Write-Host "  - $test" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Green
    Write-Host "  .\run-test.ps1 -TestName MM4"
    Write-Host "  .\run-test.ps1 -TestName OpenMMPlugin"
    Write-Host "  .\run-test.ps1 -TestName AccelerationStructure"
}

# Check if test file exists
$testFile = "Documentation/Tests/$TestName.swift"
if (-not (Test-Path $testFile)) {
    Write-Host "Error: Test file '$testFile' not found." -ForegroundColor Red
    Write-Host ""
    Show-Usage
    exit 1
}

# main.swift swapping (must leave no trace unless -NoCleanup)
$mainSwift = "Sources/Workspace/main.swift"
$backupFile = "Sources/Workspace/main.swift.backup"
$hadMainSwiftInitially = Test-Path $mainSwift

# If a previous run left a backup behind, restore it first so we start clean.
if (Test-Path $backupFile) {
    Write-Host "Found existing main.swift.backup - restoring before running test..." -ForegroundColor Yellow
    Move-Item $backupFile $mainSwift -Force
    $hadMainSwiftInitially = $true
}

# Backup original main.swift if it exists.
if (Test-Path $mainSwift) {
    Write-Host "Backing up original main.swift..." -ForegroundColor Yellow
    Copy-Item $mainSwift $backupFile -Force
}

try {
    # Copy test file to main.swift
    Write-Host "Setting up test: $TestName" -ForegroundColor Green
    Copy-Item $testFile $mainSwift -Force

    # Run the test
    Write-Host "Running test: $TestName" -ForegroundColor Green
    Write-Host "Press Ctrl+C to stop the application" -ForegroundColor Yellow
    Write-Host ""

    $exitCode = 0

    # Find Swift executable
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $swiftPath = (where.exe swift 2>$null | Select-Object -First 1)
    if (-not $swiftPath) {
        # Try common Swift installation locations
        $possiblePaths = @(
            "C:\Users\$env:USERNAME\AppData\Local\Programs\Swift\Toolchains\*\usr\bin\swift.exe",
            "C:\Library\Developer\Toolchains\*\usr\bin\swift.exe"
        )
        foreach ($path in $possiblePaths) {
            $resolved = Resolve-Path $path -ErrorAction SilentlyContinue
            if ($resolved) {
                $swiftPath = $resolved[0].Path
                break
            }
        }
    }
    if (-not $swiftPath) {
        Write-Host "Error: Swift executable not found in PATH or default locations." -ForegroundColor Red
        exit 1
    }

    # Run Swift directly with proper environment
    # Ensure native DLL dependencies are discoverable at runtime.
    # Several libraries are downloaded/copied into the package's `.build` folder
    # (e.g. FidelityFX, OpenMM, DXC).
    $buildDir = Join-Path $projectRoot ".build"
    $dllSearchDirs = @(
        # install-libraries.bat copies key DLLs here
        $projectRoot,
        $buildDir,
        (Join-Path $buildDir "xtb-windows/xtb-windows"),
        (Join-Path $buildDir "openmm-windows/openmm-windows"),
        (Join-Path $buildDir "dxc_2025_07_14/bin/x64")
    )
    foreach ($dir in $dllSearchDirs) {
        if (Test-Path $dir) {
            $env:PATH = "$dir;$env:PATH"
        }
    }

    # OpenMM loads platform plugins (e.g. OpenMMOpenCL.dll) from OPENMM_PLUGIN_DIR.
    # `install-libraries.bat` copies these DLLs into the repo root, so point there.
    $env:OPENMM_PLUGIN_DIR = $projectRoot
    $env:OMP_STACKSIZE = "2G"
    $env:MTL_HUD_ENABLED = "1"

    # Compile and run directly with Swift
    Write-Host "Using swift: $swiftPath" -ForegroundColor Cyan
    & $swiftPath run -Xswiftc -Ounchecked
    $exitCode = $LASTEXITCODE
} finally {
    # Restore original main.swift unless -NoCleanup is specified
    if (-not $NoCleanup) {
        if (Test-Path $backupFile) {
            Write-Host ""
            Write-Host "Restoring original main.swift..." -ForegroundColor Yellow
            Move-Item $backupFile $mainSwift -Force
        } elseif (-not $hadMainSwiftInitially) {
            # If there was no main.swift before the test, remove the temporary one we created.
            if (Test-Path $mainSwift) {
                Write-Host ""
                Write-Host "Removing temporary main.swift..." -ForegroundColor Yellow
                Remove-Item $mainSwift -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # Ensure we return Swift's exit code (so CI / scripts can detect failures).
    if ($null -ne $exitCode) {
        exit $exitCode
    }
}