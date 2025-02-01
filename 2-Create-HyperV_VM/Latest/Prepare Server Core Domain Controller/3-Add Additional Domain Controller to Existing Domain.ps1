# Script to set up additional Domain Controller
# Run this from your management server

# Parameters - adjust these values
$NewDCName = "DC2"
$ExistingDCName = "DC1"
$DomainName = "ABC.local"
$SafeModeAdminPassword = Read-Host -Prompt "Enter SafeMode Administrator Password" -AsSecureString

# First ensure we can resolve the existing DC
Write-Host "Testing DNS resolution of $ExistingDCName..." -ForegroundColor Yellow
$testParams = @{
    ComputerName = $ExistingDCName
    Quiet = $true
    Count = 1
}
if (-not (Test-Connection @testParams)) {
    Write-Error "Cannot reach $ExistingDCName. Please check network connectivity and DNS settings."
    exit
}

# Install AD DS role on the new server
Write-Host "Installing AD DS Role on $NewDCName..." -ForegroundColor Yellow
$installFeatureParams = @{
    ComputerName = $NewDCName
    ScriptBlock = {
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    }
}
Invoke-Command @installFeatureParams

# Test if installation was successful
$checkFeatureParams = @{
    ComputerName = $NewDCName
    ScriptBlock = {
        Get-WindowsFeature AD-Domain-Services
    }
}
$featureCheck = Invoke-Command @checkFeatureParams

if (-not $featureCheck.Installed) {
    Write-Error "Failed to install AD DS role on $NewDCName"
    exit
}

# Get domain admin credentials
$DomainCred = Get-Credential -Message "Enter domain admin credentials for $DomainName"

# Promote the server to a domain controller
Write-Host "Promoting $NewDCName to Domain Controller..." -ForegroundColor Yellow
try {
    $promotionParams = @{
        ComputerName = $NewDCName
        ScriptBlock = {
            param(
                $DomainName,
                $SafeModeAdminPassword,
                $Credential
            )
            
            $installParams = @{
                DomainName = $DomainName
                Credential = $Credential
                SafeModeAdministratorPassword = $SafeModeAdminPassword
                SiteName = "Default-First-Site-Name"
                NoGlobalCatalog = $false
                DatabasePath = "C:\Windows\NTDS"
                LogPath = "C:\Windows\NTDS"
                SysvolPath = "C:\Windows\SYSVOL"
                NoRebootOnCompletion = $false
                Force = $true
            }
            
            Install-ADDSDomainController @installParams
        }
        ArgumentList = @($DomainName, $SafeModeAdminPassword, $DomainCred)
    }

    Invoke-Command @promotionParams
    
    Write-Host "`nPromotion initiated successfully!" -ForegroundColor Green
    Write-Host "The server will restart automatically to complete the promotion." -ForegroundColor Yellow
    Write-Host "`nAfter restart, verify replication with these commands:" -ForegroundColor Cyan
    Write-Host "dcdiag /s:$NewDCName"
    Write-Host "repadmin /showrepl $NewDCName"
    Write-Host "Get-ADReplicationPartnerMetadata -Target $NewDCName"
}
catch {
    Write-Error "An error occurred during promotion: $_"
    exit
}

# Optional but recommended - After DC promotion and restart, run these verification commands
Write-Host "`nWait for the server to restart, then run these verification commands:" -ForegroundColor Green
Write-Host @"
# Check DC health:
dcdiag /s:$NewDCName

# Check replication:
repadmin /showrepl $NewDCName

# Verify AD sites and services:
Get-ADReplicationSite -Server $NewDCName

# Check DNS records:
Get-DnsServerZone -ComputerName $NewDCName

# Verify FSMO roles:
netdom query fsmo

# Check AD forest and domain functional levels:
Get-ADForest
Get-ADDomain
"@ -ForegroundColor Yellow