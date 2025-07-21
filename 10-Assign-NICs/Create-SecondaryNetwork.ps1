#requires -RunAsAdministrator
<#
.SYNOPSIS
    Creates a dedicated virtual switch and configures it for a secondary network.

.DESCRIPTION
    This script creates a new internal or private Hyper-V virtual switch and
    configures the corresponding host virtual adapter with a static IP address
    in the 198.18.1.x range.

.NOTES
    File Name      : Create-SecondaryNetwork.ps1
    Prerequisite   : Administrator rights, Hyper-V role
    Created        : 2025-03-02

.EXAMPLE
    .\Create-SecondaryNetwork.ps1
#>

# Import the Hyper-V module
if (-not (Get-Module -ListAvailable -Name Hyper-V)) {
    Write-Error "The Hyper-V PowerShell module is not available. Please ensure Hyper-V is installed."
    exit 1
}
Import-Module Hyper-V

# Set the base network information
$switchName = "SecondaryNetwork"
$subnetBase = "198.18.1"
$hostIP = 1  # Host will have 198.18.1.1
$subnetMask = "255.255.255.0"
$cidrPrefix = 24  # /24 network

# Check if the switch already exists
$existingSwitch = Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue
if ($existingSwitch) {
    Write-Host "A virtual switch named '$switchName' already exists." -ForegroundColor Yellow
    $replaceSwitch = Read-Host "Do you want to remove and recreate it? (Y/N)"
    if ($replaceSwitch -eq 'Y' -or $replaceSwitch -eq 'y') {
        Write-Host "Removing existing switch '$switchName'..." -ForegroundColor Cyan
        Remove-VMSwitch -Name $switchName -Force
    } else {
        Write-Host "Using existing switch '$switchName'." -ForegroundColor Green
    }
}

# Create the virtual switch if it doesn't exist or was removed
if (-not (Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue)) {
    Write-Host "`nSelect the type of virtual switch to create:" -ForegroundColor Cyan
    Write-Host "[1] Internal (can communicate with host and other VMs, but not external network)"
    Write-Host "[2] Private (can only communicate with other VMs, not with host or external network)"
    
    $switchType = Read-Host "Enter your choice [1-2]"
    
    try {
        if ($switchType -eq "1") {
            Write-Host "`nCreating internal virtual switch '$switchName'..." -ForegroundColor Cyan
            New-VMSwitch -Name $switchName -SwitchType Internal -ErrorAction Stop | Out-Null
        } elseif ($switchType -eq "2") {
            Write-Host "`nCreating private virtual switch '$switchName'..." -ForegroundColor Cyan
            New-VMSwitch -Name $switchName -SwitchType Private -ErrorAction Stop | Out-Null
            Write-Warning "With a private switch, the host cannot directly communicate with VMs!"
            $continue = Read-Host "Do you want to continue anyway? (Y/N)"
            if ($continue -ne 'Y' -and $continue -ne 'y') {
                Write-Host "Removing switch and restarting script..." -ForegroundColor Yellow
                Remove-VMSwitch -Name $switchName -Force
                & $PSCommandPath
                exit
            }
        } else {
            Write-Error "Invalid selection. Please enter 1 or 2."
            exit 1
        }
        
        Write-Host "Virtual switch '$switchName' created successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create virtual switch: $($_.Exception.Message)"
        exit 1
    }
}

# For internal switch, configure the host virtual adapter
if ((Get-VMSwitch -Name $switchName).SwitchType -eq "Internal") {
    # Get the virtual adapter created for this switch
    Start-Sleep -Seconds 2  # Brief pause to ensure adapter is available
    $vAdapter = Get-NetAdapter | Where-Object { 
        $_.InterfaceDescription -like "*Hyper-V*" -and 
        $_.Name -like "*$switchName*" 
    }
    
    if (-not $vAdapter) {
        Write-Warning "Could not find the virtual adapter for switch '$switchName'."
        $vAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*Hyper-V*" }
        
        if ($vAdapter.Count -gt 0) {
            Write-Host "`nFound these Hyper-V related adapters:" -ForegroundColor Yellow
            $index = 1
            foreach ($adapter in $vAdapter) {
                Write-Host "[$index] $($adapter.Name) (Index: $($adapter.ifIndex))" -ForegroundColor Cyan
                $index++
            }
            
            $selectedIndex = Read-Host "Enter the number of the adapter to use for '$switchName' [1-$($vAdapter.Count)]"
            if (-not ($selectedIndex -match '^\d+$') -or [int]$selectedIndex -lt 1 -or [int]$selectedIndex -gt $vAdapter.Count) {
                Write-Error "Invalid selection. Exiting script."
                exit 1
            }
            
            $vAdapter = $vAdapter[$selectedIndex - 1]
        } else {
            Write-Error "No Hyper-V virtual adapters found. Check your network configuration."
            exit 1
        }
    }
    
    # Configure the IP address
    try {
        $ipAddress = "$subnetBase.$hostIP"
        
        # Check if IP is already configured
        $existingConfig = Get-NetIPAddress -InterfaceIndex $vAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        
        # Only replace existing IP if it's not already the one we want
        if ($existingConfig -and $existingConfig.IPAddress -ne $ipAddress) {
            Write-Host "Removing existing IP configuration from adapter '$($vAdapter.Name)'..." -ForegroundColor Cyan
            Remove-NetIPAddress -InterfaceIndex $vAdapter.ifIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction Stop
        }
        
        # If no IP is configured or we just removed the existing one
        if (-not (Get-NetIPAddress -InterfaceIndex $vAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue) -or 
            ($existingConfig -and $existingConfig.IPAddress -ne $ipAddress)) {
            Write-Host "Setting IP address to $ipAddress with subnet mask $subnetMask..." -ForegroundColor Cyan
            New-NetIPAddress -InterfaceIndex $vAdapter.ifIndex -IPAddress $ipAddress -PrefixLength $cidrPrefix -ErrorAction Stop | Out-Null
            
            # Disable DHCP on the adapter
            Write-Host "Disabling DHCP on the adapter..." -ForegroundColor Cyan
            Set-NetIPInterface -InterfaceIndex $vAdapter.ifIndex -DHCP Disabled -ErrorAction Stop
        } else {
            Write-Host "IP address $ipAddress is already configured on adapter '$($vAdapter.Name)'." -ForegroundColor Green
        }
        
        # Display the final configuration
        $newConfig = Get-NetIPAddress -InterfaceIndex $vAdapter.ifIndex -AddressFamily IPv4
        
        Write-Host "`nSuccessfully configured virtual adapter '$($vAdapter.Name)' with:" -ForegroundColor Green
        Write-Host "IP Address: $($newConfig.IPAddress)" -ForegroundColor Green
        Write-Host "Subnet Mask: /$($newConfig.PrefixLength) ($subnetMask)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to configure virtual adapter" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "`nPrivate switch created. Note that the host system cannot communicate directly with VMs on this switch." -ForegroundColor Yellow
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
$switchInfo = Get-VMSwitch -Name $switchName
Write-Host "Virtual Switch: $($switchInfo.Name)" -ForegroundColor Green
Write-Host "Switch Type: $($switchInfo.SwitchType)" -ForegroundColor Green

if ($switchInfo.SwitchType -eq "Internal") {
    $adapterInfo = Get-NetAdapter | Where-Object { 
        $_.InterfaceDescription -like "*Hyper-V*" -and 
        $_.Name -like "*$switchName*" 
    }
    if ($adapterInfo) {
        $ipInfo = Get-NetIPAddress -InterfaceIndex $adapterInfo.ifIndex -AddressFamily IPv4
        Write-Host "Host Virtual Adapter: $($adapterInfo.Name)" -ForegroundColor Green
        Write-Host "IP Address: $($ipInfo.IPAddress)/$($ipInfo.PrefixLength)" -ForegroundColor Green
    }
}

Write-Host "`nNext Steps:" -ForegroundColor Green
Write-Host "1. Connect your VMs to this new virtual switch '$switchName'"
Write-Host "   - You can use: Add-VMNetworkAdapter -VMName <your-vm> -SwitchName '$switchName'"
Write-Host "2. Configure your VMs with IPs in the 198.18.1.x range"
Write-Host "3. Verify connectivity between the host and VMs"
