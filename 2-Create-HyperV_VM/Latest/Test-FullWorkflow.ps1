#Requires -Version 5.1
#Requires -RunAsAdministrator
#Requires -Module Hyper-V

<#
.SYNOPSIS
    Tests the complete VM creation workflow including error handling and ISO conversion.

.DESCRIPTION
    This script tests:
    1. Missing parent VHDX handling
    2. ISO to VHDX conversion option
    3. Missing data disk parent handling
    4. Full dual disk VM creation

.EXAMPLE
    .\Test-FullWorkflow.ps1
#>

[CmdletBinding()]
param()

Write-Host "`n=== Testing Complete VM Creation Workflow ===" -ForegroundColor Cyan
Write-Host "This test will validate all new features including error handling" -ForegroundColor Yellow

# Test configuration
$testConfig = @{
    ConfigPath = "D:\Code\HyperV\2-Create-HyperV_VM\Latest\test-workflow-config.psd1"
    ParentVHDX = "D:\VM\Setup\VHDX\Test-Parent-$(Get-Date -Format 'yyyyMMdd-HHmmss').vhdx"
    DataParent = "D:\VM\Setup\VHDX\Test-DataParent-$(Get-Date -Format 'yyyyMMdd-HHmmss').vhdx"
    TestISO = "D:\VM\Setup\ISO\Win11_24H2_English_x64_Oct16_2024.iso"
}

# Function to create test configuration
function Create-TestConfig {
    param($ParentPath, $DataParentPath)
    
    $configContent = @"
@{
    # VM Name
    VMNamePrefixFormat   = "{0:D3} - TEST - Full Workflow"
    
    # Primary OS Disk - Using non-existent parent to test error handling
    VMType               = "Differencing"
    ParentVHDXPath       = "$ParentPath"
    
    # Data Disk Configuration - Also non-existent to test auto-creation
    EnableDataDisk       = `$true
    DataDiskType         = "Differencing"
    DataDiskSize         = 256GB
    DataDiskParentPath   = "$DataParentPath"
    
    # ISO for conversion test
    InstallMediaPath     = "$($testConfig.TestISO)"
    
    # Smart defaults
    ProcessorCount       = 2
    SwitchName          = "Default Switch"
    
    # Memory configuration
    MemoryStartupBytes   = "2GB"
    MemoryMinimumBytes   = "1GB"
    MemoryMaximumBytes   = "4GB"
    
    # Options
    AutoStartVM          = `$false
    AutoConnectVM        = `$false
}
"@
    
    Set-Content -Path $testConfig.ConfigPath -Value $configContent
}

try {
    # Step 1: Verify ISO exists
    Write-Host "`n[1] Checking for test ISO..." -ForegroundColor Yellow
    if (-not (Test-Path $testConfig.TestISO)) {
        Write-Host "ERROR: Test ISO not found at: $($testConfig.TestISO)" -ForegroundColor Red
        Write-Host "Please ensure you have a Windows ISO at this location for testing" -ForegroundColor Yellow
        return
    }
    Write-Host "ISO found: $(Split-Path $testConfig.TestISO -Leaf)" -ForegroundColor Green
    
    # Step 2: Verify conversion script exists
    Write-Host "`n[2] Checking for ISO conversion script..." -ForegroundColor Yellow
    $conversionScript = "D:\Code\HyperV\0-Convert-ISO-VHDX-WIM-PPKG-Injection\Create-VHDX-Working.ps1"
    if (-not (Test-Path $conversionScript)) {
        Write-Host "ERROR: Conversion script not found at: $conversionScript" -ForegroundColor Red
        Write-Host "The ISO to VHDX conversion feature won't be available" -ForegroundColor Yellow
    }
    else {
        Write-Host "Conversion script found" -ForegroundColor Green
    }
    
    # Step 3: Create test configuration with non-existent parents
    Write-Host "`n[3] Creating test configuration..." -ForegroundColor Yellow
    Create-TestConfig -ParentPath $testConfig.ParentVHDX -DataParentPath $testConfig.DataParent
    Write-Host "Test configuration created" -ForegroundColor Green
    
    # Step 4: Show what we're testing
    Write-Host "`n[4] Test Scenario:" -ForegroundColor Yellow
    Write-Host "  - Parent VHDX does NOT exist (will test error handling)" -ForegroundColor White
    Write-Host "  - Data disk parent does NOT exist (will test auto-creation)" -ForegroundColor White
    Write-Host "  - Dual disk feature is ENABLED" -ForegroundColor White
    
    # Step 5: Run the main script
    Write-Host "`n[5] Running VM creation script..." -ForegroundColor Yellow
    Write-Host "Note: This will be interactive. You'll need to make selections." -ForegroundColor Cyan
    Write-Host "`nSuggested responses for full test:" -ForegroundColor Yellow
    Write-Host "  1. When parent VHDX is missing, choose option [2] to convert ISO" -ForegroundColor White
    Write-Host "  2. Confirm the conversion when prompted" -ForegroundColor White
    Write-Host "  3. When data disk parent is missing, choose 'Y' to create it" -ForegroundColor White
    
    $response = Read-Host "`nReady to start? (Y/N)"
    if ($response -ne 'Y') {
        Write-Host "Test cancelled" -ForegroundColor Yellow
        return
    }
    
    # Import the test config to determine VM name
    $config = Import-PowerShellDataFile -Path $testConfig.ConfigPath
    
    # Run the main script (this will be interactive)
    & "D:\Code\HyperV\2-Create-HyperV_VM\Latest\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1" `
        -ConfigurationPath (Split-Path $testConfig.ConfigPath -Parent)
    
    # Step 6: Validate results
    Write-Host "`n[6] Validating results..." -ForegroundColor Yellow
    
    # Find the created VM
    $createdVMs = Get-VM | Where-Object { $_.Name -like "*TEST - Full Workflow*" } | Sort-Object Name -Descending
    if ($createdVMs.Count -eq 0) {
        Write-Host "ERROR: No test VM found" -ForegroundColor Red
        return
    }
    
    $vm = $createdVMs[0]
    Write-Host "Found VM: $($vm.Name)" -ForegroundColor Green
    
    # Check disks
    $disks = Get-VMHardDiskDrive -VMName $vm.Name
    Write-Host "`nDisk configuration:" -ForegroundColor Yellow
    Write-Host "  Number of disks: $($disks.Count)" -ForegroundColor $(if ($disks.Count -eq 2) { 'Green' } else { 'Red' })
    
    foreach ($disk in $disks) {
        Write-Host "`n  Disk $($disk.ControllerLocation):" -ForegroundColor White
        Write-Host "    Path: $($disk.Path)" -ForegroundColor Gray
        
        if (Test-Path $disk.Path) {
            $vhd = Get-VHD -Path $disk.Path
            Write-Host "    Type: $($vhd.VhdType)" -ForegroundColor Gray
            Write-Host "    Size: $([math]::Round($vhd.Size/1GB, 2)) GB" -ForegroundColor Gray
            if ($vhd.ParentPath) {
                Write-Host "    Parent: $(Split-Path $vhd.ParentPath -Leaf)" -ForegroundColor Green
            }
        }
    }
    
    # Check if parent VHDX was created
    if (Test-Path $testConfig.ParentVHDX) {
        Write-Host "`nParent VHDX created successfully from ISO conversion" -ForegroundColor Green
    }
    
    # Check if data parent was created
    if (Test-Path $testConfig.DataParent) {
        Write-Host "Data disk parent created successfully" -ForegroundColor Green
    }
    
    # Summary
    Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
    $success = $true
    
    if ($disks.Count -eq 2) {
        Write-Host "VM has dual disks" -ForegroundColor Green
    } else {
        Write-Host "VM does not have dual disks" -ForegroundColor Red
        $success = $false
    }
    
    if (Test-Path $testConfig.ParentVHDX) {
        Write-Host "Parent VHDX created from ISO" -ForegroundColor Green
    } else {
        Write-Host "Parent VHDX not created" -ForegroundColor Red
        $success = $false
    }
    
    if (Test-Path $testConfig.DataParent) {
        Write-Host "Data disk parent auto-created" -ForegroundColor Green
    } else {
        Write-Host "Data disk parent not created" -ForegroundColor Red
        $success = $false
    }
    
    if ($success) {
        Write-Host "`nAll features working correctly!" -ForegroundColor Green
    } else {
        Write-Host "`nSome features did not work as expected" -ForegroundColor Yellow
    }
    
    # Cleanup option
    Write-Host "`n=== Cleanup ===" -ForegroundColor Yellow
    $cleanup = Read-Host "Do you want to remove the test VM and files? (Y/N)"
    if ($cleanup -eq 'Y') {
        Write-Host "Cleaning up..." -ForegroundColor White
        
        # Remove VM
        if ($vm) {
            Remove-VM -Name $vm.Name -Force
            $vmPath = Split-Path $vm.Path -Parent
            if (Test-Path $vmPath) {
                Remove-Item -Path $vmPath -Recurse -Force
            }
        }
        
        # Remove test parent disks
        @($testConfig.ParentVHDX, $testConfig.DataParent) | ForEach-Object {
            if (Test-Path $_) {
                Remove-Item -Path $_ -Force
            }
        }
        
        Write-Host "Cleanup completed" -ForegroundColor Green
    }
}
catch {
    Write-Host "`n=== Test Failed ===" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
}
finally {
    # Always cleanup test config
    if (Test-Path $testConfig.ConfigPath) {
        Remove-Item -Path $testConfig.ConfigPath -Force
    }
}