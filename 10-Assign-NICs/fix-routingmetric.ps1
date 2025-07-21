# Fix routing metric for SecondaryNetwork
# Run as Administrator

# Get the SecondaryNetwork adapter
$adapter = Get-NetAdapter | Where-Object { $_.Name -like "*SecondaryNetwork*" }
if (-not $adapter) {
    Write-Host "SecondaryNetwork adapter not found!" -ForegroundColor Red
    exit
}

# Display current route metrics
Write-Host "Current routes:" -ForegroundColor Cyan
Get-NetRoute -InterfaceIndex $adapter.ifIndex | Sort-Object -Property RouteMetric | Format-Table -AutoSize

# Lower the metric for the 198.18.1.0/24 route to force local routing
Get-NetRoute -DestinationPrefix "198.18.1.0/24" -InterfaceIndex $adapter.ifIndex | Remove-NetRoute -Confirm:$false
New-NetRoute -DestinationPrefix "198.18.1.0/24" -InterfaceIndex $adapter.ifIndex -NextHop "0.0.0.0" -RouteMetric 1

# Change the interface metric itself
Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -InterfaceMetric 1

Write-Host "`nRerouting traffic to 198.18.1.0/24 through SecondaryNetwork with highest priority" -ForegroundColor Green
Write-Host "Updated routes:" -ForegroundColor Cyan
Get-NetRoute -InterfaceIndex $adapter.ifIndex | Sort-Object -Property RouteMetric | Format-Table -AutoSize

# Disable IPv6 on the adapter if needed
Set-NetAdapterBinding -InterfaceAlias $adapter.Name -ComponentID "ms_tcpip6" -Enabled $false
Write-Host "Disabled IPv6 on SecondaryNetwork adapter" -ForegroundColor Green

Write-Host "`nTesting route now:" -ForegroundColor Cyan
tracert -d 198.18.1.1