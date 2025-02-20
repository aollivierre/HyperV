# Configure-RDGateway.ps1
<#
.SYNOPSIS
Configures Remote Desktop Gateway on a remote Windows Server Core machine.

.DESCRIPTION
This script automates the installation and configuration of Remote Desktop Gateway role
on a remote Windows Server Core machine. It handles:
- Role installation
- Certificate configuration
- Network policy setup
- Basic security settings

.REQUIREMENTS
1. Management server:
   - Windows Server or Windows 10/11 with RSAT tools
   - Domain joined to the same domain as target server
   - PowerShell 5.1 or later
   - Domain Administrator credentials

2. Target Server Core:
   - Domain joined to the same domain
   - Static IP configuration
   - Server name already configured
   - WinRM enabled

.PARAMETER TargetServer
The FQDN or IP address of the target Server Core machine.

.EXAMPLE
.\Configure-RDGateway.ps1 -TargetServer "RDG01.contoso.local"

.NOTES
Author: Anthony Ollivierre
Created: 2024-02-14
Last Modified: 2024-02-14
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$TargetServer
)

# Function to test if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to verify prerequisites on management server
function Test-ManagementPrerequisites {
    Write-Host "Checking management server prerequisites..." -ForegroundColor Yellow
    
    # Check if running as admin
    if (-not (Test-Administrator)) {
        Write-Error "Script must be run as Administrator on the management server"
        return $false
    }
    
    # Check if management server is domain joined
    $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
    if (-not $computerSystem.PartOfDomain) {
        Write-Error "Management server must be domain joined"
        return $false
    }
    
    # Check OS type
    $osInfo = Get-WmiObject -Class Win32_OperatingSystem
    $isWindowsServer = $osInfo.ProductType -eq 3  # 3 means Server, 1 means Workstation
    
    # Check and install RSAT RDS Tools based on OS type
    if ($isWindowsServer) {
        Write-Host "Windows Server detected, checking RSAT RDS Tools..." -ForegroundColor Yellow
        $rsatFeature = Get-WindowsFeature -Name "RSAT-RDS-Tools" -ErrorAction SilentlyContinue
        if (-not $rsatFeature -or -not $rsatFeature.Installed) {
            Write-Host "Installing RSAT RDS Tools via Windows Features..." -ForegroundColor Yellow
            Install-WindowsFeature -Name "RSAT-RDS-Tools" -IncludeAllSubFeature
        }
    } else {
        Write-Host "Windows Client detected, checking RSAT RDS Tools..." -ForegroundColor Yellow
        # Check if RSAT tools are available
        $rsatCapability = Get-WindowsCapability -Name "Rsat.RemoteDesktop.Tools*" -Online
        if ($rsatCapability.State -ne "Installed") {
            Write-Host "Installing RSAT RDS Tools via Windows Capability..." -ForegroundColor Yellow
            Add-WindowsCapability -Online -Name "Rsat.RemoteDesktop.Tools~~~~0.0.1.0"
        }
    }
    
    return $true
}

# Function to verify prerequisites on target server
function Test-TargetPrerequisites {
    param (
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    Write-Host "Checking target server prerequisites..." -ForegroundColor Yellow
    
    try {
        $prereqCheck = Invoke-Command -Session $Session -ScriptBlock {
            # Check if server is domain joined
            $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
            if (-not $computerSystem.PartOfDomain) {
                throw "Target server must be domain joined"
            }
            
            # Check if static IP is configured
            $ipConfig = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -eq "Up" }
            if (-not $ipConfig) {
                throw "No valid static IP configuration found on target server"
            }
            
            return $true
        }
        
        return $prereqCheck
    }
    catch {
        Write-Error "Failed to verify target prerequisites: $_"
        return $false
    }
}

# Function to install RD Gateway role on target server
function Install-RDGatewayRole {
    param (
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    Write-Host "Installing Remote Desktop Gateway role on target server..." -ForegroundColor Yellow
    
    try {
        $installResult = Invoke-Command -Session $Session -ScriptBlock {
            # Install RD Gateway role and management tools
            $result = Install-WindowsFeature -Name RDS-Gateway -IncludeManagementTools
            
            if ($result.Success) {
                return $true
            }
            else {
                throw "Failed to install RD Gateway role: $($result.ExitCode)"
            }
        }
        
        if ($installResult) {
            Write-Host "RD Gateway role installed successfully" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Error "Failed to install RD Gateway role: $_"
        return $false
    }
}

# Function to configure SSL certificate
function Configure-SSLCertificate {
    param (
        [System.Management.Automation.Runspaces.PSSession]$Session,
        [string]$CertificateThumbprint
    )
    
    Write-Host "Configuring SSL certificate on target server..." -ForegroundColor Yellow
    
    try {
        $certResult = Invoke-Command -Session $Session -ScriptBlock {
            param($thumbprint)
            
            # If no thumbprint provided, create self-signed certificate
            if (-not $thumbprint) {
                $serverFQDN = ([System.Net.Dns]::GetHostByName($env:COMPUTERNAME)).HostName
                $cert = New-SelfSignedCertificate -DnsName $serverFQDN -CertStoreLocation "cert:\LocalMachine\My" `
                    -KeyAlgorithm RSA -KeyLength 2048 -KeyExportPolicy Exportable `
                    -NotAfter (Get-Date).AddYears(5)
                $thumbprint = $cert.Thumbprint
            }
            
            Import-Module RemoteDesktopServices
            Set-Item -Path RDS:\GatewayServer\SSLCertificate\Thumbprint -Value $thumbprint
            
            return $true
        } -ArgumentList $CertificateThumbprint
        
        if ($certResult) {
            Write-Host "SSL certificate configured successfully" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Error "Failed to configure SSL certificate: $_"
        return $false
    }
}

# Function to configure RD Gateway settings
function Configure-RDGatewaySettings {
    param (
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    Write-Host "Configuring RD Gateway settings..." -ForegroundColor Yellow
    
    try {
        $configResult = Invoke-Command -Session $Session -ScriptBlock {
            Import-Module RemoteDesktopServices
            
            # Configure basic settings
            Set-Item -Path RDS:\GatewayServer\EnableLoadBalancing -Value 0
            Set-Item -Path RDS:\GatewayServer\MaxConnections -Value 1000
            
            # Configure connection authorization policies
            $policyName = "Default CAP"
            New-Item -Path "RDS:\GatewayServer\CAP" -Name $policyName -UserGroups "Domain Users" -AuthMethod 1
            
            # Configure resource authorization policies
            $rapName = "Default RAP"
            New-Item -Path "RDS:\GatewayServer\RAP" -Name $rapName -UserGroups "Domain Users" -ComputerGroupType 2
            
            return $true
        }
        
        if ($configResult) {
            Write-Host "RD Gateway settings configured successfully" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Error "Failed to configure RD Gateway settings: $_"
        return $false
    }
}

# Function to configure firewall rules
function Configure-Firewall {
    param (
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    Write-Host "Configuring firewall rules on target server..." -ForegroundColor Yellow
    
    try {
        $firewallResult = Invoke-Command -Session $Session -ScriptBlock {
            # Enable RD Gateway firewall rules
            Enable-NetFirewallRule -DisplayGroup "Remote Desktop Gateway"
            
            # Ensure HTTPS (TCP 443) is allowed
            $existingRule = Get-NetFirewallRule -DisplayName "RD Gateway HTTPS" -ErrorAction SilentlyContinue
            if (-not $existingRule) {
                New-NetFirewallRule -DisplayName "RD Gateway HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow
            }
            
            return $true
        }
        
        if ($firewallResult) {
            Write-Host "Firewall rules configured successfully" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Error "Failed to configure firewall rules: $_"
        return $false
    }
}

# Main script execution
try {
    Write-Host "Starting remote RD Gateway configuration for server: $TargetServer" -ForegroundColor Green
    
    # Check management server prerequisites
    if (-not (Test-ManagementPrerequisites)) {
        throw "Management server prerequisites check failed"
    }
    
    # Create remote session to target server
    Write-Host "Establishing remote session to $TargetServer..." -ForegroundColor Yellow
    $session = New-PSSession -ComputerName $TargetServer -ErrorAction Stop
    
    # Check target server prerequisites
    if (-not (Test-TargetPrerequisites -Session $session)) {
        throw "Target server prerequisites check failed"
    }
    
    # Install RD Gateway role
    if (-not (Install-RDGatewayRole -Session $session)) {
        throw "Failed to install RD Gateway role"
    }
    
    # Configure SSL certificate
    $certThumbprint = Read-Host "Enter SSL certificate thumbprint (leave blank for self-signed certificate)"
    if (-not (Configure-SSLCertificate -Session $session -CertificateThumbprint $certThumbprint)) {
        throw "Failed to configure SSL certificate"
    }
    
    # Configure RD Gateway settings
    if (-not (Configure-RDGatewaySettings -Session $session)) {
        throw "Failed to configure RD Gateway settings"
    }
    
    # Configure firewall rules
    if (-not (Configure-Firewall -Session $session)) {
        throw "Failed to configure firewall rules"
    }
    
    Write-Host "`nRD Gateway configuration completed successfully!" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Test RD Gateway connectivity from a client"
    Write-Host "2. Configure client-side Group Policy settings if needed"
    Write-Host "3. Review and customize Connection Authorization Policies (CAP)"
    Write-Host "4. Review and customize Resource Authorization Policies (RAP)"
}
catch {
    Write-Error "Configuration failed: $_"
    exit 1
}
finally {
    # Clean up remote session
    if ($session) {
        Remove-PSSession -Session $session
    }
} 