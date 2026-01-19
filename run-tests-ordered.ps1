# Test runner convenience wrapper
param([switch]$Low, [switch]$Medium, [switch]$High, [switch]$Video, [switch]$All, [switch]$NoCleanup, [int]$StartFrom = 1)
& "$PSScriptRoot/Scripts/TestAutomation/run-tests-ordered.ps1" -Low:$Low -Medium:$Medium -High:$High -Video:$Video -All:$All -NoCleanup:$NoCleanup -StartFrom $StartFrom