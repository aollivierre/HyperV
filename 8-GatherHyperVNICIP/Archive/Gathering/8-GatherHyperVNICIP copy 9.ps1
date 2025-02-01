# Load the Windows Admin Center ConnectionTools module
# Import-Module "C:\ProgramData\Server Management Experience\Extensions\msft.sme.hyperv.4.20.0\ux\powershell-module\Microsoft.SME.HyperV\Microsoft.SME.HyperV.psm1"



# Load the Windows Admin Center ConnectionTools module
# Import-Module "$env:ProgramFiles\Windows Admin Center\PowerShell\Modules\ConnectionTools"












#########################################################################################
#
# Copyright (c) Microsoft Corporation. All rights reserved.
#
# Connection Tools
#
#Requires -Version 4.0
#
#########################################################################################

# add-type @"
#     using System.Net;
#     using System.Security.Cryptography.X509Certificates;
#     public class TrustAllCertsPolicy : ICertificatePolicy {
#         public bool CheckValidationResult(
#             ServicePoint srvPoint, X509Certificate certificate,
#             WebRequest request, int certificateProblem) {
#             return true;
#         }
#     }
# "@

Function Get-Params {
    param(
        [Parameter(Mandatory = $false)]
        [Uri]
        $GatewayEndpoint,
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential
    )
    if ( $GatewayEndpoint -eq $null ) {
        try
        {
            $GatewayEndpoint = [Uri] ( Get-ItemPropertyValue 'HKCU:\Software\Microsoft\ServerManagementGateway' 'SmeDesktopEndpoint' )
        }
        catch
        {
            throw (New-Object System.Exception -ArgumentList 'No endpoint was specified so a local gateway was assumed and it must be run at least once.')
        }
    }
    $params = @{useBasicParsing = $true; userAgent = "PowerShell"}
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    $clientCertificateThumbprint = ''
    $IsLocal = $GatewayEndpoint.IsLoopback -or ( $GatewayEndpoint.Host -eq $Env:ComputerName )
    if ( ( $GatewayEndpoint.Scheme -eq [Uri]::UriSchemeHttps ) -and $IsLocal ) {
        $clientCertificateThumbprint = (Get-ChildItem 'Cert:\CurrentUser\My' | Where-Object { $_.Subject -eq 'CN=Windows Admin Center Client' }).Thumbprint
    }
    if ($clientCertificateThumbprint) {
        $params.certificateThumbprint = "$clientCertificateThumbprint"
    }
    else {
        if ($Credential) {
            $params.credential = $Credential
        }
        else {
            $params.useDefaultCredentials = $True
        }
    }
    $params.uri = "$($GatewayEndpoint)/api/connections"
    return $params
}

Function Get-Connections {
    param(
        [Parameter(Mandatory = $false)]
        [Uri]
        $GatewayEndpoint,
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential
    )
    $params = Get-Params $GatewayEndpoint $Credential
    $params.method = "Get"
    $response = Invoke-WebRequest @params
    if ($response.StatusCode -ne 200 ) {
        throw "Failed to get the connections"
    }
    $connections = ConvertFrom-Json $response.Content
    return $connections
}

Function Remove-Connection {
    param(
        [Parameter(Mandatory = $false)]
        [Uri]
        $GatewayEndpoint,
        [Parameter(Mandatory = $true)]
        [String]
        $connectionId,
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential
    )
    $params = Get-Params $GatewayEndpoint $Credential
    $params.method = "Delete"
    $params.uri = $params.uri + "/" + $connectionId
    $response = Invoke-WebRequest @params
    if ($response.StatusCode -ge 300) {
        throw "Failed to remove the connection"
    }
}

<#
.SYNOPSIS
Show the connections available in the Windows Admin Center Gateway. Export them if a filename is provided

.DESCRIPTION
The function export to a file the available connections

.PARAMETER GatewayEndpoint
Required. Provide the gateway name.

.PARAMETER Credential
Optional. If you wish to provide credentials to the Windows Admin Center gateway which are different from your credentials on the computer where you're executing the script, provide a PSCredential by using Get-Credential. You can also provide just the username for this parameter and you will be prompted to enter the corresponding password (which gets stored as a SecureString).

.PARAMETER fileName
Optional. File name to export the results. If is not provided the result is show in console.

.EXAMPLE
C:\PS> Import-Connection "http://localhost:4100" -fileName "wac-connections.csv"
#>
Function Export-Connection {
    param(
        [Parameter(Mandatory = $false)]
        [Uri]
        $GatewayEndpoint,
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential,
        [Parameter(Mandatory = $false)]
        [String]
        $fileName
    )
    $connections = Get-Connections $GatewayEndpoint $Credential
    $connections = $connections.value | Select-Object -expand properties | Select-Object name, type, tags, groupId
    if ($PSBoundParameters.ContainsKey("fileName")){
        $connections | Select-Object Name, Type, @{Name="tags"; Expression={$_.tags -join '|'}}, GroupId | Export-Csv -Path $fileName -NoTypeInformation
    } else {
        return $connections
    }
}

<#
.SYNOPSIS
Import the connections available in a file to the Windows Admin Center Gateway.

.DESCRIPTION
The function import all the connections especified into a file

.PARAMETER GatewayEndpoint
Required. Provide the gateway name.

.PARAMETER Credential
Optional. If you wish to provide credentials to the Windows Admin Center gateway which are different from your credentials on the computer where you're executing the script, provide a PSCredential by using Get-Credential. You can also provide just the username for this parameter and you will be prompted to enter the corresponding password (which gets stored as a SecureString).

.PARAMETER fileName
Required. File name to export the results. If is not provided the result is show in console.

.PARAMETER prune
Optional. If it is present, the connections not included in the file will be removed.

.EXAMPLE
C:\PS> Import-Connection "http://localhost:4100" -fileName "wac-connections.csv"
#>
Function Import-Connection {
    param(
        [Parameter(Mandatory = $false)]
        [Uri]
        $GatewayEndpoint,
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential,
        [Parameter(Mandatory = $true)]
        [String]
        $fileName,
        [Parameter(Mandatory = $false)]
        [switch]
        $prune
    )

    $connectionsResult = Get-Connections $GatewayEndpoint $Credential

    # Validate csv headers (order & case sensitive) required for connections to be imported
    $correctHeaders = @("name", "type", "tags", "groupId")
    $csvHeaders = (Get-Content $fileName -TotalCount 1).Split(",").Trim("`"' ")
    if (Compare-Object $correctHeaders $csvHeaders -SyncWindow 0 -CaseSensitive) {
        $correctHeadersFormatString = '"' + ($correctHeaders -join '","') + '"'
        throw "The CSV file does not have the correct headers. Correct header should be: $correctHeadersFormatString"
    }

    $connections = Import-Csv $fileName
    $connections | ForEach-Object {
        $connectionName = $_.name
        $id = ($_.type + "!" + $_.name)
        if ($_.groupId) {
            $id = ($id + "!" + $_.groupId)
        }
        $_ | Add-Member "id" $id

        # Get existing tags
        $existingTags = $connectionsResult.value | `
            where-Object { $_.properties.name -eq $connectionName } | `
            Select-Object @{Name = "Tags"; Expression = { $_.properties.tags } }
        [System.Array]$existingTags = $existingTags.Tags
        if ($_.tags) {
            # Get new tags
            [System.Array]$newTags = $_.tags.split("|")
        }
        else {
            # Reset variable to not use any stale tags from previous rows
            $newTags = $null
        }

        [System.Array]$tags = ($newTags + $existingTags) | Sort-Object -Unique | Where-Object {![String]::IsNullOrWhiteSpace($_)}
        $_.tags = $tags
    }

    $params = Get-Params $GatewayEndpoint $Credential
    $params.method = "Put"
    $params.body = ConvertTo-Json @($connections)
    $params.ContentType = "application/json"

    Try {
        $response = Invoke-WebRequest @params
    }
    Catch {
        Try {
            # $error = ConvertFrom-Json $_

            # TODO: Replace this with Test-Json cmdlet introduced in PowerShell 6.0+ after upgrade
            $validJson = $true
        }
        Catch {
            $validJson = $false
        }

        if ($validJson) {
            throw $error.error.message
        } else {
            throw $_
        }
    }

    if ($response) {
        if ($response.StatusCode -ne 200 ) {
            throw "Failed to import the connections"
        }
        $content = ConvertFrom-Json $response
        if ($content -and $content.errors) {
            Write-Host "The operation partially succeeded with errors:"
            Write-Warning ($content.errors | Format-List * | Out-String)
        }
        else {
            Write-Host "Import connections succeeded"
        }
        if ($prune) {
            $connectionsImported = $connections.id
            $connectionsRemove = $connectionsResult.value | Where-Object { $_.name -notin $connectionsImported }
            $connectionsRemove | ForEach-Object {
                Remove-Connection $GatewayEndpoint $_.name $Credential
            }
        }
    }
}

# Export-ModuleMember -Function Export-Connection
# Export-ModuleMember -Function Import-Connection


# Load the Hyper-V module
Import-Module Hyper-V

# Define the Get-WACVMVirtualMachine function
function Get-WACVMVirtualMachine {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $vmId
    )

    Set-StrictMode -Version 5.0
    Import-Module Hyper-V -ErrorAction SilentlyContinue

    function setupScriptEnv() {
        # Placeholder for environment setup if needed
    }

    function cleanupScriptEnv() {
        # Placeholder for environment cleanup if needed
    }

    function isDisaggregatedStorageUsed($vm) {
        $configPath = $vm.ConfigurationLocation
        if ($configPath.StartsWith("\\")) {
            return $true
        }

        $hardDisks = $vm | Get-VMHardDiskDrive -ErrorAction SilentlyContinue -ErrorVariable err

        if (-not($err)) {
            foreach ($hardDisk in $hardDisks) {
                if ($hardDisk.Path.StartsWith("\\")) {
                    return $true
                }
            }
        } else {
            Write-Host "Couldn't retrieve hard disks for VM $($vm.Name). Errors: $err." -ForegroundColor Red
            Write-Error @($err)[0]
        }

        return $false
    }

    function updateHeatBeatValue([int] $heatBeatValue) {
        $isDownlevel = [Environment]::OSVersion.Version.Major -lt 10
        if ($isDownlevel) {
            return $heatBeatValue + 1
        }
        return $heatBeatValue
    }

    function main([string] $vmId) {
        $err = $null

        $vm = Get-VM -Id $vmId -ErrorAction SilentlyContinue -ErrorVariable err | `
            Select-Object Name, CPUUsage, MemoryAssigned, MemoryDemand, State, Status, CreationTime, Uptime, Version, `
                DynamicMemoryEnabled, MemoryMaximum, MemoryMinimum, MemoryStartup, ProcessorCount, Generation, `
                ComputerName, CheckpointFileLocation, ConfigurationLocation, SmartPagingFilePath, OperationalStatus, `
                IsClustered, `
            @{Name = "DisaggregatedStorage"; Expression = { isDisaggregatedStorageUsed $_ } }, `
            @{Name = "Heartbeat"; Expression = { updateHeatBeatValue $_.Heartbeat } }

        if ($err) {
            Write-Host "Couldn't retrieve the VM with Id $vmId. Errors: $err." -ForegroundColor Red
            Write-Error @($err)[0]
            return @{}
        }

        return $vm
    }

    setupScriptEnv

    try {
        $module = Get-Module -Name Hyper-V -ErrorAction SilentlyContinue -ErrorVariable err
        if ($module) {
            return main $vmId
        } else {
            Write-Host "The required PowerShell module (Hyper-V) was not found." -ForegroundColor Red
            Write-Error "Hyper-V module is required."
            return @{}
        }
    } finally {
        cleanupScriptEnv
    }
}

# Define the output file path relative to the script's root directory
$outputFile = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.csv"

# Initialize a list to store the VM details
$vmDetails = [System.Collections.Generic.List[PSCustomObject]]::new()

# Get all VMs on the Hyper-V server
$vms = Get-VM

# Iterate through each VM and gather its name, host name, and IP address
foreach ($vm in $vms) {
    $vmId = $vm.VMId
    $vmDetailsObject = Get-WACVMVirtualMachine -vmId $vmId

    if ($vmDetailsObject) {
        $vmName = $vmDetailsObject.Name
        $vmHostName = $vmDetailsObject.ComputerName
        $vmNetworkAdapters = Get-VMNetworkAdapter -VMName $vmName
        $vmIPAddresses = $vmNetworkAdapters | Select-Object -ExpandProperty IPAddresses

        foreach ($ip in $vmIPAddresses) {
            if ($ip -ne $null -and $ip -ne "") {
                $vmDetails.Add([PSCustomObject]@{
                    HostName  = $vmHostName
                    VMName    = $vmName
                    IPAddress = $ip
                })
            }
        }
    }
}

# Export the VM details to a CSV file
$vmDetails | Export-Csv -Path $outputFile -NoTypeInformation

# Output a message indicating the completion of the export
Write-Host "VM host names and IP addresses have been exported to $outputFile" -ForegroundColor Green




