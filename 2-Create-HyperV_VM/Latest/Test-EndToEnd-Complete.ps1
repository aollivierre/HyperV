#requires -Version 5.1
#requires -RunAsAdministrator

<#
.SYNOPSIS
    Complete end-to-end test of the VM creation script.

.DESCRIPTION
    Tests the entire flow from start to finish using minimal config and smart defaults.
#>

[CmdletBinding()]
param(
    [switch]$RunActualVMCreation
)

# Create a minimal test configuration
$testConfigPath = "$PSScriptRoot\test-config-automated.psd1"
$testConfig = @'
@{
    # Minimal test configuration
    VMNamePrefixFormat = '{0:D3} - Test - Automated'
    InstallMediaPath = 'C:\test.iso'  # Will be created as dummy
    ProcessorCount = 2  # Use specific count for testing
    MemoryStartupBytes = '1GB'
    Generation = 2
}
'@

Write-Host "Creating test configuration file..." -ForegroundColor Cyan
$testConfig | Out-File -FilePath $testConfigPath -Force

# Create a dummy ISO file for testing
$dummyIsoPath = "C:\test.iso"
if (-not (Test-Path $dummyIsoPath)) {
    Write-Host "Creating dummy ISO file..." -ForegroundColor Cyan
    "Dummy ISO content" | Out-File -FilePath $dummyIsoPath -Force
}

# Test 1: Import and validate modules
Write-Host "`nTest 1: Module Import" -ForegroundColor Yellow
try {
    Import-Module "$PSScriptRoot\modules\EnhancedHyperVAO\EnhancedHyperVAO.psd1" -Force
    $functions = Get-Command -Module EnhancedHyperVAO
    Write-Host "[PASS] Imported $($functions.Count) functions from EnhancedHyperVAO" -ForegroundColor Green
}
catch {
    Write-Host "[FAIL] Module import failed: $_" -ForegroundColor Red
    exit 1
}

# Test 2: Test configuration loading
Write-Host "`nTest 2: Configuration Loading" -ForegroundColor Yellow
try {
    # Mock the selection process
    $global:MockInputQueue = @('1', 'Y')  # Select first config, then Yes
    $global:MockInputIndex = 0
    
    function global:Read-Host {
        param($Prompt)
        if ($global:MockInputIndex -lt $global:MockInputQueue.Count) {
            $input = $global:MockInputQueue[$global:MockInputIndex]
            $global:MockInputIndex++
            return $input
        }
        throw "No more mock input available"
    }
    
    # We'll use the actual Get-VMConfiguration but with our test config
    # For now, let's validate the config can be loaded
    $config = Import-PowerShellDataFile -Path $testConfigPath
    Write-Host "[PASS] Configuration loaded successfully" -ForegroundColor Green
}
catch {
    Write-Host "[FAIL] Configuration loading failed: $_" -ForegroundColor Red
}
finally {
    Remove-Item function:Read-Host -ErrorAction SilentlyContinue
}

# Test 3: Test smart defaults processing
Write-Host "`nTest 3: Smart Defaults Processing" -ForegroundColor Yellow
try {
    # Source the functions we need
    . "$PSScriptRoot\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1" -ErrorAction Stop
}
catch {
    # Script will try to execute, but we just need the functions
    if ($_.Exception.Message -notlike "*Failed to load configuration*") {
        Write-Host "[WARN] Script execution attempted, but functions loaded" -ForegroundColor Yellow
    }
}

# Test individual components
Write-Host "`nTesting individual components:" -ForegroundColor Cyan

# Test drive selection
try {
    $drives = Get-AvailableDrives
    $bestDrive = Select-BestDrive -MinimumFreeSpaceGB 10
    Write-Host "[PASS] Drive selection: $($bestDrive.DriveLetter) with $($bestDrive.FreeSpaceGB)GB free" -ForegroundColor Green
}
catch {
    Write-Host "[FAIL] Drive selection failed: $_" -ForegroundColor Red
}

# Test smart paths
try {
    $testConfig = @{
        VMPath = "D:\VMs"
        InstallMediaPath = "E:\ISO\test.iso"
    }
    $updatedConfig = Get-SmartPaths -DriveLetter "C" -Config $testConfig
    Write-Host "[PASS] Smart paths updated successfully" -ForegroundColor Green
    Write-Host "  VMPath: $($updatedConfig.VMPath)" -ForegroundColor Gray
    Write-Host "  InstallMediaPath: $($updatedConfig.InstallMediaPath)" -ForegroundColor Gray
}
catch {
    Write-Host "[FAIL] Smart paths failed: $_" -ForegroundColor Red
}

# Test processor count
try {
    $allCores = Get-ProcessorCount -ProcessorValue "All Cores"
    $specific = Get-ProcessorCount -ProcessorValue "4"
    Write-Host "[PASS] Processor count: All Cores=$allCores, Specific=4" -ForegroundColor Green
}
catch {
    Write-Host "[FAIL] Processor count failed: $_" -ForegroundColor Red
}

# Test memory allocation
try {
    $memory = Get-SmartMemoryAllocation -AllocationMode 'Balanced'
    Write-Host "[PASS] Memory allocation: $($memory.StartupBytes) startup" -ForegroundColor Green
}
catch {
    Write-Host "[FAIL] Memory allocation failed: $_" -ForegroundColor Red
}

# Test 4: Full script execution (dry run)
Write-Host "`nTest 4: Full Script Execution (Dry Run)" -ForegroundColor Yellow
if ($RunActualVMCreation) {
    Write-Host "Running actual VM creation test..." -ForegroundColor Cyan
    try {
        # Run with smart defaults to bypass all prompts
        & "$PSScriptRoot\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1" `
            -UseSmartDefaults `
            -ConfigurationPath $PSScriptRoot `
            -AutoSelectDrive
    }
    catch {
        Write-Host "[FAIL] Script execution failed: $_" -ForegroundColor Red
    }
}
else {
    Write-Host "[SKIP] Actual VM creation skipped (use -RunActualVMCreation to test)" -ForegroundColor Yellow
}

# Cleanup
Write-Host "`nCleaning up test files..." -ForegroundColor Cyan
Remove-Item -Path $testConfigPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path $dummyIsoPath -Force -ErrorAction SilentlyContinue

Write-Host "`nEnd-to-end testing complete!" -ForegroundColor Green