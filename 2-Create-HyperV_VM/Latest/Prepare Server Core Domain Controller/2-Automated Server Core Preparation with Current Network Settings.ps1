# Run these commands once remote management is enabled on Server Core
# Requires running from a management server with RSAT tools installed



# Add parameter prompts at the beginning
$DC1IP = Read-Host "Enter DC1 (Primary DNS) IP address"
if (-not ($DC1IP -as [IPAddress])) {
    Write-Error "Invalid IP address format for DC1"
    exit 1
}

$DC2IP = Read-Host "Enter desired DC2 (This server) IP address"
if (-not ($DC2IP -as [IPAddress])) {
    Write-Error "Invalid IP address format for DC2"
    exit 1
}


# Parameters
$NewDCName = "DC02"
$DomainName = "cci.local"
# $TargetServer = "192.168.100.150"
$TargetServer = $DC2IP
$CredentialFile = Join-Path $PSScriptRoot "servercore.secrets"

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



# Function to check network configuration status
function Get-NetworkConfigStatus {
    param (
        [string]$ComputerName,
        [System.Management.Automation.PSCredential]$Credential
    )
    
    $networkStatus = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $null -ne (Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4).IPAddress } | Select-Object -First 1
        
        if (-not $adapter) {
            throw "No active network adapter found with an IP address."
        }

        $ipConfig = Get-NetIPConfiguration -InterfaceIndex $adapter.ifIndex
        $dhcpStatus = Get-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4
        
        @{
            AdapterIndex  = $adapter.ifIndex
            AdapterName   = $adapter.Name
            IPAddress     = $ipConfig.IPv4Address.IPAddress
            PrefixLength  = $ipConfig.IPv4Address.PrefixLength
            Gateway       = $ipConfig.IPv4DefaultGateway.NextHop
            DNSServers    = ($ipConfig.DNSServer | Where-Object { $_.AddressFamily -eq 2 }).ServerAddresses
            IsDHCPEnabled = $dhcpStatus.Dhcp -eq 'Enabled'
        }
    }

    return $networkStatus
}





# Configure WinRM on management server
Write-Host "Configuring WinRM settings..." -ForegroundColor Yellow
try {
    Write-Host "Setting up WinRM TrustedHosts..." -ForegroundColor Yellow
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
    
    # Optional: Restart WinRM service
    Restart-Service WinRM -Force
    Start-Sleep -Seconds 2
}
catch {
    Write-Error "Failed to configure WinRM: $_"
    exit 1
}

# Get credentials
$LocalAdminCred = Get-StoredCredentials -CredentialFile $CredentialFile

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
    Write-Host "Desired IP Address: $DC2IP"
    Write-Host "Subnet Mask Length: $($networkStatus.PrefixLength)"
    Write-Host "Default Gateway: $($networkStatus.Gateway)"
    Write-Host "Current DNS Servers: $($networkStatus.DNSServers -join ', ')"
    Write-Host "Required Primary DNS: $DC1IP"
    Write-Host "DHCP Status: $(if($networkStatus.IsDHCPEnabled){'Enabled'}else{'Disabled (Static)'})"
    Write-Host "--------------------------------"

    # DNS Configuration
    Write-Host "`nDNS Configuration is critical for domain join." -ForegroundColor Yellow
    Write-Host "Primary DNS must be set to DC1 ($DC1IP) for successful domain join." -ForegroundColor Yellow
    
    $configureDNS = Read-Host "Do you want to configure DNS settings now? (yes/no)"
    if ($configureDNS -eq "yes") {
        $dnsParams = @{
            ComputerName = $TargetServer
            Credential   = $LocalAdminCred
            ScriptBlock  = {
                param($index, $dc1ip)
                Set-DnsClientServerAddress -InterfaceIndex $index -ServerAddresses $dc1ip
            }
            ArgumentList = @($networkStatus.AdapterIndex, $DC1IP)
        }
        Invoke-Command @dnsParams

        Write-Host "DNS settings updated successfully." -ForegroundColor Green
        Write-Host "Primary DNS now set to DC1 ($DC1IP)" -ForegroundColor Green
    }

    # IP Configuration
    if (-not $networkStatus.IsDHCPEnabled) {
        Write-Host "`nWARNING: Static IP configuration detected!" -ForegroundColor Yellow
        $choice = Read-Host "`nChoose an action:
1. Keep current static configuration
2. Revert to DHCP
3. Configure new static settings with IP $DC2IP
Enter choice (1-3)"

        switch ($choice) {
            "1" {
                if ($networkStatus.IPAddress -ne $DC2IP) {
                    Write-Host "WARNING: Current IP ($($networkStatus.IPAddress)) differs from desired DC2 IP ($DC2IP)" -ForegroundColor Red
                    $confirm = Read-Host "Are you sure you want to keep the current IP? (yes/no)"
                    if ($confirm -ne "yes") {
                        Write-Host "Operation cancelled by user." -ForegroundColor Yellow
                        exit
                    }
                }
                Write-Host "Keeping current static configuration..." -ForegroundColor Green
                $netConfig = $networkStatus
            }
            "2" {
                Write-Host "Reverting to DHCP..." -ForegroundColor Yellow
                $dhcpParams = @{
                    ComputerName = $TargetServer
                    Credential   = $LocalAdminCred
                    ScriptBlock  = {
                        param($index)
                        Set-NetIPInterface -InterfaceIndex $index -Dhcp Enabled
                        Set-DnsClientServerAddress -InterfaceIndex $index -ResetServerAddresses
                    }
                    ArgumentList = $networkStatus.AdapterIndex
                }
                Invoke-Command @dhcpParams
                Write-Host "Successfully reverted to DHCP." -ForegroundColor Green
                exit
            }
            "3" {
                Write-Host "Setting new static IP configuration..." -ForegroundColor Yellow
                $staticIPParams = @{
                    ComputerName = $TargetServer
                    Credential   = $LocalAdminCred
                    ScriptBlock  = {
                        param($config, $newIP)
                        
                        $removeParams = @{
                            InterfaceIndex = $config.AdapterIndex
                            AddressFamily  = 'IPv4'
                            Confirm        = $false
                            ErrorAction    = 'SilentlyContinue'
                        }
                        Remove-NetIPAddress @removeParams
                        Remove-NetRoute @removeParams

                        $newIPParams = @{
                            InterfaceIndex = $config.AdapterIndex
                            IPAddress      = $newIP
                            PrefixLength   = $config.PrefixLength
                            DefaultGateway = $config.Gateway
                        }
                        New-NetIPAddress @newIPParams
                    }
                    ArgumentList = @($networkStatus, $DC2IP)
                }
                Invoke-Command @staticIPParams

                Write-Host "Static IP configuration updated successfully." -ForegroundColor Green
                $netConfig = $networkStatus
                $netConfig.IPAddress = $DC2IP
            }
            default {
                Write-Host "Invalid choice. Exiting..." -ForegroundColor Red
                exit 1
            }
        }
    }
    else {
        Write-Host "`nDHCP is currently enabled." -ForegroundColor Green
        $proceed = Read-Host "Do you want to configure static IP settings with IP $DC2IP? (yes/no)"
        if ($proceed -ne "yes") {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit
        }

        $configureStaticParams = @{
            ComputerName = $TargetServer
            Credential   = $LocalAdminCred
            ScriptBlock  = {
                param($config, $newIP)
                
                $removeParams = @{
                    InterfaceIndex = $config.AdapterIndex
                    AddressFamily  = 'IPv4'
                    Confirm        = $false
                    ErrorAction    = 'SilentlyContinue'
                }
                Remove-NetIPAddress @removeParams
                Remove-NetRoute @removeParams

                $newIPParams = @{
                    InterfaceIndex = $config.AdapterIndex
                    IPAddress      = $newIP
                    PrefixLength   = $config.PrefixLength
                    DefaultGateway = $config.Gateway
                }
                New-NetIPAddress @newIPParams
            }
            ArgumentList = @($networkStatus, $DC2IP)
        }
        Invoke-Command @configureStaticParams

        Write-Host "Static IP configuration set successfully." -ForegroundColor Green
        $netConfig = $networkStatus
        $netConfig.IPAddress = $DC2IP
    }

    # Test DNS resolution
    Write-Host "`nTesting DNS resolution to domain..." -ForegroundColor Yellow
    $dnsTestParams = @{
        ComputerName = $TargetServer
        Credential   = $LocalAdminCred
        ScriptBlock  = {
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

    # Rename computer (this for some reason did not report any errors but upon restart did not actually set the new name so I had to set it manually from the SConfig menu from the VM Console host so please do more testing and refactor as needed)
    Write-Host "`nRenaming computer to $NewDCName..." -ForegroundColor Yellow
    $renameParams = @{
        ComputerName = $TargetServer
        Credential   = $LocalAdminCred
        ScriptBlock  = {
            param($name)
            Rename-Computer -NewName $name -Force
        }
        ArgumentList = $NewDCName
    }
    Invoke-Command @renameParams

    # Join domain
    Write-Host "`nPreparing to join domain $DomainName..." -ForegroundColor Yellow
    $DomainCred = Get-Credential -Message "Enter domain admin credentials for $DomainName"
    
    $joinParams = @{
        ComputerName = $TargetServer
        Credential   = $LocalAdminCred
        ScriptBlock  = {
            param($domainName, $credential)
            Add-Computer -DomainName $domainName -Credential $credential -Restart -Force
        }
        ArgumentList = @($DomainName, $DomainCred)
    }
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
        Credential   = $LocalAdminCred
        ScriptBlock  = {
            param($config)
            Set-NetIPInterface -InterfaceIndex $config.AdapterIndex -Dhcp Enabled
            Set-DnsClientServerAddress -InterfaceIndex $config.AdapterIndex -ResetServerAddresses
        }
        ArgumentList = $netConfig
    }
    Invoke-Command @restoreDHCPParams
    
    Write-Host "DHCP configuration restored." -ForegroundColor Green
    exit 1
}