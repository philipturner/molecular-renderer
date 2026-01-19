# Test runner convenience wrapper
param([string]$TestName, [switch]$NoCleanup)
& "$PSScriptRoot/Scripts/TestAutomation/run-test.ps1" -TestName $TestName -NoCleanup:$NoCleanup