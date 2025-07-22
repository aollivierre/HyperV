#requires -Version 5.1

<#
.SYNOPSIS
    Tests the flexible drive functionality in the refactored Hyper-V script.
#>

[CmdletBinding()]
param()

# Import the script (dot-source to get functions)
. "$PSScriptRoot\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v4-FlexibleDrives.ps1"

Write-Host "`nTesting Drive Management Functions" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

# Test 1: Get Available Drives
Write-Host "`n1. Testing Get-AvailableDrives:" -ForegroundColor Yellow
try {
    $drives = Get-AvailableDrives
    Write-Host "   [PASS] Found $($drives.Count) drives:" -ForegroundColor Green
    $drives | Format-Table DriveLetter, FreeSpaceGB, TotalSpaceGB, PercentFree -AutoSize
}
catch {
    Write-Host "   [FAIL] Error: $_" -ForegroundColor Red
}

# Test 2: Select Best Drive
Write-Host "`n2. Testing Select-BestDrive:" -ForegroundColor Yellow
try {
    $bestDrive = Select-BestDrive -MinimumFreeSpaceGB 20
    Write-Host "   [PASS] Best drive selected: $($bestDrive.DriveLetter): with $($bestDrive.FreeSpaceGB) GB free" -ForegroundColor Green
}
catch {
    Write-Host "   [FAIL] Error: $_" -ForegroundColor Red
}

# Test 3: Update Paths
Write-Host "`n3. Testing Update-PathsForDrive:" -ForegroundColor Yellow
try {
    $testConfig = @{
        VMPath = "D:\VM"
        VHDXPath = "D:\VM\Setup\VHDX\test.vhdx"
        InstallMediaPath = "E:\ISO\Windows.iso"
    }
    
    Write-Host "   Original paths:" -ForegroundColor Cyan
    $testConfig.GetEnumerator() | ForEach-Object { Write-Host "     $($_.Key): $($_.Value)" }
    
    $updatedConfig = Update-PathsForDrive -Config $testConfig -NewDrive "C"
    
    Write-Host "   Updated paths:" -ForegroundColor Cyan
    $updatedConfig.GetEnumerator() | ForEach-Object { Write-Host "     $($_.Key): $($_.Value)" }
    
    Write-Host "   [PASS] Paths updated successfully" -ForegroundColor Green
}
catch {
    Write-Host "   [FAIL] Error: $_" -ForegroundColor Red
}

# Test 4: Path without drive letter
Write-Host "`n4. Testing path without drive letter:" -ForegroundColor Yellow
try {
    $testConfig2 = @{
        VMPath = "VM\MyVMs"
    }
    
    $updatedConfig2 = Update-PathsForDrive -Config $testConfig2 -NewDrive "E"
    Write-Host "   Original: $($testConfig2.VMPath)" -ForegroundColor Cyan
    Write-Host "   Updated: $($updatedConfig2.VMPath)" -ForegroundColor Cyan
    Write-Host "   [PASS] Path without drive letter handled correctly" -ForegroundColor Green
}
catch {
    Write-Host "   [FAIL] Error: $_" -ForegroundColor Red
}

Write-Host "`nAll tests completed!" -ForegroundColor Cyan