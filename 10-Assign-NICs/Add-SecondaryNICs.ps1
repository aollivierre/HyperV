#requires -RunAsAdministrator
<#
.SYNOPSIS
    Adds secondary network adapters to all running Hyper-V virtual machines.

.DESCRIPTION
    This script adds a second virtual network interface card (NIC) to all running
    Hyper-V VMs. This is useful for migrating to a new subnet while maintaining
    connectivity throughout the process.

.NOTES
    File Name      : Add-SecondaryNICs.ps1
    Prerequisite   : Hyper-V Module, Administrator rights
    Created        : 2025-03-02

.EXAMPLE
    .\Add-SecondaryNICs.ps1
#>

# Check if the Hyper-V module is available
if (-not (Get-Module -ListAvailable -Name Hyper-V)) {
    Write-Error "The Hyper-V PowerShell module is not available. Please ensure Hyper-V is installed and you're running this on a Hyper-V host."
    exit 1
}

# Import the Hyper-V module
Import-Module Hyper-V

# Get running VMs
$runningVMs = Get-VM | Where-Object {$_.State -eq 'Running'}
if ($runningVMs.Count -eq 0) {
    Write-Warning "No running VMs found."
    exit 0
}

Write-Host "Found $($runningVMs.Count) running VM(s):" -ForegroundColor Green
$runningVMs | ForEach-Object { Write-Host " - $($_.Name)" }
Write-Host ""

# Get available virtual switches
$switches = Get-VMSwitch
if ($switches.Count -eq 0) {
    Write-Error "No virtual switches found. Please create a virtual switch before running this script."
    exit 1
}

Write-Host "Available virtual switches:" -ForegroundColor Green
$switches | Format-Table Name, SwitchType -AutoSize

# Ask for the switch to use
$switchName = Read-Host "Enter the virtual switch name to use for the new NICs"

# Validate switch name
if (-not ($switches | Where-Object {$_.Name -eq $switchName})) {
    Write-Error "Virtual switch '$switchName' not found. Please verify the name and try again."
    exit 1
}

# Display information about what's going to happen
Write-Host "`nReady to add new NICs to $($runningVMs.Count) VM(s) using switch '$switchName'" -ForegroundColor Yellow
Write-Host "After this process, you'll need to configure each new NIC inside the VMs with:" -ForegroundColor Yellow
Write-Host " - IP address in the 198.18.x.x range" -ForegroundColor Yellow 
Write-Host " - Subnet mask: 255.255.255.0" -ForegroundColor Yellow
Write-Host " - No default gateway needed on the second NIC" -ForegroundColor Yellow
Write-Host ""

$confirmation = Read-Host "Proceed? (Y/N)"
if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
    Write-Host "Operation cancelled."
    exit 0
}

# Add NICs to all running VMs
$results = @()
foreach ($vm in $runningVMs) {
    $vmName = $vm.Name
    Write-Host "Adding network adapter to VM: $vmName..." -NoNewline
    
    try {
        Add-VMNetworkAdapter -VMName $vmName -SwitchName $switchName -ErrorAction Stop
        Write-Host "Success!" -ForegroundColor Green
        $results += [PSCustomObject]@{
            VMName = $vmName
            Status = "Success"
            Error = $null
        }
    }
    catch {
        Write-Host "Failed!" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        $results += [PSCustomObject]@{
            VMName = $vmName
            Status = "Failed"
            Error = $_.Exception.Message
        }
    }
}

# Display summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize

# Verify all network adapters for running VMs
Write-Host "`n=== Network Adapters for Each Running VM ===" -ForegroundColor Cyan
Get-VM | Where-Object {$_.State -eq 'Running'} | ForEach-Object {
    Write-Host "`nVM: $($_.Name)" -ForegroundColor Cyan
    Get-VMNetworkAdapter -VMName $_.Name | Format-Table Name, SwitchName, MacAddress
}

Write-Host "`nNext Steps:" -ForegroundColor Green
Write-Host "1. Configure each new NIC inside the VMs with a static IP in the 198.18.x.x range"
Write-Host "2. Use these new IPs to connect to your VMs when you change your router subnet"
Write-Host "3. After migration is complete, you can remove the original NICs or reconfigure them"
