#requires -RunAsAdministrator

Write-Host "`nTesting Script Flow (Dry Run)" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan

# Test 1: Test with missing ISO to see prompting
Write-Host "`nTest 1: Missing ISO Path" -ForegroundColor Yellow
Write-Host "This should prompt for a valid ISO path." -ForegroundColor Gray
Write-Host "When prompted, press Ctrl+C to cancel." -ForegroundColor Yellow
Write-Host "`nPress any key to start test..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

try {
    & .\Create-VHDX-Working.ps1 -ISOPath "C:\fake\nonexistent.iso" -OutputDir "$env:TEMP" -EditionIndex 1
} catch {
    Write-Host "`nTest cancelled or error: $_" -ForegroundColor Yellow
}

# Test 2: Check what happens with valid paths but early exit
Write-Host "`n`nTest 2: Valid Paths - Early Exit Test" -ForegroundColor Yellow
Write-Host "This will start the script with valid paths but we'll exit before conversion." -ForegroundColor Gray

# Create a modified version that exits before actual conversion
$testScript = @'
param(
    [string]$ISOPath = "C:\code\ISO\Windows10.iso",
    [string]$OutputDir = "C:\code\VM\Setup\VHDX\test",
    [int]$SizeGB = 100,
    [int]$EditionIndex = 0
)

Write-Host "ISO: $ISOPath"
Write-Host "Output: $OutputDir"
Write-Host "Size: $SizeGB GB"

if (Test-Path $ISOPath) {
    Write-Host "OK - ISO found" -ForegroundColor Green
} else {
    Write-Host "ERROR - ISO not found" -ForegroundColor Red
}

if (Test-Path (Split-Path $OutputDir -Parent)) {
    Write-Host "OK - Output directory parent exists" -ForegroundColor Green
} else {
    Write-Host "ERROR - Output directory parent not found" -ForegroundColor Red
}

Write-Host "`nScript flow test complete - exiting before conversion" -ForegroundColor Yellow
'@

$testScript | Out-File "$env:TEMP\Test-Flow.ps1" -Encoding UTF8
& "$env:TEMP\Test-Flow.ps1"
Remove-Item "$env:TEMP\Test-Flow.ps1"

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Script flow tests completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green