#requires -RunAsAdministrator
<#
.SYNOPSIS
    Adds and configures a secondary network interface on the Hyper-V host.

.DESCRIPTION
    This script configures an existing network adapter on the Hyper-V host with a static IP address
    in the 198.18.x.x range. This is useful for creating a management network for your Hyper-V environment.

.NOTES
    File Name      : Configure-HostSecondaryNIC.ps1
    Prerequisite   : Administrator rights
    Created        : 2025-03-02

.EXAMPLE
    .\Configure-HostSecondaryNIC.ps1
#>

# Set the base network information
$subnetBase = "198.18.1"
$hostIP = 1  # Host will have 198.18.1.1
$subnetMask = "255.255.255.0"
$cidrPrefix = 24  # /24 network

# Get all network adapters
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

if ($adapters.Count -eq 0) {
    Write-Error "No active network adapters found."
    exit 1
}

Write-Host "Found $($adapters.Count) active network adapter(s):" -ForegroundColor Green
$index = 1
foreach ($adapter in $adapters) {
    # Get current IP configuration
    $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    $ipAddress = if ($ipConfig) { $ipConfig.IPAddress } else { "No IPv4 Address" }
    
    Write-Host "[$index] $($adapter.Name) (Index: $($adapter.ifIndex))" -ForegroundColor Cyan
    Write-Host "    MAC Address: $($adapter.MacAddress)" 
    Write-Host "    Connection: $($adapter.MediaConnectionState)"
    Write-Host "    Current IPv4: $ipAddress"
    $index++
}

Write-Host ""
$selectedIndex = Read-Host "Enter the number of the adapter you want to configure [1-$($adapters.Count)]"

# Validate selection
if (-not ($selectedIndex -match '^\d+$') -or [int]$selectedIndex -lt 1 -or [int]$selectedIndex -gt $adapters.Count) {
    Write-Error "Invalid selection. Please enter a number between 1 and $($adapters.Count)."
    exit 1
}

# Get the selected adapter
$selectedAdapter = $adapters[$selectedIndex - 1]
$ipAddress = "$subnetBase.$hostIP"

# Display information about what's going to happen
Write-Host "`nReady to configure adapter '$($selectedAdapter.Name)' with:" -ForegroundColor Yellow
Write-Host " - IP address: $ipAddress" -ForegroundColor Yellow
Write-Host " - Subnet mask: $subnetMask (/$cidrPrefix)" -ForegroundColor Yellow
Write-Host ""
Write-Host "WARNING: This may temporarily affect network connectivity." -ForegroundColor Red
Write-Host "         Ensure you have an alternate way to access the server if needed." -ForegroundColor Red
Write-Host ""

$confirmation = Read-Host "Proceed with network configuration? (Y/N)"
if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
    Write-Host "Operation cancelled."
    exit 0
}

# Configure the adapter
try {
    # Check if IP is already configured
    $existingConfig = Get-NetIPAddress -InterfaceIndex $selectedAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    
    # Only replace existing IP if it's not already the one we want
    if ($existingConfig -and $existingConfig.IPAddress -ne $ipAddress) {
        Write-Host "Removing existing IP configuration..." -ForegroundColor Cyan
        Remove-NetIPAddress -InterfaceIndex $selectedAdapter.ifIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction Stop
    }
    
    # If no IP is configured or we just removed the existing one
    if (-not (Get-NetIPAddress -InterfaceIndex $selectedAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue) -or 
        $existingConfig.IPAddress -ne $ipAddress) {
        Write-Host "Setting IP address to $ipAddress with subnet mask $subnetMask..." -ForegroundColor Cyan
        New-NetIPAddress -InterfaceIndex $selectedAdapter.ifIndex -IPAddress $ipAddress -PrefixLength $cidrPrefix -ErrorAction Stop | Out-Null
        
        # Disable DHCP on the adapter
        Write-Host "Disabling DHCP on the adapter..." -ForegroundColor Cyan
        Set-NetIPInterface -InterfaceIndex $selectedAdapter.ifIndex -DHCP Disabled -ErrorAction Stop
    } else {
        Write-Host "IP address $ipAddress is already configured on this adapter." -ForegroundColor Green
    }
    
    # Display the final configuration
    $newConfig = Get-NetIPAddress -InterfaceIndex $selectedAdapter.ifIndex -AddressFamily IPv4
    
    Write-Host "`nSuccessfully configured $($selectedAdapter.Name) with:" -ForegroundColor Green
    Write-Host "IP Address: $($newConfig.IPAddress)" -ForegroundColor Green
    Write-Host "Subnet Mask: /$($newConfig.PrefixLength) ($subnetMask)" -ForegroundColor Green
}
catch {
    Write-Host "Failed to configure network adapter" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`nNext Steps:" -ForegroundColor Green
Write-Host "1. Verify connectivity to your VMs using their new 198.18.1.x IPs"
Write-Host "2. Set up firewall rules as needed for this new network segment"
Write-Host "3. Consider creating a static route if you need to reach other subnets through this adapter"
