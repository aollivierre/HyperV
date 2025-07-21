# Advanced routing fix with static ARP entry
# Run as Administrator

# Get MAC address of OPNsense LAN interface
$vmAdapter = Get-VMNetworkAdapter -VMName "085 - OPNsense - Firewall" | Where-Object { $_.SwitchName -eq "SecondaryNetwork" }
$macAddress = $vmAdapter.MacAddress
$formattedMac = $macAddress -replace '(.{2})(?!$)', '$1-'

Write-Host "OPNsense LAN MAC address: $formattedMac" -ForegroundColor Green

# Get host adapter info
$hostAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*SecondaryNetwork*" }

# Remove all routes for this network
Get-NetRoute -DestinationPrefix "198.18.1.0/24" | Remove-NetRoute -Confirm:$false
Get-NetRoute -DestinationPrefix "198.18.1.1/32" | Remove-NetRoute -Confirm:$false

# Add static ARP entry for OPNsense
Write-Host "Adding static ARP entry for 198.18.1.1..." -ForegroundColor Cyan
$result = arp -s 198.18.1.1 $formattedMac
Write-Host $result

# Add a persistent route with interface specified explicitly
Write-Host "Adding explicit persistent route to 198.18.1.1..." -ForegroundColor Cyan
route add 198.18.1.1 mask 255.255.255.255 198.18.1.2 metric 1 if $($hostAdapter.ifIndex) -p

# Block any other routing attempts to this address
$blockRule = New-NetFirewallRule -DisplayName "Block-198.18.1.1-DefaultGateway" -Direction Outbound -Action Block -RemoteAddress 198.18.1.1 -Protocol Any -InterfaceAlias "vEthernet (Realtek Gaming 2.5GbE Family Controller - Virtual Switch)" -Enabled True
Write-Host "Added firewall rule to block routing via default gateway" -ForegroundColor Green

# Test connection
Write-Host "`nTesting connection to 198.18.1.1..." -ForegroundColor Cyan
ping 198.18.1.1

# Display ARP table
Write-Host "`nARP table for SecondaryNetwork:" -ForegroundColor Cyan
arp -a -N 198.18.1.2

Write-Host "`nIf this doesn't work, let's try one final solution with a different subnet that we know works." -ForegroundColor Yellow