# Get the active network adapter that has an IP address
$adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and (Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4).IPAddress -ne $null } | Select-Object -First 1

if (-not $adapter) {
    Write-Error "No active network adapter found with an IP address."
    exit 1
}

# Get current IP configuration
$currentIP = Get-NetIPConfiguration -InterfaceIndex $adapter.ifIndex
$ipAddress = $currentIP.IPv4Address.IPAddress
$prefixLength = $currentIP.IPv4Address.PrefixLength
$gateway = $currentIP.IPv4DefaultGateway.NextHop
$dnsServers = ($currentIP.DNSServer | Where-Object {$_.AddressFamily -eq 2}).ServerAddresses

# Display current settings
Write-Host "`nCurrent Network Configuration:" -ForegroundColor Green
Write-Host "--------------------------------"
Write-Host "Adapter Name: $($adapter.Name)"
Write-Host "IP Address: $ipAddress"
Write-Host "Subnet Mask Length: $prefixLength"
Write-Host "Default Gateway: $gateway"
Write-Host "DNS Servers: $($dnsServers -join ', ')"
Write-Host "`nThese settings will be configured as static values."
Write-Host "--------------------------------"

# Prompt for confirmation
$confirm = Read-Host "`nDo you want to proceed with setting these as static values? (yes/no)"

if ($confirm -ne "yes") {
    Write-Host "`nOperation cancelled by user." -ForegroundColor Yellow
    exit
}

try {
    # Remove existing IP configuration
    Remove-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
    Remove-NetRoute -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue

    # Set new static IP configuration
    New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $ipAddress -PrefixLength $prefixLength -DefaultGateway $gateway
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $dnsServers

    # Verify the new configuration
    $newConfig = Get-NetIPConfiguration -InterfaceIndex $adapter.ifIndex
    
    Write-Host "`nNew Static Configuration Applied Successfully:" -ForegroundColor Green
    Write-Host "--------------------------------"
    Write-Host "Adapter Name: $($adapter.Name)"
    Write-Host "IP Address: $($newConfig.IPv4Address.IPAddress)"
    Write-Host "Subnet Mask Length: $($newConfig.IPv4Address.PrefixLength)"
    Write-Host "Default Gateway: $($newConfig.IPv4DefaultGateway.NextHop)"
    Write-Host "DNS Servers: $((Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4).ServerAddresses -join ', ')"
    Write-Host "--------------------------------"
}
catch {
    Write-Host "`nAn error occurred while applying the configuration:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    Write-Host "`nTrying to restore DHCP configuration..." -ForegroundColor Yellow
    
    Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -Dhcp Enabled
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ResetServerAddresses
    
    Write-Host "DHCP configuration restored." -ForegroundColor Green
}