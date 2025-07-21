# Diagnostic script to determine the source of TTL expired messages
# Run as Administrator

# Trace the route to 198.18.1.1 to see where it's going
Write-Host "Tracing route to 198.18.1.1..." -ForegroundColor Cyan
tracert -d 198.18.1.1

# Check if any network isolation is active
$vmAdapter = Get-VMNetworkAdapter -VMName "085 - OPNsense - Firewall" | Where-Object { $_.SwitchName -eq "SecondaryNetwork" }
Write-Host "`nVM Network Adapter Settings:" -ForegroundColor Cyan
$vmAdapter | Select-Object VMName, Name, SwitchName, MacAddressSpoofing, DhcpGuard, RouterGuard | Format-Table -AutoSize

# Check NetBIOS settings on the adapter
Write-Host "`nHost Network Adapter Settings:" -ForegroundColor Cyan
$hostAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*SecondaryNetwork*" }
$netbios = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.Index -eq $hostAdapter.ifIndex }
Write-Host "NetBIOS over TCP/IP: $($netbios.TcpipNetbiosOptions)" -ForegroundColor Cyan

# Compare network stacks
Write-Host "`nComparing network stacks between host and VSCode04:" -ForegroundColor Cyan
Write-Host "On the VSCode04 VM, please run: tracert 198.18.1.1" -ForegroundColor Yellow









# Direct connection attempt using low-level NetTCPConnection
# Run as Administrator

# Force Windows to test connection on the correct interface
Write-Host "Forcing connection attempt directly through SecondaryNetwork adapter..." -ForegroundColor Cyan
$adapter = Get-NetAdapter | Where-Object { $_.Name -like "*SecondaryNetwork*" }
$IP = "198.18.1.2"  # Your host's IP on this adapter

# Try direct socket connection
$tcpClient = New-Object System.Net.Sockets.TcpClient
$tcpClient.Client.SetIPProtectionLevel("Unrestricted")  # Allow for local network

try {
    # Bind to specific local IP
    $tcpClient.Client.Bind((New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Parse($IP), 0)))
    
    # Try to connect
    $connection = $tcpClient.BeginConnect("198.18.1.1", 443, $null, $null)
    $wait = $connection.AsyncWaitHandle.WaitOne(1000, $false)
    
    if ($wait) {
        Write-Host "Successfully established TCP connection to 198.18.1.1:443!" -ForegroundColor Green
        $tcpClient.EndConnect($connection)
    } else {
        Write-Host "Connection attempt timed out" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Connection error: $_" -ForegroundColor Red
} finally {
    $tcpClient.Close()
}

Write-Host "`nDiagnostic tools complete. Please check the results above to determine next steps." -ForegroundColor Cyan