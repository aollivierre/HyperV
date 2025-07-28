#Requires -Version 5.1
#Requires -RunAsAdministrator
#Requires -Module Hyper-V

<#
.SYNOPSIS
    Tests the dual disk feature for Hyper-V VM creation.

.DESCRIPTION
    This script tests the new dual disk feature by:
    1. Creating a parent data disk if it doesn't exist
    2. Creating a test VM with dual disks
    3. Validating the VM has both disks attached
    4. Checking that both disks are differencing disks

.EXAMPLE
    .\Test-DualDiskFeature.ps1
#>

[CmdletBinding()]
param()

# Configuration
$TestVMName = "TEST-DualDisk-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$DataDiskParentPath = "D:\VM\Setup\VHDX\DataDiskParent_256GB.vhdx"
$TestConfigPath = "D:\Code\HyperV\2-Create-HyperV_VM\Latest\test-dual-disk-config.psd1"

Write-Host "`n=== Testing Dual Disk Feature ===" -ForegroundColor Cyan

try {
    # Step 1: Check if parent data disk exists
    Write-Host "`n[1] Checking parent data disk..." -ForegroundColor Yellow
    if (-not (Test-Path $DataDiskParentPath)) {
        Write-Host "Parent data disk not found. Creating it now..." -ForegroundColor White
        
        # Create parent disk
        & "D:\Code\HyperV\2-Create-HyperV_VM\Latest\Create-DataDiskParent.ps1" -Path $DataDiskParentPath
        
        if (-not (Test-Path $DataDiskParentPath)) {
            throw "Failed to create parent data disk"
        }
    }
    else {
        Write-Host "Parent data disk found: $DataDiskParentPath" -ForegroundColor Green
    }
    
    # Step 2: Create test configuration
    Write-Host "`n[2] Creating test configuration..." -ForegroundColor Yellow
    
    $testConfig = @'
@{
    # VM Name
    VMNamePrefixFormat   = "{0:D3} - TEST - Dual Disk Feature"
    
    # Primary OS Disk Configuration
    VMType               = "Standard"   # Create new OS disk for testing
    
    # Data Disk Configuration (TESTING NEW FEATURE)
    EnableDataDisk       = $true
    DataDiskType         = "Differencing"
    DataDiskSize         = 256GB
    DataDiskParentPath   = "D:\VM\Setup\VHDX\DataDiskParent_256GB.vhdx"
    
    # ISO for OS installation
    InstallMediaPath     = "D:\VM\Setup\ISO\Win11_24H2_English_x64_Oct16_2024.iso"
    
    # Smart defaults
    ProcessorCount       = 2
    SwitchName          = "Default Switch"
    
    # Memory configuration
    MemoryStartupBytes   = "2GB"
    MemoryMinimumBytes   = "1GB"
    MemoryMaximumBytes   = "4GB"
    
    # Advanced options
    UseAllAvailableSwitches = $false
    AutoStartVM          = $false
    AutoConnectVM        = $false
}
'@
    
    Set-Content -Path $TestConfigPath -Value $testConfig
    Write-Host "Test configuration created" -ForegroundColor Green
    
    # Step 3: Run VM creation script
    Write-Host "`n[3] Creating test VM with dual disks..." -ForegroundColor Yellow
    
    # Import the test config to get the next VM number
    $config = Import-PowerShellDataFile -Path $TestConfigPath
    
    # Run the main script
    & "D:\Code\HyperV\2-Create-HyperV_VM\Latest\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1" `
        -ConfigurationPath (Split-Path $TestConfigPath -Parent) `
        -UseSmartDefaults `
        -AutoSelectDrive
    
    # Get the actual VM name (with number prefix)
    $createdVMs = Get-VM | Where-Object { $_.Name -like "*TEST - Dual Disk Feature*" } | Sort-Object Name -Descending
    if ($createdVMs.Count -eq 0) {
        throw "No test VM found after creation"
    }
    
    $actualVMName = $createdVMs[0].Name
    Write-Host "`nTest VM created: $actualVMName" -ForegroundColor Green
    
    # Step 4: Validate VM has two disks
    Write-Host "`n[4] Validating VM disk configuration..." -ForegroundColor Yellow
    
    $vm = Get-VM -Name $actualVMName
    $hardDrives = Get-VMHardDiskDrive -VMName $actualVMName
    
    Write-Host "Found $($hardDrives.Count) hard drives attached to VM" -ForegroundColor White
    
    if ($hardDrives.Count -lt 2) {
        throw "Expected 2 hard drives, but found $($hardDrives.Count)"
    }
    
    # Display disk information
    foreach ($drive in $hardDrives) {
        Write-Host "`nDisk $($drive.ControllerLocation):" -ForegroundColor Yellow
        Write-Host "  Controller: $($drive.ControllerType)" -ForegroundColor White
        Write-Host "  Path: $($drive.Path)" -ForegroundColor White
        
        if (Test-Path $drive.Path) {
            $vhd = Get-VHD -Path $drive.Path
            Write-Host "  Type: $($vhd.VhdType)" -ForegroundColor White
            Write-Host "  Size: $([math]::Round($vhd.Size/1GB, 2)) GB" -ForegroundColor White
            
            if ($vhd.ParentPath) {
                Write-Host "  Parent: $(Split-Path $vhd.ParentPath -Leaf)" -ForegroundColor Green
                Write-Host "  Is Differencing: Yes" -ForegroundColor Green
            }
            else {
                Write-Host "  Is Differencing: No" -ForegroundColor White
            }
        }
    }
    
    # Step 5: Validate data disk is differencing
    Write-Host "`n[5] Validating data disk is differencing..." -ForegroundColor Yellow
    
    $dataDisk = $hardDrives | Where-Object { $_.Path -like "*DataDisk*" }
    if (-not $dataDisk) {
        throw "Data disk not found"
    }
    
    $dataVHD = Get-VHD -Path $dataDisk.Path
    if ($dataVHD.VhdType -ne 'Differencing') {
        throw "Data disk is not a differencing disk"
    }
    
    if ($dataVHD.ParentPath -ne $DataDiskParentPath) {
        throw "Data disk parent path mismatch. Expected: $DataDiskParentPath, Actual: $($dataVHD.ParentPath)"
    }
    
    Write-Host "Data disk validation successful!" -ForegroundColor Green
    
    # Success summary
    Write-Host "`n=== Test Results ===" -ForegroundColor Green
    Write-Host "✓ Parent data disk exists" -ForegroundColor Green
    Write-Host "✓ VM created successfully" -ForegroundColor Green
    Write-Host "✓ VM has 2 disks attached" -ForegroundColor Green
    Write-Host "✓ Data disk is differencing type" -ForegroundColor Green
    Write-Host "✓ Data disk has correct parent" -ForegroundColor Green
    Write-Host "`nDual disk feature is working correctly!" -ForegroundColor Green
    
    # Cleanup option
    Write-Host "`n=== Cleanup ===" -ForegroundColor Yellow
    $cleanup = Read-Host "Do you want to remove the test VM? (Y/N)"
    if ($cleanup -eq 'Y') {
        Write-Host "Removing test VM..." -ForegroundColor White
        Remove-VM -Name $actualVMName -Force
        
        # Remove VM files
        $vmPath = Split-Path $vm.Path -Parent
        if (Test-Path $vmPath) {
            Remove-Item -Path $vmPath -Recurse -Force
        }
        
        Write-Host "Test VM removed" -ForegroundColor Green
    }
}
catch {
    Write-Host "`n=== Test Failed ===" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
}
finally {
    # Cleanup test config
    if (Test-Path $TestConfigPath) {
        Remove-Item -Path $TestConfigPath -Force
    }
}