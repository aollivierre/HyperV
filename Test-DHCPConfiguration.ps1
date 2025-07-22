#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Tests and verifies DHCP configuration in your Hyper-V lab environment.

.DESCRIPTION
    This script helps verify that DHCP is properly configured and that VMs are
    receiving correct DNS settings automatically.

.EXAMPLE
    .\Test-DHCPConfiguration.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$TestVMName = "",
    
    [Parameter(Mandatory=$false)]
    [string]$DC2IP = "192.168.100.150"
)

Write-Host "`nDHCP Configuration Test Script" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan

# Function to test from a VM
function Test-VMDHCPConfig {
    param(
        [string]$VMName
    )
    
    $testScript = {
        # Release and renew IP
        ipconfig /release | Out-Null
        Start-Sleep -Seconds 2
        ipconfig /renew | Out-Null
        Start-Sleep -Seconds 3
        
        # Get current configuration
        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
        $ipConfig = Get-NetIPConfiguration -InterfaceIndex $adapter.ifIndex
        $dnsServers = (Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4).ServerAddresses
        
        # Test DNS resolution
        $domainTest = Resolve-DnsName -Name "abc.local" -ErrorAction SilentlyContinue
        
        return @{
            VMName = $env:COMPUTERNAME
            IPAddress = $ipConfig.IPv4Address.IPAddress
            Gateway = $ipConfig.IPv4DefaultGateway.NextHop
            DNSServers = $dnsServers
            DomainResolvable = ($null -ne $domainTest)
        }
    }
    
    try {
        Write-Host "`nTesting VM: $VMName" -ForegroundColor Yellow
        $result = Invoke-Command -VMName $VMName -ScriptBlock $testScript -ErrorAction Stop
        
        Write-Host "Results for $($result.VMName):" -ForegroundColor Green
        Write-Host "  IP Address: $($result.IPAddress)" -ForegroundColor White
        Write-Host "  Gateway: $($result.Gateway)" -ForegroundColor White
        Write-Host "  DNS Servers: $($result.DNSServers -join ', ')" -ForegroundColor White
        Write-Host "  Can resolve abc.local: $($result.DomainResolvable)" -ForegroundColor $(if($result.DomainResolvable){"Green"}else{"Red"})
        
        return $result
    } catch {
        Write-Warning "Failed to test VM $VMName : $_"
        return $null
    }
}

# Test 1: Check DHCP server status
Write-Host "`n1. Checking DHCP Server Status on DC2..." -ForegroundColor Yellow

$dhcpCheck = {
    $service = Get-Service -Name DHCPServer -ErrorAction SilentlyContinue
    $scope = Get-DhcpServerv4Scope -ScopeId "192.168.100.0" -ErrorAction SilentlyContinue
    $leases = Get-DhcpServerv4Lease -ScopeId "192.168.100.0" -ErrorAction SilentlyContinue
    
    return @{
        ServiceStatus = $service.Status
        ScopeActive = $scope.State -eq "Active"
        ActiveLeases = @($leases).Count
        DNSServers = (Get-DhcpServerv4OptionValue -ScopeId "192.168.100.0" -OptionId 6 -ErrorAction SilentlyContinue).Value
    }
}

try {
    $cred = Get-Credential -Message "Enter domain admin credentials for DC2"
    $dhcpStatus = Invoke-Command -ComputerName $DC2IP -Credential $cred -ScriptBlock $dhcpCheck
    
    Write-Host "DHCP Service Status: $($dhcpStatus.ServiceStatus)" -ForegroundColor $(if($dhcpStatus.ServiceStatus -eq "Running"){"Green"}else{"Red"})
    Write-Host "Scope Active: $($dhcpStatus.ScopeActive)" -ForegroundColor $(if($dhcpStatus.ScopeActive){"Green"}else{"Red"})
    Write-Host "Active Leases: $($dhcpStatus.ActiveLeases)" -ForegroundColor White
    Write-Host "DNS Servers configured: $($dhcpStatus.DNSServers -join ', ')" -ForegroundColor White
} catch {
    Write-Warning "Could not connect to DC2 DHCP server: $_"
}

# Test 2: Check VMs
Write-Host "`n2. Checking VM Configurations..." -ForegroundColor Yellow

if ($TestVMName) {
    # Test specific VM
    Test-VMDHCPConfig -VMName $TestVMName
} else {
    # Test all running VMs (excluding DCs)
    $vms = Get-VM | Where-Object { $_.State -eq 'Running' -and $_.Name -notlike "*DC*" }
    
    if ($vms.Count -eq 0) {
        Write-Warning "No running VMs found to test (excluding DCs)"
    } else {
        Write-Host "Found $($vms.Count) running VMs to test" -ForegroundColor White
        $testOne = Read-Host "Test all VMs? (Y/N) [Default: test first VM only]"
        
        if ($testOne -eq 'Y') {
            foreach ($vm in $vms) {
                Test-VMDHCPConfig -VMName $vm.Name
            }
        } else {
            Test-VMDHCPConfig -VMName $vms[0].Name
        }
    }
}

# Test 3: Network connectivity test
Write-Host "`n3. Quick Network Tests..." -ForegroundColor Yellow

# Check if we can reach DC2 on port 67 (DHCP)
$dhcpPort = Test-NetConnection -ComputerName $DC2IP -Port 67 -WarningAction SilentlyContinue
Write-Host "DHCP Port (67) accessible on DC2: $($dhcpPort.TcpTestSucceeded)" -ForegroundColor $(if($dhcpPort.TcpTestSucceeded){"Green"}else{"Red"})

# Check DNS resolution
$dnsTest = Resolve-DnsName -Name "abc.local" -Server $DC2IP -ErrorAction SilentlyContinue
Write-Host "Can resolve abc.local via DC2: $($null -ne $dnsTest)" -ForegroundColor $(if($null -ne $dnsTest){"Green"}else{"Red"})

Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "Troubleshooting Tips" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "If VMs are not getting correct DNS:" -ForegroundColor Yellow
Write-Host "1. Make sure Windows Firewall on DC2 allows DHCP (ports 67/68)" -ForegroundColor White
Write-Host "2. Check that no other DHCP servers are active on the network" -ForegroundColor White
Write-Host "3. Verify VMs are on the correct virtual switch" -ForegroundColor White
Write-Host "4. Try 'ipconfig /release' then 'ipconfig /renew' on the VM" -ForegroundColor White
Write-Host "5. Check Event Viewer on DC2 under 'Applications and Services Logs > Microsoft > Windows > DHCP-Server'" -ForegroundColor White