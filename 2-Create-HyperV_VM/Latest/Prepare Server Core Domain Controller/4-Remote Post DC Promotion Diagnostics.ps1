# Remote Post DC Promotion Diagnostics Script
param(
    [Parameter(Mandatory = $true)]
    [string]$NewDCName,
    
    [Parameter(Mandatory = $false)]
    [int]$RetryCount = 10,
    
    [Parameter(Mandatory = $false)]
    [int]$RetryWaitSeconds = 30,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]
    $Credential = (Get-Credential -Message "Enter Domain Admin credentials")
)

function Write-SectionHeader {
    param($Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
    Write-Host ("=" * (7 + $Message.Length)) -ForegroundColor Cyan
}

function Test-DCAvailability {
    param($DCName, $MaxRetries, $WaitSeconds)
    
    Write-Host "`nWaiting for DC to become available..." -ForegroundColor Yellow
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        $testParams = @{
            ComputerName = $DCName
            Count = 1
            Quiet = $true
        }
        
        if (Test-Connection @testParams) {
            Write-Host "DC is now responding to ping!" -ForegroundColor Green
            return $true
        }
        
        Write-Host "Attempt $i of $MaxRetries - DC not yet available. Waiting $WaitSeconds seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds $WaitSeconds
    }
    
    Write-Host "DC failed to respond after $MaxRetries attempts." -ForegroundColor Red
    return $false
}

function Export-DiagnosticsReport {
    param($ReportPath, $Results)
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $reportFile = Join-Path $reportPath "DC_Diagnostics_${NewDCName}_$timestamp.txt"
    
    $Results | Out-File -FilePath $reportFile -Width 120
    Write-Host "`nDiagnostics report saved to: $reportFile" -ForegroundColor Green
}

function Install-RequiredTools {
    # Check Windows version
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $isServer = $osInfo.ProductType -eq 3
    
    if ($isServer) {
        # Server OS - Install via Windows Features
        $rsatCheck = Get-WindowsFeature RSAT-AD-Tools -ErrorAction SilentlyContinue
        if (-not $rsatCheck.Installed) {
            Write-Host "Installing RSAT AD Tools..." -ForegroundColor Yellow
            Install-WindowsFeature -Name RSAT-AD-Tools -IncludeAllSubFeature
        }
        
        $rsatDNS = Get-WindowsFeature RSAT-DNS-Server -ErrorAction SilentlyContinue
        if (-not $rsatDNS.Installed) {
            Write-Host "Installing RSAT DNS Server Tools..." -ForegroundColor Yellow
            Install-WindowsFeature -Name RSAT-DNS-Server
        }
    }
    else {
        # Windows 10/11 - Install via Optional Features
        try {
            $adTools = Get-WindowsCapability -Name "Rsat.ActiveDirectory*" -Online
            if ($adTools.State -ne "Installed") {
                Write-Host "Installing RSAT AD Tools..." -ForegroundColor Yellow
                Get-WindowsCapability -Name "Rsat.ActiveDirectory*" -Online | Add-WindowsCapability -Online
            }
            
            $dnsTools = Get-WindowsCapability -Name "Rsat.Dns*" -Online
            if ($dnsTools.State -ne "Installed") {
                Write-Host "Installing RSAT DNS Tools..." -ForegroundColor Yellow
                Get-WindowsCapability -Name "Rsat.Dns*" -Online | Add-WindowsCapability -Online
            }
        }
        catch {
            Write-Warning "Failed to install RSAT tools: $_"
            Write-Warning "Please install RSAT tools manually from Windows Optional Features"
        }
    }
}

# Create results collection
$diagnosticResults = [System.Collections.ArrayList]@()

try {
    # Ensure required tools are installed
    Install-RequiredTools

    # Wait for DC to become available
    if (-not (Test-DCAvailability -DCName $NewDCName -MaxRetries $RetryCount -WaitSeconds $RetryWaitSeconds)) {
        throw "DC not available after maximum retry attempts"
    }

    # Create Report Directory
    $reportPath = Join-Path $PSScriptRoot "DC_Diagnostics_Reports"
    if (-not (Test-Path $reportPath)) {
        New-Item -ItemType Directory -Path $reportPath | Out-Null
    }

    # 1. DC Health Check using remote session
    Write-SectionHeader "Running DCDiag"
    $dcdiagParams = @{
        ComputerName = $NewDCName
        Credential = $Credential
        ScriptBlock = { dcdiag /v }
    }
    try {
        $dcdiagResult = Invoke-Command @dcdiagParams
        $diagnosticResults.Add("`nDC Health Check (DCDiag):`n$dcdiagResult") | Out-Null
        
        if ($dcdiagResult -match "failed test") {
            Write-Host "WARNING: Some DCDiag tests failed. Check the detailed report." -ForegroundColor Red
        } else {
            Write-Host "DCDiag tests completed successfully." -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Failed to run DCDiag: $_"
        $diagnosticResults.Add("`nDC Health Check (DCDiag): Failed to execute") | Out-Null
    }

    # 2. Replication Status
    Write-SectionHeader "Checking Replication Status"
    $replParams = @{
        ComputerName = $NewDCName
        Credential = $Credential
        ScriptBlock = { repadmin /showrepl }
    }
    try {
        $replResult = Invoke-Command @replParams
        $diagnosticResults.Add("`nReplication Status:`n$replResult") | Out-Null
        
        if ($replResult -match "failed") {
            Write-Host "WARNING: Replication issues detected. Check the detailed report." -ForegroundColor Red
        } else {
            Write-Host "Replication check completed successfully." -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Failed to check replication: $_"
        $diagnosticResults.Add("`nReplication Status: Failed to retrieve") | Out-Null
    }

    # 3. FSMO Roles
    Write-SectionHeader "Checking FSMO Roles"
    $fsmoParams = @{
        ComputerName = $NewDCName
        Credential = $Credential
        ScriptBlock = { netdom query fsmo }
    }
    try {
        $fsmoResult = Invoke-Command @fsmoParams
        $diagnosticResults.Add("`nFSMO Roles:`n$fsmoResult") | Out-Null
        Write-Host "FSMO roles check completed successfully." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to check FSMO roles: $_"
        $diagnosticResults.Add("`nFSMO Roles: Failed to retrieve") | Out-Null
    }

    # 4. DNS Records
    Write-SectionHeader "Checking DNS Zones"
    $dnsParams = @{
        ComputerName = $NewDCName
        Credential = $Credential
        ScriptBlock = {
            Get-DnsServerZone | Select-Object ZoneName, ZoneType, DynamicUpdate, ReplicationScope |
            Format-Table -AutoSize
        }
    }
    try {
        $dnsResult = Invoke-Command @dnsParams
        $diagnosticResults.Add("`nDNS Server Zones:`n$dnsResult") | Out-Null
        Write-Host "DNS zones verification completed." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to get DNS zones: $_"
        $diagnosticResults.Add("`nDNS Server Zones: Failed to retrieve") | Out-Null
    }

    # 5. Forest and Domain Functional Levels
    Write-SectionHeader "Checking Forest and Domain Levels"
    
    try {
        $forestParams = @{
            Server = $NewDCName
            Credential = $Credential
            ErrorAction = 'Stop'
        }
        $forestResult = Get-ADForest @forestParams | 
            Select-Object Name, ForestMode, Sites, Domains, GlobalCatalogs
        $diagnosticResults.Add("`nForest Information:`n$($forestResult | Format-List | Out-String)") | Out-Null
        
        $domainParams = @{
            Server = $NewDCName
            Credential = $Credential
            ErrorAction = 'Stop'
        }
        $domainResult = Get-ADDomain @domainParams | 
            Select-Object Name, DomainMode, PDCEmulator, RIDMaster, InfrastructureMaster
        $diagnosticResults.Add("`nDomain Information:`n$($domainResult | Format-List | Out-String)") | Out-Null
        Write-Host "Forest and Domain level verification completed." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to get Forest/Domain information: $_"
        $diagnosticResults.Add("`nForest/Domain Information: Failed to retrieve") | Out-Null
    }

    # 6. Additional Checks
    Write-SectionHeader "Running Additional Checks"
    
    # Check Global Catalog status
    try {
        $gcParams = @{
            Filter = "Name -eq '$NewDCName'"
            Server = $NewDCName
            Credential = $Credential
            Properties = "IsGlobalCatalog"
            ErrorAction = 'Stop'
        }
        $gcStatus = Get-ADDomainController @gcParams | Select-Object -ExpandProperty IsGlobalCatalog
        $diagnosticResults.Add("`nGlobal Catalog Status: $gcStatus") | Out-Null
        Write-Host "Global Catalog status: $gcStatus" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to check Global Catalog status: $_"
        $diagnosticResults.Add("`nGlobal Catalog Status: Failed to retrieve") | Out-Null
    }

    # Check AD Services remotely
    try {
        $servicesParams = @{
            ComputerName = $NewDCName
            Credential = $Credential
            ScriptBlock = { 
                Get-Service -Name @('NTDS', 'DNS', 'Netlogon', 'W32Time', 'DFSR') | 
                Select-Object Name, Status, StartType 
            }
        }
        $servicesResult = Invoke-Command @servicesParams
        $diagnosticResults.Add("`nCritical Services Status:`n$($servicesResult | Format-Table | Out-String)") | Out-Null
        Write-Host "Services check completed." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to check services: $_"
        $diagnosticResults.Add("`nCritical Services Status: Failed to retrieve") | Out-Null
    }

    # Export results to file
    Export-DiagnosticsReport -ReportPath $reportPath -Results $diagnosticResults

    Write-Host "`nAll diagnostic checks completed!" -ForegroundColor Green
    Write-Host "Please review the diagnostic report for detailed results." -ForegroundColor Yellow

}
catch {
    Write-Error "An error occurred during diagnostics: $_"
    if ($diagnosticResults.Count -gt 0) {
        Write-Host "Saving partial results..." -ForegroundColor Yellow
        Export-DiagnosticsReport -ReportPath $reportPath -Results $diagnosticResults
    }
}