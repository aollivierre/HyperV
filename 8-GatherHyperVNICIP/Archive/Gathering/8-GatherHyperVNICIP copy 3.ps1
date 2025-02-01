# Load the Windows Admin Center ConnectionTools module
# Import-Module "C:\Program Files\Windows Admin Center\PowerShell\Modules\ConnectionTools\ConnectionTools.psm1"


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
            Write-Warning ($content.errors | fl * | Out-String)
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





# Define the output file path relative to the script's root directory
$outputFile = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.csv"

# Initialize a list to store the VM details
$vmDetails = [System.Collections.Generic.List[PSCustomObject]]::new()

# Get all connections managed by Windows Admin Center
$connections = Get-Connection -GatewayEndpoint "https://localhost:6516"

# Filter the connections to get only VMs
$vms = $connections | Where-Object { $_.Type -eq 'msft.sme.connection-type.server' }

# Iterate through each VM and gather its name, host name, and IP address
foreach ($vm in $vms) {
    $vmName = $vm.Name
    $vmHostName = $vm.Name
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

# Export the VM details to a CSV file
$vmDetails | Export-Csv -Path $outputFile -NoTypeInformation

# Output a message indicating the completion of the export
Write-Host "VM host names and IP addresses have been exported to $outputFile" -ForegroundColor Green
