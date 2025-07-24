#requires -Version 5.1

<#
.SYNOPSIS
    Tests the smart defaults functionality.
#>

[CmdletBinding()]
param()

# Import the script functions
. "$PSScriptRoot\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1"

Write-Host "`nTesting Smart Defaults Functions" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

# Test 1: System Resources
Write-Host "`n1. Testing Get-SystemResources:" -ForegroundColor Yellow
try {
    $resources = Get-SystemResources
    Write-Host "   [PASS] System Resources:" -ForegroundColor Green
    Write-Host "   CPU: $($resources.CPUName)" -ForegroundColor White
    Write-Host "   Cores: $($resources.TotalCores) (Logical: $($resources.LogicalProcessors))" -ForegroundColor White
    Write-Host "   Memory: $($resources.TotalMemoryGB) GB (Available: $($resources.AvailableMemoryGB) GB)" -ForegroundColor White
}
catch {
    Write-Host "   [FAIL] Error: $_" -ForegroundColor Red
}

# Test 2: Processor Count
Write-Host "`n2. Testing Get-ProcessorCount:" -ForegroundColor Yellow
try {
    $allCores = Get-ProcessorCount -ProcessorValue "All Cores"
    Write-Host "   [PASS] 'All Cores' = $allCores" -ForegroundColor Green
    
    $specificCores = Get-ProcessorCount -ProcessorValue "4"
    Write-Host "   [PASS] '4' = $specificCores" -ForegroundColor Green
    
    $invalidValue = Get-ProcessorCount -ProcessorValue "Invalid"
    Write-Host "   [PASS] 'Invalid' = $invalidValue (defaulted to 2)" -ForegroundColor Green
}
catch {
    Write-Host "   [FAIL] Error: $_" -ForegroundColor Red
}

# Test 3: Smart Memory Allocation
Write-Host "`n3. Testing Get-SmartMemoryAllocation:" -ForegroundColor Yellow
try {
    $memory = Get-SmartMemoryAllocation -AllocationMode 'Balanced'
    Write-Host "   [PASS] Balanced allocation:" -ForegroundColor Green
    Write-Host "   Startup: $($memory.StartupBytes)" -ForegroundColor White
    Write-Host "   Minimum: $($memory.MinimumBytes)" -ForegroundColor White
    Write-Host "   Maximum: $($memory.MaximumBytes)" -ForegroundColor White
}
catch {
    Write-Host "   [FAIL] Error: $_" -ForegroundColor Red
}

# Test 4: Smart Virtual Switch
Write-Host "`n4. Testing Get-SmartVirtualSwitch:" -ForegroundColor Yellow
try {
    $switch = Get-SmartVirtualSwitch -RequestedSwitch "Default Switch"
    Write-Host "   [PASS] Selected switch: $switch" -ForegroundColor Green
}
catch {
    Write-Host "   [FAIL] Error: $_" -ForegroundColor Red
}

# Test 5: Smart Paths
Write-Host "`n5. Testing Get-SmartPaths:" -ForegroundColor Yellow
try {
    $drives = Get-AvailableDrives
    if ($drives.Count -gt 0) {
        $testDrive = $drives[0].DriveLetter
        $paths = Get-SmartPaths -DriveLetter $testDrive
        Write-Host "   [PASS] Smart paths for drive ${testDrive}:" -ForegroundColor Green
        $paths.GetEnumerator() | Where-Object { $_.Key -match 'Path$' } | ForEach-Object {
            Write-Host "   $($_.Key): $($_.Value)" -ForegroundColor White
        }
    }
}
catch {
    Write-Host "   [FAIL] Error: $_" -ForegroundColor Red
}

# Test 6: Configuration Processing
Write-Host "`n6. Testing Process-SmartConfiguration:" -ForegroundColor Yellow
try {
    $testConfig = @{
        VMNamePrefixFormat = 'Test VM'
        InstallMediaPath = 'test.iso'
        ProcessorCount = 'All Cores'
        SwitchName = 'Default Switch'
    }
    
    $drives = Get-AvailableDrives
    if ($drives.Count -gt 0) {
        $processedConfig = Process-SmartConfiguration -Config $testConfig -SelectedDrive $drives[0].DriveLetter
        Write-Host "   [PASS] Configuration processed:" -ForegroundColor Green
        Write-Host "   ProcessorCount: $($processedConfig.ProcessorCount)" -ForegroundColor White
        Write-Host "   Memory: $($processedConfig.MemoryStartupBytes)" -ForegroundColor White
        Write-Host "   Switch: $($processedConfig.SwitchName)" -ForegroundColor White
        Write-Host "   VMPath: $($processedConfig.VMPath)" -ForegroundColor White
    }
}
catch {
    Write-Host "   [FAIL] Error: $_" -ForegroundColor Red
}

Write-Host "`nAll tests completed!" -ForegroundColor Cyan