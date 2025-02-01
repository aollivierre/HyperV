# Define the output file paths relative to the script's root directory
$outputCsvFile = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.csv"
$outputTxtFile = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.txt"
$outputXMLFile = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.XML"

# Prompt the user to include IPv6 addresses
$includeIPv6 = Read-Host "Would you like to include IPv6 addresses? (yes/no)"
$includeIPv6 = $includeIPv6 -eq "yes"

# Initialize a list to store the VM details
$vmDetails = [System.Collections.Generic.List[PSCustomObject]]::new()
$hostsFileLines = [System.Collections.Generic.List[string]]::new()

# Function to get all VM DNS names and their IDs
function Get-AllVMDNSName {
    $WMIVMs = Get-CimInstance -Namespace root\virtualization\v2 -ClassName Msvm_KvpExchangeComponent
    $VMDNShostnameData = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($WMIVM in $WMIVMs) {
        $VMDNSname = ($WMIVM.GuestIntrinsicExchangeItems | ConvertFrom-StringData)[1].Values
        $VMDNSname = (($VMDNSname -split ">")[5] -split "<")[0]
        
        $VMDNSAuditData = [pscustomobject]@{
            VMid    = $WMIVM.SystemName
            DNSName = $VMDNSname
        }
        $VMDNShostnameData.Add($VMDNSAuditData)
    }

    return $VMDNShostnameData
}

# Get all VM DNS names and their IDs
$VMDNSNames = Get-AllVMDNSName

# Get all VMs on the Hyper-V server
$vms = Get-VM

# Iterate through each VM and gather its name, host name, and IP address
foreach ($vm in $vms) {
    $vmName = $vm.Name
    $vmId = $vm.VMId

    # Find the DNS name corresponding to the VM ID
    $foundVM = $VMDNSNames | Where-Object { $_.VMid -eq $vmId }
    $vmHostName = $foundVM.DNSName

    # Retrieve the IP addresses of the VM
    $vmNetworkAdapters = Get-VMNetworkAdapter -VMName $vmName
    $vmIPAddresses = $vmNetworkAdapters | Select-Object -ExpandProperty IPAddresses

    foreach ($ip in $vmIPAddresses) {
        $isIPv6 = $ip.Contains(":")
        if ($null -ne $ip -and $ip -ne "" -and ($includeIPv6 -or -not $isIPv6)) {
            $vmDetails.Add([pscustomobject]@{
                HostName  = $vmHostName
                VMName    = $vmName
                IPAddress = $ip
            })
            $hostsFileLines.Add("$ip $vmHostName # VM Name: $vmName")
        }
    }
}

# Export the VM details to a CSV file
$vmDetails | Export-Csv -Path $outputCsvFile -NoTypeInformation

# Export the VM details to a text file in hosts file format
$hostsFileLines | Out-File -FilePath $outputTxtFile -Encoding utf8

# Export the VM details to a XML file
$vmDetailsHashTable = @{}
foreach ($vm in $vmDetails) {
    $vmDetailsHashTable.Add($vm.VMName, @{
        HostName  = $vm.HostName
        IPAddress = $vm.IPAddress
    })
}
$vmDetailsHashTable | Export-Clixml -Path $outputXMLFile

# Display the VM details in GridView
$vmDetails | Out-GridView -Title "VM Host Names and IP Addresses"

# Output the VM details to the console
$vmDetails | Format-Table -AutoSize

# Output the hosts file content to the console
Get-Content -Path $outputTxtFile | Write-Output

# Open the text file using VS Code
Start-Process "code" -ArgumentList $outputTxtFile

# Output a message indicating the completion of the export
Write-Host "VM host names and IP addresses have been exported to $outputCsvFile, $outputTxtFile, and $outputXMLFile" -ForegroundColor Green


# $DBG

function Update-HostsFile {
    param (
        [string]$remoteHost,
        [PSCredential]$adminCredential,
        [string]$scriptContent1,
        [PSCustomObject[]]$hostEntries
    )

    # Invoke-Command to update hosts file using PowerShell 7 with admin credentials
    Write-Host "Updating hosts file - Start"
    Invoke-Command -ComputerName $remoteHost -Credential $adminCredential -ConfigurationName 'PowerShell.7' -ScriptBlock {
        param ($scriptContent1, $hostEntries)

        # Define the function to update the hosts file
        $updateHostsScript = [scriptblock]::Create($scriptContent1)
        . $updateHostsScript

        # Define the remote hosts file path
        $remoteHostFilePath = "C:\Windows\System32\drivers\etc\hosts"

        # Call the function with the provided content
        Update-RemoteHostsFileCommand -remoteHostFilePath $remoteHostFilePath -hostEntries $hostEntries
    } -ArgumentList $scriptContent1, $hostEntries
    Write-Host "Updating hosts file - End"
}


function Create-RDPSessionsRemote {
    param (
        [string]$remoteHost,
        [PSCredential]$standardCredential,
        [string]$scriptContent2,
        [PSCustomObject[]]$hostEntries
    )

    # Invoke-Command to create RDP sessions using PowerShell 7 with standard user credentials
    Write-Host "Creating RDP sessions - Start"
    Invoke-Command -ComputerName $remoteHost -Credential $standardCredential -ConfigurationName 'PowerShell.7' -ScriptBlock {
        param ($scriptContent2, $hostEntries)

        # Define the function to create RDP sessions
        $createRDPSessionsScript = [scriptblock]::Create($scriptContent2)
        . $createRDPSessionsScript

        # Call the function with the provided content
        Create-RDPSessions -hostEntries $hostEntries
    } -ArgumentList $scriptContent2, $hostEntries
    Write-Host "Creating RDP sessions - End"
}

function Execute-RemoteScript {
    # Load the secrets from the secrets.psd1 file
    $secretsPath = Join-Path -Path $PSScriptRoot -ChildPath "secrets.psd1"
    $secrets = Import-PowerShellDataFile -Path $secretsPath

    # Extract credentials
    $remoteHost = $secrets.RemoteHost
    $adminUsername = $secrets.AdminUsername
    $adminPassword = $secrets.AdminPassword
    $standardUsername = $secrets.StandardUsername
    $standardPassword = $secrets.StandardPassword

    # Local script paths based on $PSScriptRoot
    $localScriptPath1 = Join-Path -Path $PSScriptRoot -ChildPath "Update-RemoteHostsFileCommand.ps1"
    $localScriptPath2 = Join-Path -Path $PSScriptRoot -ChildPath "Create-RDPSessions.ps1"
    $localHostEntriesFilePath = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.csv"

    # Read the content of the local scripts
    $scriptContent1 = Get-Content -Path $localScriptPath1 -Raw
    $scriptContent2 = Get-Content -Path $localScriptPath2 -Raw

    # Import the host entries from the CSV file
    $hostEntriesData = Import-Csv -Path $localHostEntriesFilePath

    # Print the imported data to verify its structure and contents
    Write-Host "Imported host entries data:" -ForegroundColor Yellow
    $hostEntriesData | Format-Table -AutoSize | Out-String | Write-Host

    # Convert admin credentials to a PSCredential object
    $adminSecurePassword = ConvertTo-SecureString -String $adminPassword -AsPlainText -Force
    $adminCredential = New-Object System.Management.Automation.PSCredential ($adminUsername, $adminSecurePassword)

    # Convert standard user credentials to a PSCredential object
    $standardSecurePassword = ConvertTo-SecureString -String $standardPassword -AsPlainText -Force
    $standardCredential = New-Object System.Management.Automation.PSCredential ($standardUsername, $standardSecurePassword)

    # Update hosts file using admin credentials
    Update-HostsFile -remoteHost $remoteHost -adminCredential $adminCredential -scriptContent1 $scriptContent1 -hostEntries $hostEntriesData

    # Create RDP sessions using standard user credentials
    Create-RDPSessionsRemote -remoteHost $remoteHost -standardCredential $standardCredential -scriptContent2 $scriptContent2 -hostEntries $hostEntriesData
}

# Main script
Execute-RemoteScript