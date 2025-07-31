#Requires -Version 5.1
#Requires -RunAsAdministrator
#Requires -Module Hyper-V

<#
.SYNOPSIS
    Tests the multi-NIC VM creation feature.

.DESCRIPTION
    This script tests creating VMs with multiple network interfaces.
#>

Write-Host "`n=== Testing Multi-NIC VM Creation ===" -ForegroundColor Cyan

# First, check available virtual switches
Write-Host "`nChecking available virtual switches..." -ForegroundColor Yellow
$switches = Get-VMSwitch | Select-Object Name, SwitchType, NetAdapterInterfaceDescription

if ($switches.Count -eq 0) {
    Write-Host "ERROR: No virtual switches found!" -ForegroundColor Red
    Write-Host "Please create at least one virtual switch before testing." -ForegroundColor Yellow
    return
}

Write-Host "Found $($switches.Count) virtual switch(es):" -ForegroundColor Green
foreach ($switch in $switches) {
    Write-Host "  - $($switch.Name) ($($switch.SwitchType))" -ForegroundColor White
}

# Create test configuration with multi-NIC enabled
$testConfig = @"
@{
    # VM Type
    VMType               = "Standard"  # Use standard disk for quick testing
    
    # Network - Enable multi-NIC
    SwitchName           = "Default Switch"  # Primary NIC
    UseAllAvailableSwitches = `$true  # Add all available switches as NICs
    
    # Basic settings
    VMNamePrefixFormat   = "{0:D3} - TEST - Multi-NIC"
    VMPath               = "D:\VM"
    InstallMediaPath     = "D:\VM\Setup\ISO\Win11_24H2_English_x64_Oct16_2024.iso"
    
    # Memory
    MemoryStartupBytes   = "2GB"
    MemoryMinimumBytes   = "1GB"
    MemoryMaximumBytes   = "4GB"
    
    # Other settings
    Generation           = 2
    ProcessorCount       = 2
    AutoStartVM          = `$false
    AutoConnectVM        = `$false
}
"@

$configPath = "D:\Code\HyperV\2-Create-HyperV_VM\Latest\test-multi-nic-config.psd1"
Set-Content -Path $configPath -Value $testConfig

Write-Host "`nTest configuration created with:" -ForegroundColor Yellow
Write-Host "  - Primary switch: Default Switch" -ForegroundColor White
Write-Host "  - UseAllAvailableSwitches: True" -ForegroundColor Green

# Option 1: Test with smart defaults (automatic)
Write-Host "`n[1] Test with smart defaults (automatic)" -ForegroundColor Cyan
Write-Host "[2] Test with interactive mode" -ForegroundColor Cyan
Write-Host "[3] Skip test" -ForegroundColor Cyan

$choice = Read-Host "`nSelect test mode (1-3)"

if ($choice -eq "3") {
    Write-Host "Test skipped" -ForegroundColor Yellow
    Remove-Item -Path $configPath -Force
    return
}

try {
    Write-Host "`nRunning VM creation script..." -ForegroundColor Yellow
    
    if ($choice -eq "1") {
        # Run with smart defaults
        & "D:\Code\HyperV\2-Create-HyperV_VM\Latest\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1" `
            -ConfigurationPath (Split-Path $configPath -Parent) `
            -UseSmartDefaults `
            -AutoSelectDrive
    }
    else {
        # Run interactively
        & "D:\Code\HyperV\2-Create-HyperV_VM\Latest\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1" `
            -ConfigurationPath (Split-Path $configPath -Parent)
    }
    
    # Check results
    Start-Sleep -Seconds 3
    $testVMs = Get-VM | Where-Object { $_.Name -like "*TEST - Multi-NIC*" } | Sort-Object Name -Descending
    
    if ($testVMs.Count -gt 0) {
        $vm = $testVMs[0]
        Write-Host "`n=== Test Results ===" -ForegroundColor Cyan
        Write-Host "VM Created: $($vm.Name)" -ForegroundColor Green
        
        # Check network adapters
        $nics = Get-VMNetworkAdapter -VMName $vm.Name
        Write-Host "`nNetwork Adapters: $($nics.Count)" -ForegroundColor Yellow
        
        $nicNum = 1
        foreach ($nic in $nics) {
            Write-Host "`nNIC $nicNum:" -ForegroundColor White
            Write-Host "  Name: $($nic.Name)" -ForegroundColor Gray
            Write-Host "  Switch: $($nic.SwitchName)" -ForegroundColor Gray
            Write-Host "  Status: $($nic.Status)" -ForegroundColor Gray
            if ($nic.MacAddress) {
                Write-Host "  MAC: $($nic.MacAddress)" -ForegroundColor Gray
            }
            $nicNum++
        }
        
        # Success check
        if ($nics.Count -gt 1) {
            Write-Host "`nSUCCESS: Multi-NIC configuration working!" -ForegroundColor Green
            Write-Host "VM has $($nics.Count) network adapters connected to different switches." -ForegroundColor Green
        }
        else {
            Write-Host "`nWARNING: VM only has $($nics.Count) network adapter(s)" -ForegroundColor Yellow
            Write-Host "Multi-NIC feature may not have worked as expected." -ForegroundColor Yellow
        }
        
        # Cleanup
        Write-Host "`nDo you want to remove the test VM? (Y/N)" -ForegroundColor Yellow
        $cleanup = Read-Host
        if ($cleanup -eq 'Y') {
            Remove-VM -Name $vm.Name -Force
            $vmPath = Split-Path $vm.Path -Parent
            Remove-Item -Path $vmPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Test VM removed" -ForegroundColor Green
        }
    }
    else {
        Write-Host "`nERROR: No test VM found!" -ForegroundColor Red
    }
}
catch {
    Write-Host "`nERROR during test: $_" -ForegroundColor Red
}
finally {
    # Cleanup config
    if (Test-Path $configPath) {
        Remove-Item -Path $configPath -Force
    }
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan