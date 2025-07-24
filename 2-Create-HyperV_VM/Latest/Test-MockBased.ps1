#requires -Version 5.1

<#
.SYNOPSIS
    Mock-based tests that don't require Hyper-V infrastructure.

.DESCRIPTION
    Tests core logic using mocked data without requiring admin rights or Hyper-V.
#>

[CmdletBinding()]
param()

Write-Host "=== Mock-Based Testing (No Hyper-V Required) ===" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

# Define all functions inline for isolated testing
function Write-Log {
    param($Message, $Level = 'INFO')
    Write-Host "[$Level] $Message"
}

function Get-ProcessorCount {
    param($ProcessorValue)
    
    if ($ProcessorValue -eq "All Cores" -or $ProcessorValue -eq "All") {
        # Mock system with 8 cores
        Write-Log -Message "Using all available cores: 8" -Level 'INFO'
        return 8
    }
    elseif ($ProcessorValue -match '^\d+$') {
        return [int]$ProcessorValue
    }
    else {
        Write-Log -Message "Invalid processor value: $ProcessorValue. Using 2 cores as default." -Level 'WARNING'
        return 2
    }
}

function Get-SmartMemoryAllocation {
    param(
        [string]$RequestedMemory,
        [string]$AllocationMode = 'Balanced'
    )
    
    # Mock available memory as 16GB
    $availableGB = 16
    
    switch ($AllocationMode) {
        'Minimum' {
            $startupGB = 2
            $minimumGB = 1
            $maximumGB = 8
        }
        'Balanced' {
            $startupGB = 4
            $minimumGB = 2
            $maximumGB = 16
        }
        'Maximum' {
            $startupGB = 8
            $minimumGB = 4
            $maximumGB = 16
        }
    }
    
    Write-Log -Message "Smart memory allocation: Startup=${startupGB}GB, Min=${minimumGB}GB, Max=${maximumGB}GB" -Level 'INFO'
    
    return @{
        StartupBytes = "${startupGB}GB"
        MinimumBytes = "${minimumGB}GB"
        MaximumBytes = "${maximumGB}GB"
    }
}

function Get-SmartPaths {
    param(
        [string]$DriveLetter,
        [hashtable]$Config = @{}
    )
    
    Write-Log -Message "Creating smart paths for drive $DriveLetter" -Level 'INFO'
    
    $smartPaths = @{
        VMPath = "${DriveLetter}:\VMs"
        VHDXPath = "${DriveLetter}:\VMs\Templates"
        ISOPath = "${DriveLetter}:\VMs\ISOs"
        ExportPath = "${DriveLetter}:\VMs\Exports"
        CheckpointPath = "${DriveLetter}:\VMs\Checkpoints"
    }
    
    # Create a copy of keys to avoid modification during enumeration
    $configKeys = @($Config.Keys)
    foreach ($key in $configKeys) {
        if ($Config[$key] -and $Config[$key] -ne "") {
            if ($key -match 'Path$' -and $Config[$key] -match '^[A-Za-z]:') {
                $Config[$key] = $Config[$key] -replace '^[A-Za-z]:', "${DriveLetter}:"
            }
        }
    }
    
    # Add smart paths for missing values
    $smartPathKeys = @($smartPaths.Keys)
    foreach ($key in $smartPathKeys) {
        if (-not $Config.ContainsKey($key) -or [string]::IsNullOrEmpty($Config[$key])) {
            $Config[$key] = $smartPaths[$key]
        }
    }
    
    return $Config
}

function Process-SmartConfiguration {
    param(
        [hashtable]$Config,
        [string]$SelectedDrive
    )
    
    Write-Log -Message "Processing configuration with smart defaults..." -Level 'INFO'
    
    # Process processor count
    if ($Config.ContainsKey('ProcessorCount')) {
        $Config.ProcessorCount = Get-ProcessorCount -ProcessorValue $Config.ProcessorCount
    }
    else {
        $Config.ProcessorCount = 4  # Default to 4 cores
    }
    
    # Process memory settings
    if (-not $Config.ContainsKey('MemoryStartupBytes')) {
        $memorySettings = Get-SmartMemoryAllocation -AllocationMode 'Balanced'
        $Config.MemoryStartupBytes = $memorySettings.StartupBytes
        $Config.MemoryMinimumBytes = $memorySettings.MinimumBytes
        $Config.MemoryMaximumBytes = $memorySettings.MaximumBytes
    }
    
    # Process network switch
    if (-not $Config.ContainsKey('SwitchName') -or $Config.SwitchName -eq "Default Switch") {
        $Config.SwitchName = "Default Switch"
    }
    
    # Apply smart paths
    $Config = Get-SmartPaths -DriveLetter $SelectedDrive -Config $Config
    
    # Set other smart defaults
    if (-not $Config.ContainsKey('Generation')) {
        $Config.Generation = 2
    }
    
    if (-not $Config.ContainsKey('EnableDynamicMemory')) {
        $Config.EnableDynamicMemory = $true
    }
    
    if (-not $Config.ContainsKey('EnableVirtualizationExtensions')) {
        $Config.EnableVirtualizationExtensions = $false
    }
    
    if (-not $Config.ContainsKey('IncludeTPM')) {
        $Config.IncludeTPM = ($Config.Generation -eq 2)
    }
    
    return $Config
}

# Run Tests
$testsPassed = 0
$testsFailed = 0

function Run-Test {
    param(
        [string]$TestName,
        [scriptblock]$Test,
        [object]$Expected
    )
    
    Write-Host "`nTest: $TestName" -ForegroundColor Yellow
    try {
        $result = & $Test
        if ($null -eq $Expected) {
            Write-Host "[PASS] Result: $result" -ForegroundColor Green
            $script:testsPassed++
        }
        elseif ($result -eq $Expected) {
            Write-Host "[PASS] Result matches expected: $Expected" -ForegroundColor Green
            $script:testsPassed++
        }
        else {
            Write-Host "[FAIL] Expected: $Expected, Got: $result" -ForegroundColor Red
            $script:testsFailed++
        }
    }
    catch {
        Write-Host "[FAIL] Error: $_" -ForegroundColor Red
        $script:testsFailed++
    }
}

# Test 1: Processor Count
Run-Test -TestName "Get-ProcessorCount with 'All Cores'" -Test {
    Get-ProcessorCount -ProcessorValue "All Cores"
} -Expected 8

Run-Test -TestName "Get-ProcessorCount with number '4'" -Test {
    Get-ProcessorCount -ProcessorValue "4"
} -Expected 4

Run-Test -TestName "Get-ProcessorCount with invalid value" -Test {
    Get-ProcessorCount -ProcessorValue "Invalid"
} -Expected 2

# Test 2: Memory Allocation
Run-Test -TestName "Get-SmartMemoryAllocation - Balanced" -Test {
    $memory = Get-SmartMemoryAllocation -AllocationMode 'Balanced'
    return ($memory.StartupBytes -eq "4GB")
} -Expected $true

Run-Test -TestName "Get-SmartMemoryAllocation - Minimum" -Test {
    $memory = Get-SmartMemoryAllocation -AllocationMode 'Minimum'
    return ($memory.StartupBytes -eq "2GB")
} -Expected $true

# Test 3: Smart Paths
Run-Test -TestName "Get-SmartPaths creates standard structure" -Test {
    $config = @{ VMPath = "D:\Custom\VMs" }
    $updated = Get-SmartPaths -DriveLetter "C" -Config $config
    return ($updated.VMPath -eq "C:\Custom\VMs" -and $updated.VHDXPath -eq "C:\VMs\Templates")
} -Expected $true

# Test 4: Process Configuration
Run-Test -TestName "Process-SmartConfiguration with minimal config" -Test {
    $config = @{
        ProcessorCount = 'All Cores'
        SwitchName = 'Default Switch'
    }
    $processed = Process-SmartConfiguration -Config $config -SelectedDrive 'C'
    return ($processed.ProcessorCount -eq 8 -and 
            $processed.MemoryStartupBytes -eq "4GB" -and
            $processed.VMPath -eq "C:\VMs" -and
            $processed.Generation -eq 2)
} -Expected $true

# Test 5: Configuration Update
Run-Test -TestName "Configuration preserves existing values" -Test {
    $config = @{
        ProcessorCount = '2'
        MemoryStartupBytes = '8GB'
        VMPath = 'E:\MyVMs'
        Generation = 1
    }
    $processed = Process-SmartConfiguration -Config $config -SelectedDrive 'C'
    return ($processed.ProcessorCount -eq 2 -and 
            $processed.MemoryStartupBytes -eq "8GB" -and
            $processed.VMPath -eq "C:\MyVMs" -and
            $processed.Generation -eq 1)
} -Expected $true

# Summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "MOCK TEST SUMMARY" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Total Tests: $($testsPassed + $testsFailed)" -ForegroundColor White
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor Red

if ($testsFailed -eq 0) {
    Write-Host "`nAll mock tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "`nSome tests failed!" -ForegroundColor Red
    exit 1
}