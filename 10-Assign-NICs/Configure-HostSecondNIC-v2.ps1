# Configure static IP for the Hyper-V host's SecondaryNetwork adapter
$adapter = Get-NetAdapter | Where-Object { $_.Name -like "*SecondaryNetwork*" }
if ($adapter) {
    $interfaceIndex = $adapter.ifIndex
    
    # Remove existing IP configuration
    Remove-NetIPAddress -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
    
    # Add static IP address (using a different IP than OPNsense)
    New-NetIPAddress -InterfaceIndex $interfaceIndex -IPAddress "198.18.1.2" -PrefixLength 24
    
    # Set DNS servers if needed
    # Set-DnsClientServerAddress -InterfaceIndex $interfaceIndex -ServerAddresses "198.18.1.1"
    
    Write-Host "Static IP 198.18.1.2 configured on SecondaryNetwork adapter" -ForegroundColor Green
} else {
    Write-Host "SecondaryNetwork adapter not found!" -ForegroundColor Red
}