# Define the output file paths relative to the script's root directory
$outputCsvFile = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.csv"
$outputTxtFile = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.txt"

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

# Display the VM details in GridView
$vmDetails | Out-GridView -Title "VM Host Names and IP Addresses"

# Output the VM details to the console
$vmDetails | Format-Table -AutoSize

# Output the hosts file content to the console
Get-Content -Path $outputTxtFile | Write-Output

# Open the text file using VS Code
Start-Process "code" -ArgumentList $outputTxtFile

# Output a message indicating the completion of the export
Write-Host "VM host names and IP addresses have been exported to $outputCsvFile and $outputTxtFile" -ForegroundColor Green












function Execute-RemoteScript {
    param (
        [string]$remoteHost = "NNOTT-LLW-SL08",
        [string]$username = "share",
        [string]$password = "Default1234"
    )

    # Local script paths based on $PSScriptRoot
    $localScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Update-RemoteHostsFileCommand.ps1"
    $localHostEntriesFilePath = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.txt"

    # Read the content of the local script and host entries file
    $scriptContent = Get-Content -Path $localScriptPath -Raw
    $hostEntries = Get-Content -Path $localHostEntriesFilePath

    # Convert credentials to a PSCredential object
    $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)

    # Method 1: Invoke-Command
    Write-Host "Method 1: Invoke-Command - Start"
    Invoke-Command -ComputerName $remoteHost -Credential $credential -ScriptBlock {
        param ($scriptContent, $hostEntries)

        # Define the function to update the hosts file
        $updateHostsScript = [scriptblock]::Create($scriptContent)
        . $updateHostsScript

        # Define the paths
        $remoteHostFilePath = "C:\Windows\System32\drivers\etc\hosts"

        # Call the function to update the remote hosts file with entries from the provided content
        Update-RemoteHostsFileCommand -remoteHostFilePath $remoteHostFilePath -hostEntries $hostEntries
    } -ArgumentList $scriptContent, $hostEntries
    Write-Host "Method 1: Invoke-Command - End"
}

# Main script
Execute-RemoteScript -remoteHost "NNOTT-LLW-SL08" -username "share" -password "Default1234"

















