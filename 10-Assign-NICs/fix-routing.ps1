# Fix routing for OPNsense network
# Run as Administrator

# Check current routes to the 198.18.1.0 network
Write-Host "Current routes for 198.18.1.0 network:" -ForegroundColor Cyan
Get-NetRoute -DestinationPrefix "198.18.1.0/24" | Format-Table -AutoSize

# Get the SecondaryNetwork adapter index
$adapter = Get-NetAdapter | Where-Object { $_.Name -like "*SecondaryNetwork*" }
if (-not $adapter) {
    Write-Host "SecondaryNetwork adapter not found!" -ForegroundColor Red
    exit
}

# Remove any existing routes to 198.18.1.0/24
Get-NetRoute -DestinationPrefix "198.18.1.0/24" -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false

# Add a specific route for the 198.18.1.0/24 network through the SecondaryNetwork adapter
New-NetRoute -DestinationPrefix "198.18.1.0/24" -InterfaceIndex $adapter.ifIndex -NextHop "0.0.0.0"
Write-Host "Added direct route to 198.18.1.0/24 via SecondaryNetwork adapter" -ForegroundColor Green

# Check Windows Firewall for ICMPv4 rules
$icmpRules = Get-NetFirewallRule -DisplayGroup "File and Printer Sharing" | 
             Where-Object { $_.DisplayName -like "*ICMPv4*" -and $_.Enabled -eq $false }

if ($icmpRules) {
    Write-Host "Enabling ICMPv4 echo request rules in Windows Firewall..." -ForegroundColor Yellow
    $icmpRules | Enable-NetFirewallRule
    Write-Host "ICMPv4 echo requests enabled" -ForegroundColor Green
}

# Flush DNS cache
Clear-DnsClientCache
Write-Host "DNS cache cleared" -ForegroundColor Green

# Display updated routing table
Write-Host "`nUpdated routes:" -ForegroundColor Cyan
Get-NetRoute -DestinationPrefix "198.18.1.0/24" | Format-Table -AutoSize

Write-Host "`nTest connectivity with: ping 198.18.1.1" -ForegroundColor Cyan
Write-Host "If ping works, try accessing: https://198.18.1.1" -ForegroundColor Cyan