<#
.SYNOPSIS
Automates the preparation of a Windows Server Core machine for domain joining, whether as a Domain Controller or for other server roles.

.DESCRIPTION
This script performs comprehensive network diagnostics and configuration to prepare a Server Core
installation for domain integration. It can be used for:
- Preparing a new Domain Controller
- Setting up member servers for specific roles
- General domain joining of Server Core installations

The script includes:
- Network connectivity verification
- WinRM configuration and testing
- Remote management setup
- Detailed troubleshooting guidance
- Flexible credential handling for both workgroup and domain scenarios

.REQUIREMENTS
1. Management Machine:
   - Windows PowerShell (recommended) or PowerShell 7+
   - RSAT Tools installed
   - Network connectivity to both DC1 and target server

2. Target Server:
   - Windows Server Core installation
   - Basic network configuration
   - ICMP and WinRM ports accessible

3. Credentials:
   - Local administrator credentials if management machine is in workgroup
   - Domain administrator credentials if management machine is domain-joined

.NOTES
Author: Anthony Ollivierre
Created: 2024-02-14
Last Modified: 2024-02-14

.EXAMPLE
# For Domain Controller Preparation:
.\2-Automated Server Core Preparation with Current Network Settings.ps1
# Follow prompts to configure as Domain Controller

.EXAMPLE
# For Member Server Preparation:
.\2-Automated Server Core Preparation with Current Network Settings.ps1
# Follow prompts to configure as domain member

Both scenarios will prompt for:
1. DC1 (Primary DNS) IP address
2. Target server IP address
3. New server name
4. Domain name
5. Administrator credentials
#>

# Run these commands once remote management is enabled on Server Core
# Verify RSAT Tools installation
function Test-RSATTools {
    # First, determine if we're running on Windows Server or Windows Client
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $isWindowsServer = $osInfo.ProductType -eq 3  # 3 means Server, 1 means Workstation

    if ($isWindowsServer) {
        # Check RSAT features using Get-WindowsFeature (Server method)
        $requiredFeatures = @(
            "RSAT-AD-Tools",
            "RSAT-DHCP",
            "RSAT-DNS-Server",
            "RSAT-Role-Tools"
        )
        
        $missingFeatures = @()
        foreach ($feature in $requiredFeatures) {
            if (-not (Get-WindowsFeature -Name $feature).Installed) {
                $missingFeatures += $feature
            }
        }
    } else {
        # Check RSAT features using Get-WindowsCapability (Windows 10/11 method)
        $requiredFeatures = @(
            "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0",
            "Rsat.DHCP.Tools~~~~0.0.1.0",
            "Rsat.DNS.Tools~~~~0.0.1.0",
            "Rsat.ServerManager.Tools~~~~0.0.1.0"
        )
        
        $missingFeatures = @()
        foreach ($feature in $requiredFeatures) {
            $state = Get-WindowsCapability -Name $feature -Online | Select-Object -ExpandProperty State
            if ($state -ne "Installed") {
                $missingFeatures += $feature
            }
        }
    }
    
    if ($missingFeatures.Count -gt 0) {
        Write-Host "Missing RSAT features detected. The following features need to be installed:" -ForegroundColor Yellow
        $missingFeatures | ForEach-Object { Write-Host "- $_" }
        
        $install = Read-Host "Would you like to install the missing RSAT features now? (Y/N)"
        if ($install -eq 'Y') {
            foreach ($feature in $missingFeatures) {
                Write-Host "Installing $feature..." -ForegroundColor Yellow
                if ($isWindowsServer) {
                    Install-WindowsFeature -Name $feature
                } else {
                    Add-WindowsCapability -Online -Name $feature
                }
            }
            Write-Host "RSAT features installation completed." -ForegroundColor Green
        } else {
            Write-Error "Required RSAT features are not installed. Script cannot continue."
            exit 1
        }
    } else {
        Write-Host "All required RSAT features are installed." -ForegroundColor Green
    }
}

# Verify RSAT installation before proceeding
Test-RSATTools

# Function to handle credential management
function Get-StoredCredentials {
    param (
        [string]$CredentialFile
    )
    
    if (Test-Path $CredentialFile) {
        try {
            $credentialData = Import-Clixml -Path $CredentialFile
            Write-Host "Using stored credentials from $CredentialFile" -ForegroundColor Green
            return $credentialData
        }
        catch {
            Write-Warning "Could not read credential file. Will prompt for new credentials."
            Remove-Item -Path $CredentialFile -Force
        }
    }
    
    $cred = Get-Credential -Message "Enter local admin credentials of Server Core"
    
    try {
        $cred | Export-Clixml -Path $CredentialFile
        Write-Host "Credentials stored in $CredentialFile" -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not save credentials: $_"
    }
    
    return $cred
}

# Function to create a PSSession with retry
function New-RetryPSSession {
    param(
        [string]$ComputerName,
        [PSCredential]$Credential,
        [int]$MaxAttempts = 3,
        [int]$RetryDelaySeconds = 5
    )
    
    Write-Host "Establishing PowerShell session to $ComputerName..." -ForegroundColor Yellow
    
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            $session = New-PSSession -ComputerName $ComputerName -Credential $Credential -ErrorAction Stop
            Write-Host "Successfully established PowerShell session." -ForegroundColor Green
            return $session
        }
        catch {
            if ($attempt -lt $MaxAttempts) {
                Write-Host "Attempt $attempt failed. Retrying in $RetryDelaySeconds seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds $RetryDelaySeconds
            }
            else {
                Write-Error "Failed to establish PowerShell session after $MaxAttempts attempts: $_"
                return $null
            }
        }
    }
}

# Function to test server accessibility
function Test-ServerAccess {
    param (
        [string]$ServerIP,
        [PSCredential]$Credential
    )
    
    Write-Host "Testing server accessibility..." -ForegroundColor Yellow
    
    # Test WinRM connectivity
    Write-Host "Testing WinRM connectivity..." -ForegroundColor Yellow
    try {
        # Test basic connectivity first
        $result = Test-WSMan -ComputerName $ServerIP -Authentication Negotiate -ErrorAction Stop
        Write-Host "WinRM connectivity test successful" -ForegroundColor Green
        
        # Try to create a test session
        $session = New-PSSession -ComputerName $ServerIP -Credential $Credential -Authentication Negotiate -ErrorAction Stop
        
        if ($session) {
            Write-Host "Successfully created test session" -ForegroundColor Green
            Remove-PSSession $session
            return $true
        }
    }
    catch {
        Write-Error "Failed to connect to server: $_"
        Write-Host "`nTroubleshooting steps:" -ForegroundColor Yellow
        Write-Host "1. On the server (via console), run:" -ForegroundColor Cyan
        Write-Host "   Enable-PSRemoting -Force"
        Write-Host "   Set-NetConnectionProfile -NetworkCategory Private"
        Write-Host "   Restart-Service WinRM"
        Write-Host "`n2. Verify these settings:" -ForegroundColor Cyan
        Write-Host "   Get-NetConnectionProfile"
        Write-Host "   Get-Service WinRM"
        Write-Host "   winrm get winrm/config/client"
        Write-Host "`n3. Make sure Windows Firewall allows WinRM:" -ForegroundColor Cyan
        Write-Host "   Enable-NetFirewallRule -DisplayGroup 'Windows Remote Management'"
        return $false
    }
    
    return $false
}

# Function to check network configuration status
function Get-NetworkConfigStatus {
    param (
        [string]$ComputerName,
        [PSCredential]$Credential
    )
    
    Write-Host "Retrieving network configuration..." -ForegroundColor Yellow
    
    try {
        $session = New-RetryPSSession -ComputerName $ComputerName -Credential $Credential
        if (-not $session) {
            throw "Failed to establish session for network configuration check"
        }
        
        $networkStatus = Invoke-Command -Session $session -ScriptBlock {
            # Get all up adapters that have an IPv4 address
            $adapters = Get-NetAdapter | Where-Object { 
                $_.Status -eq 'Up' -and 
                (Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue)
            }
            
            # Find the adapter that matches our target IP if specified
            $targetIP = $using:ComputerName
            $adapter = $adapters | Where-Object {
                $ipAddresses = Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
                $ipAddresses.IPAddress -contains $targetIP
            }

            # If no adapter found with target IP, take the first one with an IPv4 address
            if (-not $adapter) {
                $adapter = $adapters | Select-Object -First 1
            }

            if (-not $adapter) {
                throw "No active network adapter with IPv4 address found"
            }

            $ipConfig = Get-NetIPConfiguration -InterfaceIndex $adapter.ifIndex -ErrorAction Stop
            $dhcpStatus = Get-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction Stop
            
            return @{
                AdapterName = $adapter.Name
                AdapterIndex = $adapter.ifIndex
                IPAddress = $ipConfig.IPv4Address.IPAddress
                PrefixLength = $ipConfig.IPv4Address.PrefixLength
                Gateway = $ipConfig.IPv4DefaultGateway.NextHop
                DNSServers = $ipConfig.DNSServer.ServerAddresses
                IsDHCPEnabled = $dhcpStatus.Dhcp -eq 'Enabled'
            }
        } -ErrorAction Stop
        
        Remove-PSSession $session
        return $networkStatus
    }
    catch {
        Write-Error "Failed to retrieve network configuration: $_"
        throw
    }
}

# Function to provide recovery guidance
function Show-RecoverySteps {
    Write-Host "`nServer Recovery Steps:" -ForegroundColor Cyan
    Write-Host "1. From Hyper-V Manager:" -ForegroundColor Yellow
    Write-Host "   a. Turn off the VM (State -> Turn Off)"
    Write-Host "   b. Start the VM again"
    Write-Host "   c. Wait for the VM to boot to the login screen"
    Write-Host "`n2. Once the VM is running:" -ForegroundColor Yellow
    Write-Host "   a. Log in using local administrator credentials"
    Write-Host "   b. Run 'sconfig' and select option 1"
    Write-Host "   c. Join a workgroup first (enter 'WORKGROUP')"
    Write-Host "   d. Set the desired computer name"
    Write-Host "   e. Let it restart"
    Write-Host "`n3. After restart:" -ForegroundColor Yellow
    Write-Host "   a. Verify network settings (option 8 in sconfig)"
    Write-Host "   b. Ensure WinRM is enabled (option 4 in sconfig)"
    Write-Host "   c. Run this script again"
    Write-Host "`nWould you like to proceed with these recovery steps? (yes/no): " -NoNewline
}

# Add parameter prompts at the beginning
$PrimaryDNSIP = Read-Host "Enter Primary DNS Server IP address"
if (-not ($PrimaryDNSIP -as [IPAddress])) {
    Write-Error "Invalid IP address format for Primary DNS"
    exit 1
}

$TargetIP = Read-Host "Enter desired Target Server IP address"
if (-not ($TargetIP -as [IPAddress])) {
    Write-Error "Invalid IP address format for Target Server"
    exit 1
}

# Parameters
$NewComputerName = Read-Host "Enter the new computer name for the server"
if ([string]::IsNullOrWhiteSpace($NewComputerName)) {
    Write-Error "Computer name cannot be empty"
    exit 1
}

$DomainName = Read-Host "Enter the domain name to join (e.g., contoso.local)"
if ([string]::IsNullOrWhiteSpace($DomainName) -or $DomainName -notmatch '^\w+\.\w+$') {
    Write-Error "Invalid domain name format. Please use format like 'contoso.local'"
    exit 1
}

$TargetServer = $TargetIP
$CredentialFile = Join-Path $PSScriptRoot "servercore.secrets"

# Remove existing credential file if it exists to force new credentials
if (Test-Path $CredentialFile) {
    Write-Host "Removing existing stored credentials to get fresh ones..." -ForegroundColor Yellow
    Remove-Item -Path $CredentialFile -Force
}

Write-Host "`nPlease enter the local administrator credentials for the Server Core machine." -ForegroundColor Yellow
Write-Host "Use the format: .\administrator for the username since we're using local credentials" -ForegroundColor Yellow

$credentialPrompt = "Enter local administrator credentials"
$LocalAdminCred = Get-Credential -Message $credentialPrompt -UserName ".\administrator"

if (-not $LocalAdminCred) {
    Write-Error "Credentials are required to continue."
    exit 1
}

# Test network connectivity first
Write-Host "`nTesting network connectivity..." -ForegroundColor Yellow

# Get network adapter information
Write-Host "`n1. Checking network adapters:" -ForegroundColor Cyan
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
foreach ($adapter in $adapters) {
    Write-Host "   Adapter: $($adapter.Name)"
    Write-Host "   Status: $($adapter.Status)"
    try {
        $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction Stop
        Write-Host "   IP Address: $($ipConfig.IPAddress)"
        Write-Host "   Subnet Mask: $($ipConfig.PrefixLength)"
    } catch {
        Write-Host "   IP Address: Unable to retrieve"
        Write-Host "   Subnet Mask: Unable to retrieve"
    }
    Write-Host ""
}

# Test DNS resolution
Write-Host "2. Testing DNS resolution:" -ForegroundColor Cyan
$dnsServers = Get-DnsClientServerAddress -AddressFamily IPv4 | 
    Where-Object { $_.ServerAddresses } | 
    Select-Object -ExpandProperty ServerAddresses -Unique
Write-Host "   DNS Servers configured: $($dnsServers -join ', ')"

# Test connectivity to Primary DNS
Write-Host "`n3. Testing connectivity to Primary DNS ($PrimaryDNSIP):" -ForegroundColor Cyan
$primaryDNSPing = Test-Connection -ComputerName $PrimaryDNSIP -Count 1 -Quiet
Write-Host "   Ping Primary DNS: $(if ($primaryDNSPing) { 'Success' } else { 'Failed' })"

if (-not $primaryDNSPing) {
    Write-Host "`nWARNING: Cannot reach Primary DNS. Please verify:" -ForegroundColor Red
    Write-Host "1. Primary DNS is powered on and running"
    Write-Host "2. Network settings are correct"
    Write-Host "3. Firewall rules allow ICMP traffic"
    Write-Host "4. Both servers are on the same network/subnet"
    exit 1
}

# Test connectivity to target server
Write-Host "`n4. Testing connectivity to target server ($TargetServer):" -ForegroundColor Cyan
$targetPing = Test-Connection -ComputerName $TargetServer -Count 1 -Quiet
Write-Host "   Ping Target: $(if ($targetPing) { 'Success' } else { 'Failed' })"

if (-not $targetPing) {
    Write-Host "`nWARNING: Cannot reach target server. Please verify:" -ForegroundColor Red
    Write-Host "1. The server is powered on"
    Write-Host "2. IP address $TargetServer is correct"
    Write-Host "3. The server's network settings are properly configured"
    
    # Try to get route information
    Write-Host "`nNetwork route information:" -ForegroundColor Yellow
    Get-NetRoute -AddressFamily IPv4 | Where-Object { 
        $_.DestinationPrefix -like "192.168.*" -or 
        $_.DestinationPrefix -eq "0.0.0.0/0" 
    } | Format-Table -AutoSize
    
    Write-Host "`nTroubleshooting steps:" -ForegroundColor Yellow
    Write-Host "1. Verify target server IP configuration (on server console):"
    Write-Host "   ipconfig /all"
    Write-Host "2. Check if the server responds to ping (on server console):"
    Write-Host "   ping $PrimaryDNSIP"
    Write-Host "3. Verify network adapter settings (on server console):"
    Write-Host "   Get-NetAdapter"
    Write-Host "   Get-NetIPAddress -AddressFamily IPv4"
    exit 1
}

# Test server accessibility before proceeding
Write-Host "`nTesting server accessibility..." -ForegroundColor Yellow
if (-not (Test-WSMan -ComputerName $TargetServer -Authentication Negotiate -ErrorAction SilentlyContinue)) {
    Write-Host "`nServer appears to be inaccessible or in a problematic state." -ForegroundColor Red
    Show-RecoverySteps
    $proceed = Read-Host
    if ($proceed -ne "yes") {
        exit 1
    }
    exit 0
}

Write-Host "Starting Server Core preparation process..." -ForegroundColor Green

# Test connectivity with retry logic
Write-Host "Testing connection to Server Core..." -ForegroundColor Yellow
$maxRetries = 3
$retryCount = 0
$connected = $false

while (-not $connected -and $retryCount -lt $maxRetries) {
    try {
        $null = Test-WSMan -ComputerName $TargetServer -Authentication Default -Credential $LocalAdminCred
        $connected = $true
        Write-Host "Successfully connected to Server Core" -ForegroundColor Green
    }
    catch {
        $retryCount++
        if ($retryCount -lt $maxRetries) {
            Write-Host "Connection attempt $retryCount failed. Retrying in 5 seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
        }
        else {
            Write-Error "Cannot connect to server after $maxRetries attempts. Ensure:
            1. Remote Management is enabled (Option 4 in SConfig)
            2. WinRM is started on the target server
            3. Network connectivity is available
            4. Firewall allows WinRM (TCP 5985)"
            exit 1
        }
    }
}

# Main configuration block
try {
    Write-Host "Analyzing current network configuration..." -ForegroundColor Yellow
    $networkStatus = Get-NetworkConfigStatus -ComputerName $TargetServer -Credential $LocalAdminCred

    # Display current configuration status
    Write-Host "`nCurrent Network Configuration:" -ForegroundColor Green
    Write-Host "--------------------------------"
    Write-Host "Adapter Name: $($networkStatus.AdapterName)"
    Write-Host "Current IP Address: $($networkStatus.IPAddress)"
    Write-Host "Desired IP Address: $TargetIP"
    Write-Host "Subnet Mask Length: $($networkStatus.PrefixLength)"
    Write-Host "Default Gateway: $($networkStatus.Gateway)"
    Write-Host "Current DNS Servers: $($networkStatus.DNSServers -join ', ')"
    Write-Host "Required Primary DNS: $PrimaryDNSIP"
    Write-Host "DHCP Enabled: $($networkStatus.IsDHCPEnabled)"

    Write-Host "`nNOTE: Primary DNS must be set to $PrimaryDNSIP for successful domain join." -ForegroundColor Yellow

    # Prompt for configuration choice
    Write-Host "`nConfiguration Options:" -ForegroundColor Cyan
    Write-Host "1. Update DNS settings only"
    Write-Host "2. Configure new static IP settings"
    Write-Host "3. Skip network configuration"
    $choice = Read-Host "`nEnter your choice (1-3)"

    switch ($choice) {
        "1" {
            Write-Host "`nUpdating DNS settings..." -ForegroundColor Yellow
            $dnsParams = @{
                ComputerName = $TargetServer
                Credential = $LocalAdminCred
                ScriptBlock = {
                    param($adapterIndex, $dnsServer)
                    Set-DnsClientServerAddress -InterfaceIndex $adapterIndex -ServerAddresses $dnsServer
                }
                ArgumentList = @($networkStatus.AdapterIndex, $PrimaryDNSIP)
            }
            
            Invoke-Command @dnsParams
            Write-Host "Primary DNS now set to $PrimaryDNSIP" -ForegroundColor Green
        }
        "2" {
            Write-Host "`nConfiguring static IP settings..." -ForegroundColor Yellow
            Write-Host "1. Current IP: $($networkStatus.IPAddress)"
            Write-Host "2. DHCP Status: $($networkStatus.IsDHCPEnabled)"
            Write-Host "3. Configure new static settings with IP $TargetIP"

            if ($networkStatus.IsDHCPEnabled) {
                if ($networkStatus.IPAddress -ne $TargetIP) {
                    Write-Host "WARNING: Current IP ($($networkStatus.IPAddress)) differs from desired Target IP ($TargetIP)" -ForegroundColor Red
                }
                Write-Host "Reverting to DHCP..." -ForegroundColor Yellow
                $dhcpParams = @{
                    ComputerName = $TargetServer
                    Credential = $LocalAdminCred
                    ScriptBlock = {
                        param($config)
                        Set-NetIPInterface -InterfaceIndex $config.AdapterIndex -Dhcp Enabled
                        Set-DnsClientServerAddress -InterfaceIndex $config.AdapterIndex -ResetServerAddresses
                    }
                    ArgumentList = $networkStatus
                }
                Invoke-Command @dhcpParams
                Write-Host "Successfully reverted to DHCP." -ForegroundColor Green
            }

            Write-Host "Setting new static IP configuration..." -ForegroundColor Yellow
            $staticIPParams = @{
                ComputerName = $TargetServer
                Credential = $LocalAdminCred
                ScriptBlock = {
                    param($config, $newIP)
                    
                    $removeParams = @{
                        InterfaceIndex = $config.AdapterIndex
                        AddressFamily = 'IPv4'
                        Confirm = $false
                        ErrorAction = 'SilentlyContinue'
                    }
                    Remove-NetIPAddress @removeParams
                    Remove-NetRoute @removeParams

                    $newIPParams = @{
                        InterfaceIndex = $config.AdapterIndex
                        IPAddress = $newIP
                        PrefixLength = $config.PrefixLength
                        DefaultGateway = $config.Gateway
                    }
                    New-NetIPAddress @newIPParams
                }
                ArgumentList = @($networkStatus, $TargetIP)
            }
            Invoke-Command @staticIPParams

            Write-Host "Static IP configuration updated successfully." -ForegroundColor Green
        }
        "3" {
            Write-Host "Skipping network configuration..." -ForegroundColor Yellow
        }
        default {
            Write-Host "Invalid choice. Exiting..." -ForegroundColor Red
            exit 1
        }
    }

    # Test DNS resolution
    Write-Host "`nTesting DNS resolution to domain..." -ForegroundColor Yellow
    $dnsTestParams = @{
        ComputerName = $TargetServer
        Credential = $LocalAdminCred
        ScriptBlock = {
            param($domain)
            Resolve-DnsName -Name $domain -ErrorAction SilentlyContinue
        }
        ArgumentList = $DomainName
    }
    $dnsTest = Invoke-Command @dnsTestParams

    if (-not $dnsTest) {
        Write-Host "WARNING: Cannot resolve domain $DomainName. DNS may not be configured correctly." -ForegroundColor Red
        $continue = Read-Host "Do you want to continue anyway? (yes/no)"
        if ($continue -ne "yes") {
            exit 1
        }
    }

    # Check current domain status
    Write-Host "`nChecking current domain status..." -ForegroundColor Yellow
    $domainCheckParams = @{
        ComputerName = $TargetServer
        Credential = $LocalAdminCred
        ScriptBlock = {
            $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
            return @{
                Domain = $computerSystem.Domain
                PartOfDomain = $computerSystem.PartOfDomain
                CurrentName = $env:COMPUTERNAME
            }
        }
    }
    $domainStatus = Invoke-Command @domainCheckParams

    if ($domainStatus.PartOfDomain) {
        Write-Host "WARNING: Computer is already part of domain '$($domainStatus.Domain)'" -ForegroundColor Red
        Write-Host "Current computer name: $($domainStatus.CurrentName)" -ForegroundColor Yellow
        
        $removeDomain = Read-Host "Do you want to remove the computer from the current domain before proceeding? (yes/no)"
        if ($removeDomain -eq "yes") {
            Write-Host "Removing computer from domain..." -ForegroundColor Yellow
            $removeDomainParams = @{
                ComputerName = $TargetServer
                Credential = $LocalAdminCred
                ScriptBlock = {
                    $localCred = Get-Credential -Message "Enter local administrator credentials for workgroup"
                    Remove-Computer -UnjoinDomainCredential $using:DomainCred -Force -LocalCredential $localCred
                }
            }
            Invoke-Command @removeDomainParams
            
            Write-Host "Computer removed from domain. A restart is required." -ForegroundColor Green
            $restartParams = @{
                ComputerName = $TargetServer
                Credential = $LocalAdminCred
                ScriptBlock = { Restart-Computer -Force }
            }
            Invoke-Command @restartParams
            
            Write-Host "Server is restarting. Please wait 5 minutes and run the script again." -ForegroundColor Yellow
            exit 0
        } else {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 1
        }
    }

    # Rename computer with verification (only using safe methods)
    Write-Host "`nRenaming computer to $NewComputerName..." -ForegroundColor Yellow
    $renameParams = @{
        ComputerName = $TargetServer
        Credential = $LocalAdminCred
        ScriptBlock = {
            param($name)
            try {
                # Get current computer name
                $currentName = $env:COMPUTERNAME
                
                # Check if rename is actually needed
                if ($currentName -eq $name) {
                    Write-Host "Computer is already named $name. No rename needed."
                    return @{
                        Success = $true
                        RequiresRestart = $false
                    }
                }
                
                # Only use Rename-Computer (safer than registry method)
                Rename-Computer -NewName $name -Force -ErrorAction Stop
                Write-Host "Computer rename to $name is pending and will take effect after restart."
                return @{
                    Success = $true
                    RequiresRestart = $true
                }
            } catch {
                Write-Error "Failed to rename computer: $_"
                return @{
                    Success = $false
                    RequiresRestart = $false
                }
            }
        }
        ArgumentList = $NewComputerName
    }
    
    $renameResult = Invoke-Command @renameParams
    if (-not $renameResult.Success) {
        Write-Error "Failed to rename the computer to $NewComputerName."
        exit 1
    }

    # Only restart if rename requires it
    if ($renameResult.RequiresRestart) {
        # Restart after rename before attempting domain join
        Write-Host "`nRestarting server to apply computer name change..." -ForegroundColor Yellow
        $restartParams = @{
            ComputerName = $TargetServer
            Credential = $LocalAdminCred
            ScriptBlock = { Restart-Computer -Force }
        }
        Invoke-Command @restartParams
        
        Write-Host "`nServer is restarting to apply the new computer name." -ForegroundColor Green
        Write-Host "Please wait 5 minutes and run the script again to complete the domain join." -ForegroundColor Yellow
        Write-Host "`nAfter restart:" -ForegroundColor Cyan
        Write-Host "1. Wait for the server to come back online (about 5 minutes)"
        Write-Host "2. Run this script again to complete the domain join"
        exit 0
    }

    # Proceed with domain join if no restart was needed
    Write-Host "`nPreparing to join domain $DomainName..." -ForegroundColor Yellow
    $DomainCred = Get-Credential -Message "Enter domain admin credentials for $DomainName"

    $joinParams = @{
        ComputerName = $TargetServer
        Credential = $LocalAdminCred
        ScriptBlock = {
            param($domainName, $credential)
            Add-Computer -DomainName $domainName -Credential $credential -Restart -Force
        }
        ArgumentList = @($DomainName, $DomainCred)
    }

    Write-Host "Joining domain $DomainName..." -ForegroundColor Yellow
    Invoke-Command @joinParams

    Write-Host "`nServer preparation completed successfully!" -ForegroundColor Green
    Write-Host "The server will now restart to complete the domain join." -ForegroundColor Yellow
    Write-Host "`nAfter restart:" -ForegroundColor Cyan
    Write-Host "1. Wait for the server to come back online (about 5 minutes)"
    Write-Host "2. Log in with domain admin credentials"
    Write-Host "3. Proceed with DC promotion script"

}
catch {
    Write-Error "An error occurred: $_"
    Write-Host "`nTrying to restore DHCP configuration..." -ForegroundColor Yellow
    
    $restoreDHCPParams = @{
        ComputerName = $TargetServer
        Credential = $LocalAdminCred
        ScriptBlock = {
            param($config)
            Set-NetIPInterface -InterfaceIndex $config.AdapterIndex -Dhcp Enabled
            Set-DnsClientServerAddress -InterfaceIndex $config.AdapterIndex -ResetServerAddresses
        }
        ArgumentList = $networkStatus
    }
    Invoke-Command @restoreDHCPParams
    
    Write-Host "DHCP configuration restored." -ForegroundColor Green
    exit 1
}