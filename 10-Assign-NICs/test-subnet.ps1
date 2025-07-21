# Test-SubnetRanges.ps1
# Script to test multiple subnet ranges for routing behavior in Hyper-V

# Define the subnet ranges to test
$subnetsToTest = @(
    # TEST-NET ranges (RFC 5737)
    @{Subnet = "192.0.2"; PrefixLength = 24; Description = "TEST-NET-1"},
    @{Subnet = "198.51.100"; PrefixLength = 24; Description = "TEST-NET-2"},
    @{Subnet = "203.0.113"; PrefixLength = 24; Description = "TEST-NET-3"},
    
    # Just outside standard private ranges
    @{Subnet = "172.32.1"; PrefixLength = 24; Description = "Just outside 172.16.0.0/12"},
    @{Subnet = "192.169.1"; PrefixLength = 24; Description = "Just outside 192.168.0.0/16"},
    
    # Other potentially useful ranges
    @{Subnet = "192.88.99"; PrefixLength = 24; Description = "Former 6to4 Relay"},
    @{Subnet = "240.0.1"; PrefixLength = 24; Description = "Class E range (experimental)"}
)

# First list all network adapters
Write-Host "Available network adapters on this system:" -ForegroundColor Cyan
Get-NetAdapter | Format-Table -Property Name, InterfaceDescription, Status, MacAddress

# Find virtual adapters connected to Hyper-V switches
Write-Host "`nAvailable Hyper-V virtual switches:" -ForegroundColor Cyan
$virtualSwitches = Get-VMSwitch
$virtualSwitches | Format-Table -Property Name, SwitchType, NetAdapterInterfaceDescription

Write-Host "`nLooking for the SecondaryNetwork adapter..." -ForegroundColor Cyan

# Try multiple methods to find the right adapter
$adapter = $null

# Method 1: Try to find directly by virtual switch name
$secondarySwitch = $virtualSwitches | Where-Object { $_.Name -eq "SecondaryNetwork" }
if ($secondarySwitch) {
    # For internal or private switches, look for vEthernet adapter
    $adapter = Get-NetAdapter | Where-Object { 
        $_.Name -like "*SecondaryNetwork*" -or
        $_.Name -like "vEthernet*" -and $_.InterfaceDescription -like "*$($secondarySwitch.Name)*" 
    }
}

# Method 2: If not found, look for any adapter that might be the internal one
if (-not $adapter) {
    Write-Host "Trying alternate detection methods..." -ForegroundColor Yellow
    
    # Look for vEthernet adapters which are usually Hyper-V virtual adapters
    $vEthernetAdapters = Get-NetAdapter | Where-Object { $_.Name -like "vEthernet*" }
    
    if ($vEthernetAdapters) {
        Write-Host "Found vEthernet adapters. Please select the one connected to your SecondaryNetwork:" -ForegroundColor Yellow
        for ($i=0; $i -lt $vEthernetAdapters.Count; $i++) {
            Write-Host "$($i+1): $($vEthernetAdapters[$i].Name) - $($vEthernetAdapters[$i].InterfaceDescription)" -ForegroundColor Cyan
        }
        
        $selection = Read-Host "Enter the number of the correct adapter (or press Enter to manually enter adapter name)"
        
        if ($selection -match '^\d+$' -and $selection -ge 1 -and $selection -le $vEthernetAdapters.Count) {
            $adapter = $vEthernetAdapters[$selection-1]
        } else {
            $manualName = Read-Host "Enter the exact name of your SecondaryNetwork adapter"
            $adapter = Get-NetAdapter | Where-Object { $_.Name -eq $manualName } | Select-Object -First 1
        }
    } else {
        # Last resort - ask user to specify adapter name
        $manualName = Read-Host "Enter the exact name of your SecondaryNetwork adapter"
        $adapter = Get-NetAdapter | Where-Object { $_.Name -eq $manualName } | Select-Object -First 1
    }
}

if (-not $adapter) {
    Write-Host "ERROR: Could not identify the network adapter for SecondaryNetwork!" -ForegroundColor Red
    Write-Host "Please run this script again and enter the exact adapter name when prompted." -ForegroundColor Yellow
    exit 1
}

Write-Host "`nUsing adapter: $($adapter.Name) - $($adapter.InterfaceDescription)" -ForegroundColor Green

# Store original IP config to restore later
$originalConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4
$originalRoutes = Get-NetRoute -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 | Where-Object {$_.NextHop -ne "0.0.0.0" -and $_.NextHop -ne "::"}

# Function to test a subnet
function Test-SubnetRouting {
    param (
        [string]$Subnet,
        [int]$PrefixLength,
        [string]$Description
    )
    
    # Calculate values based on inputs
    $testIP = "$Subnet.2"
    $virtualIP = "$Subnet.1"
    $subnetWithMask = "$Subnet.0/$PrefixLength"
    
    Write-Host "`n===============================================" -ForegroundColor Cyan
    Write-Host "Testing subnet: $subnetWithMask - $Description" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "Configuring: $testIP as temporary test IP" -ForegroundColor Cyan
    Write-Host "Will test connection to: $virtualIP (simulated OPNsense)" -ForegroundColor Cyan
    
    # Remove any existing IP addresses from this subnet if present
    Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 | Where-Object {
        $_.IPAddress -like "$Subnet.*"
    } | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
    
    # Temporarily configure the test IP
    Write-Host "Configuring test IP..." -ForegroundColor Yellow
    New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $testIP -PrefixLength $PrefixLength -ErrorAction SilentlyContinue | Out-Null
    Start-Sleep -Seconds 2
    
    # Clear any existing routes for this subnet
    Get-NetRoute -DestinationPrefix $subnetWithMask -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
    
    # Add a specific route with low metric
    Write-Host "Adding test route with metric 1..." -ForegroundColor Yellow
    New-NetRoute -DestinationPrefix $subnetWithMask -InterfaceIndex $adapter.ifIndex -NextHop 0.0.0.0 -RouteMetric 1 -ErrorAction SilentlyContinue | Out-Null
    Start-Sleep -Seconds 2
    
    # Display route information
    Write-Host "Current routes for this subnet:" -ForegroundColor Green
    Get-NetRoute -DestinationPrefix $subnetWithMask -ErrorAction SilentlyContinue | Format-Table -Property DestinationPrefix, NextHop, RouteMetric, InterfaceAlias
    
    # Test ping first (quick check)
    Write-Host "Testing ping to $virtualIP..." -ForegroundColor Green
    $pingResult = ping -n 2 -w 1000 $virtualIP
    Write-Host $pingResult -ForegroundColor Gray
    
    # Test routing behavior with traceroute
    Write-Host "Testing routing behavior with traceroute to $virtualIP..." -ForegroundColor Green
    Write-Host "Note: This IP doesn't exist yet, so check only the route path taken:" -ForegroundColor Yellow
    $traceResult = tracert -h 5 -w 500 $virtualIP
    Write-Host $traceResult -ForegroundColor Gray
    
    # Analyze results to determine if route is going through default gateway
    $routeThroughDefaultGateway = $false
    $ttlExpired = $false
    
    foreach ($line in $traceResult) {
        if ($line -match "192\.168\.100\.254") {
            $routeThroughDefaultGateway = $true
        }
        if ($line -match "TTL expired") {
            $ttlExpired = $true
        }
    }
    
    # Print verdict
    Write-Host "`nResult analysis for $subnetWithMask - $Description" -ForegroundColor Cyan
    if ($routeThroughDefaultGateway) {
        Write-Host "❌ Traffic is routing through default gateway (192.168.100.254)" -ForegroundColor Red
        Write-Host "   This subnet likely has the same issue as 198.18.x.x" -ForegroundColor Red
    } elseif ($ttlExpired) {
        Write-Host "❌ Received 'TTL expired in transit' messages" -ForegroundColor Red
        Write-Host "   This subnet is routing through ISP instead of locally" -ForegroundColor Red
    } else {
        Write-Host "✅ Traffic appears to route locally (not through default gateway)" -ForegroundColor Green
        Write-Host "   This subnet is likely usable without special configuration" -ForegroundColor Green
    }
    
    # Clean up - remove test IP and route
    Write-Host "`nCleaning up test configuration..." -ForegroundColor Yellow
    Get-NetRoute -DestinationPrefix $subnetWithMask -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
    Remove-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $testIP -Confirm:$false -ErrorAction SilentlyContinue
    
    # Return result for summary
    if (-not $routeThroughDefaultGateway -and -not $ttlExpired) {
        return @{
            Subnet = $subnetWithMask
            Description = $Description
            IsGood = $true
        }
    } else {
        return @{
            Subnet = $subnetWithMask
            Description = $Description
            IsGood = $false
            GoesToDefaultGateway = $routeThroughDefaultGateway
            HasTtlExpired = $ttlExpired
        }
    }
}

# Run tests for each subnet
$results = @()
foreach ($subnet in $subnetsToTest) {
    $result = Test-SubnetRouting -Subnet $subnet.Subnet -PrefixLength $subnet.PrefixLength -Description $subnet.Description
    $results += $result
}

# Restore original configuration
if ($originalConfig) {
    Write-Host "`nRestoring original IP configuration..." -ForegroundColor Yellow
    
    # Remove all test IPs we might have added
    Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 | 
        Where-Object { $_.IPAddress -ne $originalConfig.IPAddress } | 
        Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
    
    # Re-add original IP if it's not there
    if (-not (Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $originalConfig.IPAddress -ErrorAction SilentlyContinue)) {
        New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $originalConfig.IPAddress -PrefixLength $originalConfig.PrefixLength -ErrorAction SilentlyContinue | Out-Null
    }
    
    # Restore original routes
    foreach ($route in $originalRoutes) {
        if (-not (Get-NetRoute -DestinationPrefix $route.DestinationPrefix -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue)) {
            New-NetRoute -DestinationPrefix $route.DestinationPrefix -InterfaceIndex $adapter.ifIndex -NextHop $route.NextHop -RouteMetric $route.RouteMetric -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

# Display summary of results
Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "              SUBNET TESTING SUMMARY              " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$goodSubnets = $results | Where-Object { $_.IsGood -eq $true }
Write-Host "`nRecommended subnets (routed locally):" -ForegroundColor Green
if ($goodSubnets.Count -gt 0) {
    foreach ($result in $goodSubnets) {
        Write-Host "✅ $($result.Subnet) - $($result.Description)" -ForegroundColor Green
    }
} else {
    Write-Host "❌ No subnets found that route correctly" -ForegroundColor Red
    Write-Host "   You will need to use the IP alias approach" -ForegroundColor Yellow
}

$badSubnets = $results | Where-Object { $_.IsGood -eq $false }
Write-Host "`nProblematic subnets:" -ForegroundColor Red
foreach ($result in $badSubnets) {
    $reason = if ($result.GoesToDefaultGateway) { "Routes through default gateway" } else { "TTL expired in transit" }
    Write-Host "❌ $($result.Subnet) - $($result.Description) - $reason" -ForegroundColor Red
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "                 RECOMMENDATIONS                  " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

if ($goodSubnets.Count -gt 0) {
    Write-Host "1. Configure OPNsense with one of the recommended subnets" -ForegroundColor Green
    Write-Host "   Best option: $($goodSubnets[0].Subnet) - $($goodSubnets[0].Description)" -ForegroundColor Green
    Write-Host "2. As a backup, also add the IP alias (192.168.100.200) to OPNsense LAN" -ForegroundColor Green
} else {
    Write-Host "1. All tested subnets show routing issues similar to 198.18.x.x" -ForegroundColor Yellow
    Write-Host "2. Implement the IP alias solution:" -ForegroundColor Yellow
    Write-Host "   - Keep any subnet for VM-to-OPNsense communication" -ForegroundColor Yellow
    Write-Host "   - Add 192.168.100.200 as an alias to OPNsense LAN interface" -ForegroundColor Yellow
    Write-Host "   - Access OPNsense from host via 192.168.100.200" -ForegroundColor Yellow
}

Write-Host "`nTest completed for all subnets" -ForegroundColor Cyan