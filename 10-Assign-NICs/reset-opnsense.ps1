# Reset-OPNsenseNetwork.ps1
# Script to completely recreate the SecondaryNetwork virtual switch with best practices
# Run as Administrator

# Parameters - adjust these as needed
$switchName = "SecondaryNetwork"
$vmName = "085 - OPNsense - Firewall"
$hostNetworkIP = "198.18.1.2"
$networkPrefix = 24

# 1. Check that the VM is actually shut down first
$vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
if ($vm -and $vm.State -ne 'Off') {
    Write-Host "ERROR: VM '$vmName' is still running! Please shut it down first." -ForegroundColor Red
    exit 1
}

# 2. Identify and remove the existing virtual network adapter for the SecondaryNetwork
Write-Host "`n--- Removing existing adapter configuration ---" -ForegroundColor Cyan
$existingAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*$switchName*" }
if ($existingAdapter) {
    Write-Host "Found existing adapter: $($existingAdapter.Name)" -ForegroundColor Yellow
    
    # Remove any IP addresses from the adapter
    Get-NetIPAddress -InterfaceIndex $existingAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
        Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
    
    # Remove any explicit routes associated with this adapter
    Get-NetRoute -InterfaceIndex $existingAdapter.ifIndex -ErrorAction SilentlyContinue | 
        Where-Object { $_.DestinationPrefix -ne "0.0.0.0/0" -and $_.DestinationPrefix -ne "::/0" } | 
        Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
}

# 3. Remove the existing virtual switch
Write-Host "`n--- Removing existing virtual switch ---" -ForegroundColor Cyan
$existingSwitch = Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue
if ($existingSwitch) {
    Write-Host "Removing switch: $switchName" -ForegroundColor Yellow
    Remove-VMSwitch -Name $switchName -Force
    Start-Sleep -Seconds 2
}

# 4. Create a new internal virtual switch with optimal settings
Write-Host "`n--- Creating new virtual switch with best practices ---" -ForegroundColor Cyan
$newSwitch = New-VMSwitch -Name $switchName -SwitchType Internal -Notes "OPNsense LAN Network" -MinimumBandwidthMode Weight

# 5. Configure the host network adapter for the new switch
Write-Host "`n--- Configuring host network adapter ---" -ForegroundColor Cyan
# Allow time for the adapter to be created
Start-Sleep -Seconds 3

# Find the newly created adapter
$newAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*$switchName*" }
if (-not $newAdapter) {
    Write-Host "ERROR: Could not find the new network adapter. Script cannot continue." -ForegroundColor Red
    exit 1
}

Write-Host "Configuring new adapter: $($newAdapter.Name)" -ForegroundColor Yellow

# Set basic adapter properties - corrected to remove MacAddressSpoofing parameter
Set-NetAdapter -Name $newAdapter.Name -NoRestart

# Disable NetBIOS over TCP/IP using registry (compatible with PowerShell 7)
$netbtRegKey = "HKLM:SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces\Tcpip_$($newAdapter.InterfaceGuid)"
if (Test-Path $netbtRegKey) {
    Write-Host "Disabling NetBIOS over TCP/IP" -ForegroundColor Yellow
    Set-ItemProperty -Path $netbtRegKey -Name "NetbiosOptions" -Value 2
}

# Configure IPv4 address
Write-Host "Setting IP address to $hostNetworkIP/$networkPrefix" -ForegroundColor Yellow
New-NetIPAddress -InterfaceIndex $newAdapter.ifIndex -IPAddress $hostNetworkIP -PrefixLength $networkPrefix | Out-Null

# Disable IPv6 on this adapter (if not needed)
Write-Host "Disabling IPv6 on the adapter" -ForegroundColor Yellow
Disable-NetAdapterBinding -Name $newAdapter.Name -ComponentID "ms_tcpip6"

# Set low interface metric for the adapter (1)
Write-Host "Setting interface metric to 1" -ForegroundColor Yellow
Set-NetIPInterface -InterfaceIndex $newAdapter.ifIndex -InterfaceMetric 1 -AddressFamily IPv4

# 6. Configure DNS settings - no DNS needed for this adapter
Write-Host "Removing DNS settings from adapter" -ForegroundColor Yellow
Set-DnsClientServerAddress -InterfaceIndex $newAdapter.ifIndex -ResetServerAddresses

# 7. Update VM networking settings
if ($vm) {
    Write-Host "`n--- Updating VM network configuration ---" -ForegroundColor Cyan
    
    # Find the VM network adapter that should connect to this switch
    $vmAdapter = Get-VMNetworkAdapter -VM $vm | Where-Object { $_.Name -eq "Network Adapter 2" -or $_.Name -like "*LAN*" }
    
    if ($vmAdapter) {
        Write-Host "Connecting VM network adapter to the new switch" -ForegroundColor Yellow
        Connect-VMNetworkAdapter -VMNetworkAdapter $vmAdapter -SwitchName $switchName
        
        # Configure advanced features for OPNsense
        Write-Host "Enabling advanced features for OPNsense VM adapter" -ForegroundColor Yellow
        Set-VMNetworkAdapter -VMNetworkAdapter $vmAdapter -MacAddressSpoofing On -DhcpGuard Off -RouterGuard Off -AllowTeaming On
    } else {
        Write-Host "WARNING: Could not find the appropriate VM network adapter to connect to the switch." -ForegroundColor Yellow
        Write-Host "You will need to manually connect the OPNsense LAN adapter to the '$switchName' switch." -ForegroundColor Yellow
    }
}

# 8. Verify setup
Write-Host "`n--- Verifying configuration ---" -ForegroundColor Cyan
Write-Host "Virtual Switch:" -ForegroundColor Green
Get-VMSwitch -Name $switchName | Format-Table Name, SwitchType, Notes

Write-Host "Host Network Adapter:" -ForegroundColor Green
Get-NetAdapter | Where-Object { $_.Name -like "*$switchName*" } | Format-Table Name, Status, MacAddress, LinkSpeed

Write-Host "IP Configuration:" -ForegroundColor Green
Get-NetIPAddress -InterfaceAlias $newAdapter.Name -AddressFamily IPv4 | Format-Table IPAddress, PrefixLength, InterfaceAlias

# 9. Remove APIPA address (169.254.x.x) if present
$apipaAddress = Get-NetIPAddress -InterfaceAlias $newAdapter.Name -AddressFamily IPv4 | 
                Where-Object { $_.IPAddress -like "169.254.*" }
if ($apipaAddress) {
    Write-Host "`n--- Removing APIPA address ---" -ForegroundColor Cyan
    Write-Host "Removing automatic private IP address: $($apipaAddress.IPAddress)" -ForegroundColor Yellow
    try {
        Remove-NetIPAddress -IPAddress $apipaAddress.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
    } catch {
        Write-Host "Note: Could not remove APIPA address. This is normal and will not affect functionality." -ForegroundColor Yellow
    }
}

Write-Host "`n--- Setup complete ---" -ForegroundColor Cyan
Write-Host "The virtual switch has been recreated with best practices." -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "1. Start the OPNsense VM" -ForegroundColor Yellow
Write-Host "2. Add the IP alias 192.168.100.200/24 to OPNsense LAN interface" -ForegroundColor Yellow
Write-Host "3. Access OPNsense from the host via 192.168.100.200" -ForegroundColor Yellow
Write-Host "4. Access OPNsense from VMs via 198.18.1.1" -ForegroundColor Yellow