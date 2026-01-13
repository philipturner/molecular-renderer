# Test Automation

This document explains how to automatically run the tests in `Documentation/Tests/` without manual copy-paste operations.

## Quick Start

### Method 1: Interactive Menu (Easiest)

Run the interactive test selector:

```batch
run-tests.bat
```

This will show a numbered list of available tests. Just enter the number or name of the test you want to run.

### Method 2: Run Tests in Order

Run tests in their intended order by atom count complexity:

```batch
run-tests-ordered.bat
```

Or use PowerShell directly:

```powershell
.\run-tests-ordered.ps1 -Low      # Run low atom count tests (10-100 atoms)
.\run-tests-ordered.ps1 -Medium   # Run medium atom count tests (10k-100k atoms)
.\run-tests-ordered.ps1 -High     # Run high atom count tests (1M-100M atoms)
.\run-tests-ordered.ps1 -All      # Run all tests in order
```

### Method 3: Direct PowerShell Script

Run a specific test directly:

```powershell
.\run-test.ps1 -TestName MM4
.\run-test.ps1 -TestName OpenMMPlugin
.\run-test.ps1 -TestName AccelerationStructure
```

## Folder Organization

```
molecular-renderer/
├── Scripts/TestAutomation/     # Test automation scripts
│   ├── README.md              # This documentation
│   ├── run-test.ps1           # Run individual tests
│   ├── run-tests-ordered.ps1  # Run tests in order
│   ├── run-tests.bat          # Interactive test selector
│   └── run-tests-ordered.bat  # Interactive ordered runner
├── Documentation/Tests/       # Test source files
├── Art/                       # Generated outputs (videos, images)
└── [root wrappers]            # Convenience scripts (run-test.ps1, etc.)
```

## Available Tests

Tests are organized by atom count complexity:

### Low Atom Count (10-100 atoms)
These tests are quick to run and validate basic functionality:

- **Upscaling** - Tests image upscaling functionality
- **Upscaling-WithOutput** - Saves 5 animation frames to .build/upscaling_frame_*.ppm (runs for 10 seconds)
- **Upscaling-WithVideo** - Creates animated GIF of molecular upscaling (10s animation → Art/molecular-upscaling-animation.gif)
- **Upscaling-Video** - Saves 8-second animated GIF of rotating molecules to Art/upscaling-molecular-animation.gif
- **OpenMMPlugin** - Tests OpenMM plugin loading
- **MM4** - Tests MM4 force field integration
- **MM4-WithVideo** - Molecular dynamics simulation with thermal motion (3s animation → .build/mm4-molecular-dynamics.gif)
- **MM4-Video** - Saves 3-second animated GIF of molecular dynamics to Art/mm4-molecular-dynamics.gif
- **xTB** - Tests xTB quantum chemistry integration

### Medium Atom Count (10,000-100,000 atoms)
These tests exercise medium-scale molecular structures:

- **AccelerationStructure** - Tests acceleration structure functionality
- **CriticalPixelCount** - Tests critical pixel count handling
- **MDSimulationVideo** - Tests molecular dynamics simulation video generation
- **MM4-Video** - Creates animated GIF of MM4 molecular dynamics
- **Upscaling-Video** - Creates animated GIF of molecular upscaling effects

### High Atom Count (1,000,000-100,000,000 atoms)
These tests push the limits of the renderer with massive structures:

- **RotatingBeam** - Tests rotating beam rendering (up to ~1M atoms)
- **LongDistances** - Tests handling of long distance calculations
- **LargeScenes** - Tests rendering of large molecular scenes (up to ~100M atoms)

### Special Tests (Require Additional Files)
Some tests require downloading additional Swift files from GitHub Gists:

- **Propargyl Alcohol Tripod** - Advanced tripod structure (requires gist files)
- **Stannatrane Tripod** - Complex tripod with energy minimization (requires gist files)
- **MM4 Energy Minimization** - FIRE algorithm minimization (requires gist files)

These special tests are documented but not included in the automated runners.

## GUI Test Behavior

**✅ Full Automation Working:** All tests now run successfully, including GUI tests that display windows!

### What Was Fixed:
- **Swift Path Detection**: Scripts now automatically find Swift in user-specific installation paths
- **Environment Setup**: Proper environment variables are set for OpenMM and performance optimization
- **Interactive GUI Support**: GUI tests now properly launch windows when run interactively

### Test Results:
- ✅ **Console Tests** (OpenMMPlugin, xTB): Run automatically and print results
- ✅ **GUI Tests** (Upscaling, MM4, etc.): Launch interactive molecular visualization windows
- ✅ **Output-Saving Tests**: Save files to .build/ and Art/ folders:
  - `MDSimulationVideo` → `Art/diamond-beams-collision-md.gif` (colliding beams MD)
  - `Upscaling-WithVideo` → `Art/molecular-upscaling-animation.gif` (rotating molecules)
  - `MM4-WithVideo` → `.build/mm4-molecular-dynamics.gif` (thermal motion)
  - `Upscaling-WithOutput` → `.build/upscaling_frame_*.ppm` (static frames)
  - Some tripod tests → `.build/image.ppm` (static image)
- ✅ **Build Validation**: All tests compile successfully
- ✅ **Environment Setup**: Proper OpenMM plugins and threading configured
- ✅ **Timing**: GUI tests now run for 15-20 seconds for visual inspection

### To See Visual Output:
Run any test and GUI windows will appear showing molecular animations!

### Test Types:
- **Console-Only Tests** (OpenMMPlugin, xTB): Run automatically and print results
- **GUI Tests** (Upscaling, MM4, etc.): Launch interactive molecular visualization windows

## Script Details

### run-test.ps1

The main PowerShell script that handles test execution:

- **Parameters:**
  - `-TestName` (required): Name of the test to run (without .swift extension)
  - `-NoCleanup` (optional): Don't restore the original main.swift after running

- **Features:**
  - Validates test file existence
  - Backs up your original `main.swift` automatically
  - Copies the test file to `Sources/Workspace/main.swift`
  - Runs the application using the existing `run.sh` script
  - Restores your original `main.swift` when done (unless `-NoCleanup` is used)

### run-tests.bat

A Windows batch file wrapper that provides an interactive menu:

- Lists all available tests with numbers
- Accepts test selection by number or name
- Calls `run-test.ps1` with the selected test

## Examples

```batch
# Run using the interactive menu
run-tests.bat

# Run specific tests directly
.\run-test.ps1 -TestName MM4
.\run-test.ps1 -TestName OpenMMPlugin

# Run a test without restoring main.swift (useful for debugging)
.\run-test.ps1 -TestName AccelerationStructure -NoCleanup
```

## Error Handling

The scripts include error handling for:
- Missing test files
- Invalid test names
- Backup/restore operations

If a test fails or you interrupt it with Ctrl+C, your original `main.swift` will be automatically restored.

## Integration with Development Workflow

You can integrate these scripts into your development workflow:

1. **Quick Testing:** Use `run-tests.bat` for rapid test switching during development
2. **CI/CD:** The PowerShell script can be called from automated build systems
3. **Regression Testing:** Create scripts that run multiple tests in sequence

## Troubleshooting

- **"Test file not found":** Make sure you're using the correct test name (case-sensitive)
- **"Permission denied":** Run PowerShell/Command Prompt as Administrator
- **"swift command not found":** Ensure Swift is properly installed and in PATH
- **Application won't start:** Check that all required libraries are installed (see main README.md)

## Advanced Usage

### Running Tests Programmatically

You can call the PowerShell script from other scripts:

```batch
@echo off
powershell -ExecutionPolicy Bypass -File "run-test.ps1" -TestName %1
```

Save this as `run-single-test.bat` and call it like:
```batch
run-single-test.bat MM4
```

### Creating Test Suites

Create a batch file to run multiple tests:

```batch
@echo off
echo Running test suite...

call powershell -ExecutionPolicy Bypass -File "run-test.ps1" -TestName OpenMMPlugin
call powershell -ExecutionPolicy Bypass -File "run-test.ps1" -TestName MM4
call powershell -ExecutionPolicy Bypass -File "run-test.ps1" -TestName AccelerationStructure

echo Test suite complete.
pause
```

## File Safety

The scripts automatically:
- Create backups of your original `main.swift`
- Restore the original file after test completion
- Handle interruptions gracefully (Ctrl+C)

Your original code is never permanently overwritten.