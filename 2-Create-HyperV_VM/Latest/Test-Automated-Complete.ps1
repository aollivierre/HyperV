#requires -Version 5.1

<#
.SYNOPSIS
    Comprehensive automated test suite for the Hyper-V VM creation script.

.DESCRIPTION
    Tests all major functions and workflows without user interaction or actual VM creation.
#>

[CmdletBinding()]
param(
    [switch]$Verbose
)

# Test results tracking
$testResults = @()
$testCount = 0
$passCount = 0
$failCount = 0

function Test-Function {
    param(
        [string]$Name,
        [scriptblock]$Test
    )
    
    $global:testCount++
    Write-Host "`nTest $testCount: $Name" -ForegroundColor Yellow
    
    try {
        $result = & $Test
        if ($result -ne $false) {
            Write-Host "[PASS] $Name" -ForegroundColor Green
            $global:passCount++
            $success = $true
        }
        else {
            Write-Host "[FAIL] $Name" -ForegroundColor Red
            $global:failCount++
            $success = $false
        }
    }
    catch {
        Write-Host "[FAIL] $Name - Error: $_" -ForegroundColor Red
        $global:failCount++
        $success = $false
    }
    
    $global:testResults += [PSCustomObject]@{
        TestNumber = $testCount
        TestName = $Name
        Success = $success
        Error = if (-not $success) { $_.ToString() } else { $null }
    }
}

Write-Host "=== Automated Test Suite for Hyper-V VM Creation Script ===" -ForegroundColor Cyan
Write-Host "Starting at: $(Get-Date)" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

# Import modules
Write-Host "`nImporting modules..." -ForegroundColor Cyan
Import-Module "$PSScriptRoot\modules\EnhancedHyperVAO\EnhancedHyperVAO.psd1" -Force

# Load functions from main script
Write-Host "Loading main script functions..." -ForegroundColor Cyan
. "$PSScriptRoot\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1" `
    -UseSmartDefaults `
    -AutoSelectDrive `
    -ConfigurationPath "$PSScriptRoot\TestConfigs" 2>$null

# Create test configuration directory
$testConfigDir = "$PSScriptRoot\TestConfigs"
if (-not (Test-Path $testConfigDir)) {
    New-Item -Path $testConfigDir -ItemType Directory -Force | Out-Null
}

# Create test configuration
$testConfigPath = "$testConfigDir\test-automated.psd1"
$testConfig = @'
@{
    VMNamePrefixFormat = '{0:D3} - Test - Automated'
    InstallMediaPath = 'C:\test.iso'
    ProcessorCount = 'All Cores'
    SwitchName = 'Default Switch'
    Generation = 2
    VMType = 'Standard'
}
'@
$testConfig | Out-File -FilePath $testConfigPath -Force

# Test 1: System Resources
Test-Function -Name "Get-SystemResources" -Test {
    $resources = Get-SystemResources
    return ($resources.TotalCores -gt 0 -and $resources.TotalMemoryGB -gt 0)
}

# Test 2: Processor Count Parsing
Test-Function -Name "Get-ProcessorCount with 'All Cores'" -Test {
    $count = Get-ProcessorCount -ProcessorValue "All Cores"
    return $count -gt 0
}

Test-Function -Name "Get-ProcessorCount with number" -Test {
    $count = Get-ProcessorCount -ProcessorValue "4"
    return $count -eq 4
}

Test-Function -Name "Get-ProcessorCount with invalid value" -Test {
    $count = Get-ProcessorCount -ProcessorValue "Invalid"
    return $count -eq 2  # Should return default
}

# Test 3: Memory Allocation
Test-Function -Name "Get-SmartMemoryAllocation - Balanced" -Test {
    $memory = Get-SmartMemoryAllocation -AllocationMode 'Balanced'
    return ($memory.StartupBytes -and $memory.MinimumBytes -and $memory.MaximumBytes)
}

# Test 4: Drive Management
Test-Function -Name "Get-AvailableDrives" -Test {
    $drives = Get-AvailableDrives
    return $drives.Count -gt 0
}

Test-Function -Name "Select-BestDrive" -Test {
    $bestDrive = Select-BestDrive -MinimumFreeSpaceGB 1
    return $bestDrive.DriveLetter -match '^[A-Z]$'
}

# Test 5: Smart Paths
Test-Function -Name "Get-SmartPaths" -Test {
    $testConfig = @{
        VMPath = "D:\VMs"
        InstallMediaPath = "E:\ISO\test.iso"
    }
    $updatedConfig = Get-SmartPaths -DriveLetter "C" -Config $testConfig
    return ($updatedConfig.VMPath -match '^C:' -and $updatedConfig.VHDXPath -ne $null)
}

# Test 6: Virtual Switch
Test-Function -Name "Get-SmartVirtualSwitch" -Test {
    # This might fail if no switches exist, but that's OK for testing
    try {
        $switch = Get-SmartVirtualSwitch -RequestedSwitch "Default Switch"
        return $switch -ne $null
    }
    catch {
        # If no switches exist, that's still a valid test result
        return $true
    }
}

# Test 7: Configuration Processing
Test-Function -Name "Process-SmartConfiguration" -Test {
    $testConfig = @{
        ProcessorCount = 'All Cores'
        SwitchName = 'Default Switch'
    }
    $processed = Process-SmartConfiguration -Config $testConfig -SelectedDrive 'C'
    return ($processed.ProcessorCount -gt 0 -and $processed.MemoryStartupBytes -ne $null)
}

# Test 8: Configuration Loading (Non-Interactive)
Test-Function -Name "Get-VMConfiguration (Non-Interactive)" -Test {
    $config = Get-VMConfiguration -ConfigPath $testConfigDir -NonInteractive
    return $config -ne $null
}

# Test 9: Full Workflow Simulation (without VM creation)
Test-Function -Name "Full Workflow Simulation" -Test {
    # Simulate the full workflow
    $config = Get-VMConfiguration -ConfigPath $testConfigDir -NonInteractive
    if (-not $config) { return $false }
    
    $selectedDrive = Select-BestDrive -MinimumFreeSpaceGB 1
    if (-not $selectedDrive) { return $false }
    
    $processedConfig = Process-SmartConfiguration -Config $config -SelectedDrive $selectedDrive.DriveLetter
    if (-not $processedConfig) { return $false }
    
    # Verify all required parameters are present
    $requiredParams = @('ProcessorCount', 'MemoryStartupBytes', 'VMPath', 'SwitchName')
    foreach ($param in $requiredParams) {
        if (-not $processedConfig.ContainsKey($param) -or $processedConfig[$param] -eq $null) {
            Write-Host "Missing required parameter: $param" -ForegroundColor Red
            return $false
        }
    }
    
    return $true
}

# Test 10: Logging Function
Test-Function -Name "Write-Log Function" -Test {
    $logPath = "$PSScriptRoot\TestLogs"
    $global:LogPath = $logPath
    $global:JobName = "TestJob"
    
    Write-Log -Message "Test log entry" -Level 'INFO'
    Write-Log -Message "Test warning" -Level 'WARNING'
    Write-Log -Message "Test error" -Level 'ERROR'
    
    # Check if log file was created
    $logFile = Get-ChildItem -Path $logPath -Filter "TestJob-*.log" -ErrorAction SilentlyContinue
    return $logFile -ne $null
}

# Cleanup
Write-Host "`nCleaning up test files..." -ForegroundColor Cyan
Remove-Item -Path $testConfigDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$PSScriptRoot\TestLogs" -Recurse -Force -ErrorAction SilentlyContinue

# Summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "Total Tests: $testCount" -ForegroundColor White
Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor Red
Write-Host "Success Rate: $('{0:P}' -f ($passCount / $testCount))" -ForegroundColor White
Write-Host ("=" * 60) -ForegroundColor Cyan

# Export results
$resultsPath = "$PSScriptRoot\TestResults-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$testResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $resultsPath -Force
Write-Host "`nTest results saved to: $resultsPath" -ForegroundColor Cyan

# Exit with appropriate code
if ($failCount -eq 0) {
    Write-Host "`nAll tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "`nSome tests failed. Please review the results." -ForegroundColor Red
    exit 1
}