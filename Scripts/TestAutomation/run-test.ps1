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

# Backup original main.swift if it exists and not already a backup
$mainSwift = "Sources/Workspace/main.swift"
$backupFile = "Sources/Workspace/main.swift.backup"

if ((Test-Path $mainSwift) -and -not (Test-Path $backupFile)) {
    Write-Host "Backing up original main.swift..." -ForegroundColor Yellow
    Copy-Item $mainSwift $backupFile
}

# Copy test file to main.swift
Write-Host "Setting up test: $TestName" -ForegroundColor Green
Copy-Item $testFile $mainSwift -Force

# Run the test
Write-Host "Running test: $TestName" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop the application" -ForegroundColor Yellow
Write-Host ""

try {
    # Find Swift executable
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
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
        return
    }

    # Run Swift directly with proper environment
    $env:OPENMM_PLUGIN_DIR = $scriptDir
    $env:OMP_STACKSIZE = "2G"
    $env:MTL_HUD_ENABLED = "1"

    # Compile and run directly with Swift
    & $swiftPath run -Xswiftc -Ounchecked
} finally {
    # Restore original main.swift unless -NoCleanup is specified
    if (-not $NoCleanup) {
        if (Test-Path $backupFile) {
            Write-Host ""
            Write-Host "Restoring original main.swift..." -ForegroundColor Yellow
            Move-Item $backupFile $mainSwift -Force
        }
    }
}