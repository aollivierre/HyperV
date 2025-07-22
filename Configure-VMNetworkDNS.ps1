#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Automates DNS configuration for Hyper-V virtual machines in a lab environment.

.DESCRIPTION
    This script provides multiple methods to ensure VMs in your Hyper-V lab automatically
    get the correct DNS settings to find and join your abc.local domain. It addresses
    the issue of VMs getting external DNS servers from DHCP instead of your domain controllers.

.PARAMETER VMName
    Name of the VM to configure. Use * for all VMs.

.PARAMETER DomainControllers
    Array of domain controller IP addresses to use as DNS servers.

.PARAMETER Method
    Configuration method: 'VMGuest', 'DHCP', or 'Both'

.EXAMPLE
    .\Configure-VMNetworkDNS.ps1 -VMName "Win11-Client" -DomainControllers @("192.168.100.198", "192.168.100.199")

.EXAMPLE
    .\Configure-VMNetworkDNS.ps1 -VMName * -Method Both
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$VMName = "*",
    
    [Parameter(Mandatory=$false)]
    [string[]]$DomainControllers = @("192.168.100.198", "192.168.100.199", "192.168.100.200", "192.168.100.201"),
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("VMGuest", "DHCP", "Both")]
    [string]$Method = "VMGuest",
    
    [Parameter(Mandatory=$false)]
    [string]$DomainName = "abc.local",
    
    [Parameter(Mandatory=$false)]
    [string]$DHCPScope = "192.168.100.0"
)

# Function to configure DNS on individual VMs
function Set-VMGuestDNS {
    param(
        [string]$VMName,
        [string[]]$DNSServers,
        [PSCredential]$Credential
    )
    
    try {
        # Check if VM is running
        $vm = Get-VM -Name $VMName
        if ($vm.State -ne 'Running') {
            Write-Warning "VM $VMName is not running. Starting VM..."
            Start-VM -Name $VMName
            Start-Sleep -Seconds 30  # Wait for VM to boot
        }
        
        # Use PowerShell Direct to configure DNS inside the VM
        $scriptBlock = {
            param($DNSServers)
            
            # Get all network adapters with IP addresses
            $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
            
            foreach ($adapter in $adapters) {
                # Set DNS servers
                Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $DNSServers
                
                # Also configure DNS suffix
                Set-DnsClient -InterfaceIndex $adapter.ifIndex -ConnectionSpecificSuffix "abc.local"
            }
            
            # Register in DNS
            Register-DnsClient
            
            # Clear DNS cache
            Clear-DnsClientCache
        }
        
        if ($Credential) {
            Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock $scriptBlock -ArgumentList (,$DNSServers)
        } else {
            # Try without credentials (works if VM is domain joined and you have access)
            Invoke-Command -VMName $VMName -ScriptBlock $scriptBlock -ArgumentList (,$DNSServers)
        }
        
        Write-Host "Successfully configured DNS on VM: $VMName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Warning "Failed to configure DNS on VM $VMName using PowerShell Direct: $_"
        return $false
    }
}

# Function to configure DHCP server on domain controller
function Configure-DHCPServer {
    param(
        [string]$DCName,
        [string[]]$DNSServers,
        [string]$ScopeName,
        [PSCredential]$Credential
    )
    
    $scriptBlock = {
        param($DNSServers, $ScopeName)
        
        # Check if DHCP role is installed
        $dhcpFeature = Get-WindowsFeature -Name DHCP
        if ($dhcpFeature.InstallState -ne 'Installed') {
            Write-Host "Installing DHCP Server role..." -ForegroundColor Yellow
            Install-WindowsFeature -Name DHCP -IncludeManagementTools
        }
        
        # Authorize DHCP server in AD if not already authorized
        $authorized = Get-DhcpServerInDC -ErrorAction SilentlyContinue
        if (-not $authorized) {
            Add-DhcpServerInDC -DnsName $env:COMPUTERNAME
        }
        
        # Check if scope exists
        $scope = Get-DhcpServerv4Scope -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $ScopeName }
        
        if (-not $scope) {
            # Create new scope
            Add-DhcpServerv4Scope -Name $ScopeName `
                -StartRange "192.168.100.100" `
                -EndRange "192.168.100.200" `
                -SubnetMask "255.255.255.0" `
                -State Active
            
            # Set scope options
            Set-DhcpServerv4OptionValue -ScopeId "192.168.100.0" `
                -Router "192.168.100.254" `
                -DnsServer $DNSServers `
                -DnsDomain "abc.local"
        } else {
            # Update existing scope DNS servers
            Set-DhcpServerv4OptionValue -ScopeId $scope.ScopeId `
                -DnsServer $DNSServers `
                -Force
        }
        
        # Restart DHCP service
        Restart-Service -Name DHCPServer -Force
        
        Write-Host "DHCP server configured successfully" -ForegroundColor Green
    }
    
    try {
        # Try to connect to first available DC
        $dc = Get-VM -Name $DCName -ErrorAction SilentlyContinue
        if ($dc -and $dc.State -eq 'Running') {
            if ($Credential) {
                Invoke-Command -VMName $DCName -Credential $Credential -ScriptBlock $scriptBlock -ArgumentList $DNSServers, $ScopeName
            } else {
                Invoke-Command -ComputerName $DCName -ScriptBlock $scriptBlock -ArgumentList $DNSServers, $ScopeName
            }
            return $true
        }
    }
    catch {
        Write-Warning "Failed to configure DHCP on $DCName : $_"
    }
    
    return $false
}

# Function to create a DNS configuration startup script
function New-DNSConfigurationScript {
    param(
        [string[]]$DNSServers,
        [string]$OutputPath = "C:\Scripts"
    )
    
    $scriptContent = @"
# Auto-configure DNS for domain joining
`$dnsServers = @('$($DNSServers -join "','")')
`$domainSuffix = 'abc.local'

# Get active network adapters
`$adapters = Get-NetAdapter | Where-Object { `$_.Status -eq 'Up' }

foreach (`$adapter in `$adapters) {
    # Skip virtual adapters
    if (`$adapter.Name -notlike "*vEthernet*") {
        # Set DNS servers
        Set-DnsClientServerAddress -InterfaceIndex `$adapter.ifIndex -ServerAddresses `$dnsServers
        
        # Set DNS suffix
        Set-DnsClient -InterfaceIndex `$adapter.ifIndex -ConnectionSpecificSuffix `$domainSuffix
    }
}

# Register in DNS
Register-DnsClient

# Clear DNS cache
Clear-DnsClientCache

# Test domain connectivity
`$testResult = Resolve-DnsName -Name `$domainSuffix -ErrorAction SilentlyContinue
if (`$testResult) {
    Write-Host "Successfully configured DNS and can resolve `$domainSuffix" -ForegroundColor Green
} else {
    Write-Warning "DNS configured but cannot resolve `$domainSuffix"
}
"@
    
    # Create scripts directory if it doesn't exist
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
    
    # Save the script
    $scriptPath = Join-Path $OutputPath "Configure-DNSForDomain.ps1"
    $scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8
    
    Write-Host "DNS configuration script created at: $scriptPath" -ForegroundColor Green
    return $scriptPath
}

# Main execution
Write-Host "`nHyper-V Lab DNS Configuration Tool" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan

# Get credentials if needed
$needCredentials = $false
if ($Method -in @("VMGuest", "Both")) {
    $vmCred = Get-Credential -Message "Enter local administrator credentials for VMs (username: Administrator or .\Administrator)"
}
if ($Method -in @("DHCP", "Both")) {
    $dcCred = Get-Credential -Message "Enter domain administrator credentials for configuring DHCP"
}

# Method 1: Configure DNS directly on VMs
if ($Method -in @("VMGuest", "Both")) {
    Write-Host "`nConfiguring DNS on Virtual Machines..." -ForegroundColor Yellow
    
    if ($VMName -eq "*") {
        $vms = Get-VM | Where-Object { $_.State -eq 'Running' -and $_.Name -notlike "*DC*" }
    } else {
        $vms = Get-VM -Name $VMName
    }
    
    foreach ($vm in $vms) {
        Set-VMGuestDNS -VMName $vm.Name -DNSServers $DomainControllers -Credential $vmCred
    }
}

# Method 2: Configure DHCP server
if ($Method -in @("DHCP", "Both")) {
    Write-Host "`nConfiguring DHCP Server on Domain Controller..." -ForegroundColor Yellow
    
    # Find running DC
    $dcs = Get-VM | Where-Object { $_.Name -like "*DC*" -and $_.State -eq 'Running' }
    
    foreach ($dc in $dcs) {
        if (Configure-DHCPServer -DCName $dc.Name -DNSServers $DomainControllers -ScopeName "Lab Network" -Credential $dcCred) {
            Write-Host "DHCP configured on $($dc.Name)" -ForegroundColor Green
            break
        }
    }
}

# Create DNS configuration script for future use
Write-Host "`nCreating DNS configuration script for new VMs..." -ForegroundColor Yellow
$scriptPath = New-DNSConfigurationScript -DNSServers $DomainControllers

# Summary and recommendations
Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "DNS Configuration Summary" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "Domain Controllers (DNS Servers): $($DomainControllers -join ', ')" -ForegroundColor Green
Write-Host "Domain Name: $DomainName" -ForegroundColor Green
Write-Host "Configuration Method: $Method" -ForegroundColor Green

Write-Host "`nRecommendations:" -ForegroundColor Yellow
Write-Host "1. For new VMs, run the script at: $scriptPath"
Write-Host "2. Or use this command after VM creation:"
Write-Host "   .\Configure-VMNetworkDNS.ps1 -VMName 'NewVMName' -Method VMGuest"
Write-Host "3. To configure all VMs at once:"
Write-Host "   .\Configure-VMNetworkDNS.ps1 -VMName * -Method Both"
Write-Host "4. Consider adding the DNS script to your VM provisioning process"

Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
Write-Host "- If VMs still can't find domain, check firewall rules on DCs"
Write-Host "- Ensure DCs are running and DNS service is active"
Write-Host "- Verify network connectivity between VMs and DCs"
Write-Host "- Use 'nslookup abc.local <DC_IP>' to test DNS resolution"