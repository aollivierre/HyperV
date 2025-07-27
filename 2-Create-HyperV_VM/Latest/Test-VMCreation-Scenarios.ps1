#requires -RunAsAdministrator
#requires -Module Hyper-V

<#
.SYNOPSIS
    Test script to validate VM creation scenarios
.DESCRIPTION
    Tests the following scenarios:
    1. VM creation with missing ISO path (user skips)
    2. VM creation with differencing disk
    3. VM creation with new disk
    4. Single drive system handling
#>

param(
    [Parameter()]
    [ValidateSet('All', 'MissingISO', 'Differencing', 'NewDisk')]
    [string]$TestScenario = 'All',
    
    [Parameter()]
    [switch]$Cleanup
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot "2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1"

# Test configurations
$testConfigs = @{
    MissingISO = @{
        Name = "Test-MissingISO"
        ConfigContent = @'
@{
    VMType               = "Standard"
    VMNamePrefixFormat   = "{0:D3} - TEST - Missing ISO"
    InstallMediaPath     = "C:\NonExistent\ISO\Windows.iso"  # This won't exist
    ProcessorCount       = "2"
    SwitchName          = "Default Switch"
    MemoryStartupBytes   = "1GB"
    MemoryMinimumBytes   = "512MB"
    MemoryMaximumBytes   = "2GB"
    Generation           = 2
    AutoStartVM          = $false
    AutoConnectVM        = $false
}
'@
    }
    
    Differencing = @{
        Name = "Test-Differencing"
        ConfigContent = @'
@{
    VMType               = "Differencing"
    VMNamePrefixFormat   = "{0:D3} - TEST - Differencing Disk"
    ParentVHDXPath       = "D:\VM\Setup\VHDX\Win11_24H2_English_x64_Oct16_2024-100GB.VHDX"
    InstallMediaPath     = "D:\VM\Setup\ISO\Win11_24H2_English_x64_Oct16_2024.iso"
    ProcessorCount       = "2"
    SwitchName          = "Default Switch"
    MemoryStartupBytes   = "2GB"
    MemoryMinimumBytes   = "1GB"
    MemoryMaximumBytes   = "4GB"
    Generation           = 2
    AutoStartVM          = $false
    AutoConnectVM        = $false
}
'@
    }
    
    NewDisk = @{
        Name = "Test-NewDisk"
        ConfigContent = @'
@{
    VMType               = "Standard"
    VMNamePrefixFormat   = "{0:D3} - TEST - New Disk"
    InstallMediaPath     = "D:\VM\Setup\ISO\Win11_24H2_English_x64_Oct16_2024.iso"
    ProcessorCount       = "2"
    SwitchName          = "Default Switch"
    MemoryStartupBytes   = "2GB"
    MemoryMinimumBytes   = "1GB"
    MemoryMaximumBytes   = "4GB"
    Generation           = 2
    AutoStartVM          = $false
    AutoConnectVM        = $false
}
'@
    }
}

function Write-TestHeader {
    param([string]$TestName)
    Write-Host "`n" -NoNewline
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "TEST: $TestName" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
}

function Test-VMCreationScenario {
    param(
        [string]$ScenarioName,
        [hashtable]$Config
    )
    
    Write-TestHeader $ScenarioName
    
    try {
        # Create temporary config file
        $tempConfigPath = Join-Path $env:TEMP "test-config-$(Get-Random).psd1"
        $Config.ConfigContent | Out-File -FilePath $tempConfigPath -Encoding UTF8
        
        Write-Host "Created test config at: $tempConfigPath" -ForegroundColor Yellow
        
        # Run the script with the test config
        $scriptParams = @{
            ConfigurationPath = Split-Path $tempConfigPath -Parent
            UseSmartDefaults = $true
        }
        
        Write-Host "Running VM creation script..." -ForegroundColor Yellow
        & $scriptPath @scriptParams
        
        # Verify VM was created
        $vmPattern = "*TEST*"
        $createdVM = Get-VM | Where-Object { $_.Name -like $vmPattern } | Select-Object -First 1
        
        if ($createdVM) {
            Write-Host "`nSUCCESS: VM created: $($createdVM.Name)" -ForegroundColor Green
            Write-Host "State: $($createdVM.State)" -ForegroundColor Green
            Write-Host "ProcessorCount: $($createdVM.ProcessorCount)" -ForegroundColor Green
            Write-Host "Memory: $($createdVM.MemoryStartup / 1GB)GB" -ForegroundColor Green
            
            # Check for hard disk
            $vhd = Get-VMHardDiskDrive -VMName $createdVM.Name
            if ($vhd) {
                Write-Host "Hard Disk: $($vhd.Path)" -ForegroundColor Green
                $vhdInfo = Get-VHD -Path $vhd.Path
                Write-Host "Disk Type: $($vhdInfo.VhdType)" -ForegroundColor Green
                if ($vhdInfo.ParentPath) {
                    Write-Host "Parent Disk: $($vhdInfo.ParentPath)" -ForegroundColor Green
                }
            }
            
            # Cleanup if requested
            if ($Cleanup) {
                Write-Host "`nCleaning up test VM..." -ForegroundColor Yellow
                Stop-VM -Name $createdVM.Name -Force -ErrorAction SilentlyContinue
                Remove-VM -Name $createdVM.Name -Force
                if ($vhd -and (Test-Path $vhd.Path)) {
                    Remove-Item -Path $vhd.Path -Force
                }
                $vmFolder = Split-Path $vhd.Path -Parent
                if (Test-Path $vmFolder) {
                    Remove-Item -Path $vmFolder -Recurse -Force
                }
            }
        }
        else {
            Write-Host "`nFAILED: No VM created!" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "`nERROR in test: $_" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
    }
    finally {
        # Cleanup temp config
        if (Test-Path $tempConfigPath) {
            Remove-Item -Path $tempConfigPath -Force
        }
    }
}

# Main test execution
Write-Host "Starting VM Creation Tests" -ForegroundColor Cyan
Write-Host "Script Path: $scriptPath" -ForegroundColor Cyan

# Verify script exists
if (-not (Test-Path $scriptPath)) {
    throw "VM creation script not found at: $scriptPath"
}

# Run tests based on scenario
switch ($TestScenario) {
    'All' {
        foreach ($scenario in $testConfigs.GetEnumerator()) {
            Test-VMCreationScenario -ScenarioName $scenario.Key -Config $scenario.Value
        }
    }
    default {
        if ($testConfigs.ContainsKey($TestScenario)) {
            Test-VMCreationScenario -ScenarioName $TestScenario -Config $testConfigs[$TestScenario]
        }
        else {
            throw "Unknown test scenario: $TestScenario"
        }
    }
}

Write-Host "`n" -NoNewline
Write-Host ("=" * 60) -ForegroundColor Green
Write-Host "TEST EXECUTION COMPLETE" -ForegroundColor Green
Write-Host ("=" * 60) -ForegroundColor Green