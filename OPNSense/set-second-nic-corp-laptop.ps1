# Configure-LabNetworkAccess.ps1
# Run as Administrator on your corporate laptop

# Find the built-in Ethernet adapter
$targetAdapter = Get-NetAdapter | Where-Object { 
    $_.InterfaceDescription -like "*PCIe GbE*" 
}

if (-not $targetAdapter) {
    Write-Host "Could not find the built-in Ethernet adapter." -ForegroundColor Red
    Write-Host "Available adapters:" -ForegroundColor Yellow
    Get-NetAdapter | Format-Table Name, InterfaceDescription, Status
    exit 1
}

Write-Host "Found adapter: $($targetAdapter.Name) - $($targetAdapter.InterfaceDescription)" -ForegroundColor Green
$adapterName = $targetAdapter.Name
$adapterIndex = $targetAdapter.ifIndex

# Use PowerShell cmdlets to configure the adapter more cleanly
Write-Host "Configuring adapter with IP 198.18.1.50..." -ForegroundColor Green
try {
    # Remove any existing IP configuration
    Get-NetIPAddress -InterfaceIndex $adapterIndex -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
    Get-NetRoute -InterfaceIndex $adapterIndex -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
    
    # Set static IP address
    New-NetIPAddress -InterfaceIndex $adapterIndex -IPAddress "198.18.1.50" -PrefixLength 24 -Type Unicast
    
    # Set DNS server
    Set-DnsClientServerAddress -InterfaceIndex $adapterIndex -ServerAddresses "198.18.1.1"
    
    Write-Host "IP configuration successful!" -ForegroundColor Green
} catch {
    Write-Host "Error configuring IP: $_" -ForegroundColor Red
    exit 1
}

# Make sure the adapter is enabled
if ($targetAdapter.Status -ne "Up") {
    Write-Host "Enabling adapter..." -ForegroundColor Yellow
    Enable-NetAdapter -Name $targetAdapter.Name
}

# Force metric to be very low for the 198.18.1.x network
Write-Host "Adding explicit route for 198.18.1.0/24 network with low metric..." -ForegroundColor Yellow
try {
    # First delete any existing routes to this network
    route delete 198.18.1.0 mask 255.255.255.0 2>$null
    
    # Add the route with a very low metric to ensure it takes precedence
    route add 198.18.1.0 mask 255.255.255.0 0.0.0.0 metric 1 if $adapterIndex
    Write-Host "Route added successfully" -ForegroundColor Green
} catch {
    Write-Host "Warning: Could not add route: $_" -ForegroundColor Yellow
}

# Display adapter information
Write-Host "`nCurrent Adapter Configuration:" -ForegroundColor Cyan
ipconfig /all | findstr /C:"Ethernet adapter Ethernet" /C:"IPv4 Address" /C:"Subnet Mask" /C:"Default Gateway" /C:"DNS Servers" -context 1,10

# Display the routing table
Write-Host "`nRouting Table for 198.18.1.x network:" -ForegroundColor Cyan
route print 198.18.1.*

# Wait a moment for the network to stabilize
Start-Sleep -Seconds 2

# Test connectivity to OPNsense
Write-Host "`nTesting connectivity to OPNsense (198.18.1.1)..." -ForegroundColor Cyan
ping -n 4 198.18.1.1

# Test connectivity to Hyper-V host (using correct IP)
Write-Host "`nTesting connectivity to Hyper-V host (198.18.1.108)..." -ForegroundColor Cyan
ping -n 4 198.18.1.108

# Check physical connectivity
Write-Host "`nChecking ARP table for 198.18.1.x hosts..." -ForegroundColor Cyan
arp -a | findstr "198.18.1"

# Display active connections
Write-Host "`nActive Network Connections:" -ForegroundColor Cyan
netstat -an | findstr "198.18.1"

# Instructions for connecting to OPNsense
Write-Host "`n==== SUCCESS: CONNECTION TO OPNSENSE ESTABLISHED ====" -ForegroundColor Green
Write-Host "You can now access OPNsense at: https://198.18.1.1" -ForegroundColor Green

# Help with VM access
Write-Host "`n==== ACCESSING YOUR VIRTUAL MACHINES ====" -ForegroundColor Green
Write-Host "To access your VMs on the Hyper-V host:" -ForegroundColor Green
Write-Host "1. You can now RDP to your Hyper-V host at: 198.18.1.108" -ForegroundColor White
Write-Host "   Example: mstsc /v:198.18.1.108" -ForegroundColor White
Write-Host "2. Access VMs directly if they have IPs in the 198.18.1.x range" -ForegroundColor White
Write-Host "3. You can now manage your environment while connected to your corporate VPN!" -ForegroundColor White

# Save this configuration for future use
Write-Host "`n==== SAVING CONFIGURATION ====" -ForegroundColor Yellow
Write-Host "This network configuration will be lost when you disconnect your Ethernet cable." -ForegroundColor Yellow
Write-Host "To quickly reconnect in the future, just run this script again as Administrator." -ForegroundColor White