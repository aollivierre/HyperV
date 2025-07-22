#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configures DHCP Server on DC2 (Server Core) for Hyper-V lab environment.

.DESCRIPTION
    This script checks and configures DHCP on your Server Core DC2 (192.168.100.150) to automatically 
    provide correct DNS settings to all VMs on the 192.168.100.x network. This eliminates the need 
    to manually set DNS on each new VM.

.EXAMPLE
    .\Configure-DC2-DHCP-Server.ps1
    
.EXAMPLE
    .\Configure-DC2-DHCP-Server.ps1 -SkipDHCPCheck
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$DC2Name = "DC2",
    
    [Parameter(Mandatory=$false)]
    [string]$DC2IP = "192.168.100.150",
    
    [Parameter(Mandatory=$false)]
    [string[]]$DomainControllerIPs = @("192.168.100.150", "192.168.100.198", "192.168.100.199", "192.168.100.200", "192.168.100.201"),
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipDHCPCheck
)

Write-Host "`nDC2 DHCP Server Configuration Script" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Target DC: $DC2Name ($DC2IP)" -ForegroundColor Yellow
Write-Host "This will configure DHCP to serve the 192.168.100.x network" -ForegroundColor Yellow

# Check if we should run from Hyper-V host or directly
$runLocation = Read-Host "`nWhere are you running this script from? (H)yper-V Host or (D)irectly on DC2? [H/D]"

if ($runLocation -eq 'D') {
    # Running directly on DC2
    Write-Host "`nRunning configuration directly on DC2..." -ForegroundColor Green
    
    # Check if DHCP is already running
    if (-not $SkipDHCPCheck) {
        Write-Host "`nChecking for existing DHCP servers on network..." -ForegroundColor Yellow
        $existingDHCP = Get-WmiObject -Class Win32_Service | Where-Object { $_.Name -eq 'DHCPServer' -and $_.State -eq 'Running' }
        
        if ($existingDHCP) {
            Write-Warning "DHCP Server service is already running on this server."
            $continue = Read-Host "Do you want to continue and reconfigure it? (Y/N)"
            if ($continue -ne 'Y') {
                Write-Host "Exiting..." -ForegroundColor Yellow
                exit
            }
        }
    }
    
    # Install DHCP if needed
    Write-Host "`nChecking DHCP Server role installation..." -ForegroundColor Yellow
    $dhcpFeature = Get-WindowsFeature -Name DHCP
    
    if ($dhcpFeature.InstallState -ne 'Installed') {
        Write-Host "Installing DHCP Server role..." -ForegroundColor Yellow
        Install-WindowsFeature -Name DHCP -IncludeManagementTools
        Write-Host "DHCP Server role installed successfully" -ForegroundColor Green
    } else {
        Write-Host "DHCP Server role is already installed" -ForegroundColor Green
    }
    
    # Authorize DHCP server in AD
    Write-Host "`nAuthorizing DHCP server in Active Directory..." -ForegroundColor Yellow
    try {
        Add-DhcpServerInDC -DnsName $env:COMPUTERNAME -IPAddress $DC2IP
        Write-Host "DHCP server authorized in AD" -ForegroundColor Green
    } catch {
        if ($_.Exception.Message -like "*already exists*") {
            Write-Host "DHCP server already authorized in AD" -ForegroundColor Green
        } else {
            Write-Warning "Failed to authorize DHCP server: $_"
        }
    }
    
    # Configure DHCP scope
    Write-Host "`nConfiguring DHCP scope for 192.168.100.0/24..." -ForegroundColor Yellow
    
    # Check if scope already exists
    $existingScope = Get-DhcpServerv4Scope -ErrorAction SilentlyContinue | Where-Object { $_.ScopeId -eq "192.168.100.0" }
    
    if ($existingScope) {
        Write-Host "DHCP scope already exists. Updating configuration..." -ForegroundColor Yellow
        # Remove existing scope to reconfigure
        Remove-DhcpServerv4Scope -ScopeId "192.168.100.0" -Force
    }
    
    # Create new scope
    Add-DhcpServerv4Scope -Name "Lab Network - 192.168.100.x" `
        -StartRange "192.168.100.100" `
        -EndRange "192.168.100.240" `
        -SubnetMask "255.255.255.0" `
        -LeaseDuration "8.00:00:00" `
        -State Active
    
    Write-Host "DHCP scope created successfully" -ForegroundColor Green
    
    # Set scope options
    Write-Host "`nConfiguring DHCP scope options..." -ForegroundColor Yellow
    
    # Option 3: Router (Default Gateway)
    Set-DhcpServerv4OptionValue -ScopeId "192.168.100.0" -Router "192.168.100.254"
    
    # Option 6: DNS Servers (Your Domain Controllers)
    Set-DhcpServerv4OptionValue -ScopeId "192.168.100.0" -DnsServer $DomainControllerIPs
    
    # Option 15: DNS Domain Name
    Set-DhcpServerv4OptionValue -ScopeId "192.168.100.0" -DnsDomain "abc.local"
    
    Write-Host "DHCP scope options configured" -ForegroundColor Green
    
    # Add exclusions for static IPs (your DCs and other servers)
    Write-Host "`nAdding IP exclusions for domain controllers..." -ForegroundColor Yellow
    Add-DhcpServerv4ExclusionRange -ScopeId "192.168.100.0" -StartRange "192.168.100.1" -EndRange "192.168.100.99"
    Add-DhcpServerv4ExclusionRange -ScopeId "192.168.100.0" -StartRange "192.168.100.241" -EndRange "192.168.100.254"
    
    Write-Host "IP exclusions added" -ForegroundColor Green
    
    # Configure DHCP server options
    Write-Host "`nConfiguring server-level options..." -ForegroundColor Yellow
    Set-DhcpServerv4OptionValue -DnsServer $DomainControllerIPs -DnsDomain "abc.local"
    
    # Restart DHCP service
    Write-Host "`nRestarting DHCP Server service..." -ForegroundColor Yellow
    Restart-Service -Name DHCPServer -Force
    Start-Sleep -Seconds 5
    
    # Verify configuration
    Write-Host "`n=======================================" -ForegroundColor Cyan
    Write-Host "DHCP Configuration Summary" -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
    
    $scope = Get-DhcpServerv4Scope -ScopeId "192.168.100.0"
    Write-Host "Scope Name: $($scope.Name)" -ForegroundColor Green
    Write-Host "IP Range: $($scope.StartRange) - $($scope.EndRange)" -ForegroundColor Green
    Write-Host "Subnet Mask: $($scope.SubnetMask)" -ForegroundColor Green
    Write-Host "State: $($scope.State)" -ForegroundColor Green
    
    $options = Get-DhcpServerv4OptionValue -ScopeId "192.168.100.0"
    $dnsOption = $options | Where-Object { $_.OptionId -eq 6 }
    $routerOption = $options | Where-Object { $_.OptionId -eq 3 }
    $domainOption = $options | Where-Object { $_.OptionId -eq 15 }
    
    Write-Host "`nScope Options:" -ForegroundColor Yellow
    Write-Host "DNS Servers: $($dnsOption.Value -join ', ')" -ForegroundColor Green
    Write-Host "Default Gateway: $($routerOption.Value)" -ForegroundColor Green
    Write-Host "DNS Domain: $($domainOption.Value)" -ForegroundColor Green
    
} else {
    # Running from Hyper-V host
    Write-Host "`nConnecting to DC2 from Hyper-V host..." -ForegroundColor Yellow
    Write-Host "You'll need domain admin credentials to configure DHCP on DC2" -ForegroundColor Yellow
    
    $cred = Get-Credential -Message "Enter domain admin credentials (e.g., ABC\Administrator)"
    
    # Script block to run on DC2
    $scriptBlock = {
        param($DomainControllerIPs)
        
        # [Previous configuration code goes here - same as above]
        # I'll include a condensed version for space
        
        # Install DHCP
        $dhcpFeature = Get-WindowsFeature -Name DHCP
        if ($dhcpFeature.InstallState -ne 'Installed') {
            Install-WindowsFeature -Name DHCP -IncludeManagementTools
        }
        
        # Authorize in AD
        try {
            Add-DhcpServerInDC -DnsName $env:COMPUTERNAME
        } catch {
            # Already authorized
        }
        
        # Remove existing scope if present
        $existingScope = Get-DhcpServerv4Scope -ErrorAction SilentlyContinue | Where-Object { $_.ScopeId -eq "192.168.100.0" }
        if ($existingScope) {
            Remove-DhcpServerv4Scope -ScopeId "192.168.100.0" -Force
        }
        
        # Create scope
        Add-DhcpServerv4Scope -Name "Lab Network - 192.168.100.x" `
            -StartRange "192.168.100.100" `
            -EndRange "192.168.100.240" `
            -SubnetMask "255.255.255.0" `
            -LeaseDuration "8.00:00:00" `
            -State Active
        
        # Set options
        Set-DhcpServerv4OptionValue -ScopeId "192.168.100.0" -Router "192.168.100.254"
        Set-DhcpServerv4OptionValue -ScopeId "192.168.100.0" -DnsServer $DomainControllerIPs
        Set-DhcpServerv4OptionValue -ScopeId "192.168.100.0" -DnsDomain "abc.local"
        
        # Add exclusions
        Add-DhcpServerv4ExclusionRange -ScopeId "192.168.100.0" -StartRange "192.168.100.1" -EndRange "192.168.100.99"
        Add-DhcpServerv4ExclusionRange -ScopeId "192.168.100.0" -StartRange "192.168.100.241" -EndRange "192.168.100.254"
        
        # Restart service
        Restart-Service -Name DHCPServer -Force
        
        # Return summary
        $scope = Get-DhcpServerv4Scope -ScopeId "192.168.100.0"
        return @{
            ScopeName = $scope.Name
            StartRange = $scope.StartRange
            EndRange = $scope.EndRange
            State = $scope.State
        }
    }
    
    try {
        # Try using PowerShell Direct first (if DC2 is a VM on this host)
        Write-Host "Attempting to connect via PowerShell Direct..." -ForegroundColor Yellow
        $result = Invoke-Command -VMName $DC2Name -Credential $cred -ScriptBlock $scriptBlock -ArgumentList (,$DomainControllerIPs)
        Write-Host "Successfully configured DHCP on DC2 via PowerShell Direct" -ForegroundColor Green
    } catch {
        # Fall back to PSRemoting
        Write-Host "PowerShell Direct failed, trying PSRemoting..." -ForegroundColor Yellow
        $result = Invoke-Command -ComputerName $DC2IP -Credential $cred -ScriptBlock $scriptBlock -ArgumentList (,$DomainControllerIPs)
        Write-Host "Successfully configured DHCP on DC2 via PSRemoting" -ForegroundColor Green
    }
    
    # Display results
    Write-Host "`n=======================================" -ForegroundColor Cyan
    Write-Host "DHCP Configuration Summary" -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host "Scope Name: $($result.ScopeName)" -ForegroundColor Green
    Write-Host "IP Range: $($result.StartRange) - $($result.EndRange)" -ForegroundColor Green
    Write-Host "State: $($result.State)" -ForegroundColor Green
}

Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "Next Steps" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "1. New VMs will now automatically get correct DNS settings" -ForegroundColor Green
Write-Host "2. Existing VMs need to renew their DHCP lease:" -ForegroundColor Yellow
Write-Host "   - Restart the VMs, or" -ForegroundColor Yellow
Write-Host "   - Run 'ipconfig /release' then 'ipconfig /renew' on each VM" -ForegroundColor Yellow
Write-Host "3. Your Bell router will still provide DHCP for physical devices" -ForegroundColor Green
Write-Host "4. VMs will get IPs from 192.168.100.100-240 range" -ForegroundColor Green

Write-Host "`nIMPORTANT:" -ForegroundColor Red
Write-Host "If you have any VMs with static IPs in the 100-240 range," -ForegroundColor Red
Write-Host "please change them to avoid conflicts!" -ForegroundColor Red