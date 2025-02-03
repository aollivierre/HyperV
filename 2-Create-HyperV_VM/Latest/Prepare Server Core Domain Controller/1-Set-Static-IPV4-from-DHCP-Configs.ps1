#Example of how to run this script from a URL
# $scriptUrl = 'https://raw.githubusercontent.com/aollivierre/HyperV/refs/heads/main/2-Create-HyperV_VM/Latest/Prepare%20Server%20Core%20Domain%20Controller/1-Set-Static-IPV4-from-DHCP-Configs.ps1'; $outputPath = "$env:TEMP\Set-Static-IPV4.ps1"; Invoke-WebRequest -Uri $scriptUrl -OutFile $outputPath; Write-Host "Script downloaded to: $outputPath"; Get-Content $outputPath | Write-Host; Read-Host "Press Enter to execute the script"; Set-ExecutionPolicy Bypass -Scope Process -Force; & $outputPath

#Refer to https://github.com/aollivierre/docs/blob/b2f13176a535600eab71467b885f5a643510a56e/PowerShell/PowerShell%20Script%20Execution%20from%20URLs%20Guide.md for more information

# Get the active network adapter that has an IP address
$adapter = Get-NetAdapter | Where-Object { 
    $_.Status -eq "Up" -and                                    # Adapter is up
    -not $_.Virtual -and                                       # Not a virtual adapter
    -not $_.Name.StartsWith("vEthernet") -and                 # Not a Hyper-V virtual adapter
    (Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4).IPAddress -ne $null 
} | Select-Object -First 1

if (-not $adapter) {
    Write-Host "No suitable physical network adapter found with an IP address." -ForegroundColor Red
    Write-Host "Available network adapters:" -ForegroundColor Yellow
    Get-NetAdapter | Format-Table Name, InterfaceDescription, Status, LinkSpeed, Virtual
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
Write-Host "Adapter Description: $($adapter.InterfaceDescription)"
Write-Host "Adapter Type: $(if ($adapter.Virtual) { 'Virtual' } else { 'Physical' })"
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