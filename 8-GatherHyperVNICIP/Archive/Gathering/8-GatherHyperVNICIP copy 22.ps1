# # Define the output file paths relative to the script's root directory
# $outputCsvFile = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.csv"
# $outputTxtFile = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.txt"

# # Prompt the user to include IPv6 addresses
# $includeIPv6 = Read-Host "Would you like to include IPv6 addresses? (yes/no)"
# $includeIPv6 = $includeIPv6 -eq "yes"

# # Initialize a list to store the VM details
# $vmDetails = [System.Collections.Generic.List[PSCustomObject]]::new()
# $hostsFileLines = [System.Collections.Generic.List[string]]::new()

# # Function to get all VM DNS names and their IDs
# function Get-AllVMDNSName {
#     $WMIVMs = Get-CimInstance -Namespace root\virtualization\v2 -ClassName Msvm_KvpExchangeComponent
#     $VMDNShostnameData = [System.Collections.Generic.List[PSCustomObject]]::new()

#     foreach ($WMIVM in $WMIVMs) {
#         $VMDNSname = ($WMIVM.GuestIntrinsicExchangeItems | ConvertFrom-StringData)[1].Values
#         $VMDNSname = (($VMDNSname -split ">")[5] -split "<")[0]
        
#         $VMDNSAuditData = [pscustomobject]@{
#             VMid    = $WMIVM.SystemName
#             DNSName = $VMDNSname
#         }
#         $VMDNShostnameData.Add($VMDNSAuditData)
#     }

#     return $VMDNShostnameData
# }

# # Get all VM DNS names and their IDs
# $VMDNSNames = Get-AllVMDNSName

# # Get all VMs on the Hyper-V server
# $vms = Get-VM

# # Iterate through each VM and gather its name, host name, and IP address
# foreach ($vm in $vms) {
#     $vmName = $vm.Name
#     $vmId = $vm.VMId

#     # Find the DNS name corresponding to the VM ID
#     $foundVM = $VMDNSNames | Where-Object { $_.VMid -eq $vmId }
#     $vmHostName = $foundVM.DNSName

#     # Retrieve the IP addresses of the VM
#     $vmNetworkAdapters = Get-VMNetworkAdapter -VMName $vmName
#     $vmIPAddresses = $vmNetworkAdapters | Select-Object -ExpandProperty IPAddresses

#     foreach ($ip in $vmIPAddresses) {
#         $isIPv6 = $ip.Contains(":")
#         if ($null -ne $ip -and $ip -ne "" -and ($includeIPv6 -or -not $isIPv6)) {
#             $vmDetails.Add([pscustomobject]@{
#                 HostName  = $vmHostName
#                 VMName    = $vmName
#                 IPAddress = $ip
#             })
#             $hostsFileLines.Add("$ip $vmHostName # VM Name: $vmName")
#         }
#     }
# }

# # Export the VM details to a CSV file
# $vmDetails | Export-Csv -Path $outputCsvFile -NoTypeInformation

# # Export the VM details to a text file in hosts file format
# $hostsFileLines | Out-File -FilePath $outputTxtFile -Encoding utf8

# # Display the VM details in GridView
# $vmDetails | Out-GridView -Title "VM Host Names and IP Addresses"

# # Output the VM details to the console
# $vmDetails | Format-Table -AutoSize

# # Output the hosts file content to the console
# Get-Content -Path $outputTxtFile | Write-Output

# # Open the text file using VS Code
# Start-Process "code" -ArgumentList $outputTxtFile

# # Output a message indicating the completion of the export
# Write-Host "VM host names and IP addresses have been exported to $outputCsvFile and $outputTxtFile" -ForegroundColor Green


# # $DBG



function Execute-RemoteScript {
    # Load the secrets from the secrets.psd1 file
    $secretsPath = Join-Path -Path $PSScriptRoot -ChildPath "secrets.psd1"
    $secrets = Import-PowerShellDataFile -Path $secretsPath

    # Extract credentials
    $remoteHost = $secrets.RemoteHost
    $username = $secrets.Username
    $password = $secrets.Password

    # Local script paths based on $PSScriptRoot
    $localScriptPath1 = Join-Path -Path $PSScriptRoot -ChildPath "Update-RemoteHostsFileCommand.ps1"
    $localScriptPath2 = Join-Path -Path $PSScriptRoot -ChildPath "Create-RDPSessions.ps1"
    $localHostEntriesFilePath = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.txt"

    # Read the content of the local scripts and host entries file
    $scriptContent1 = Get-Content -Path $localScriptPath1 -Raw
    $scriptContent2 = Get-Content -Path $localScriptPath2 -Raw
    $hostEntries = Get-Content -Path $localHostEntriesFilePath

    # Convert credentials to a PSCredential object
    $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)

    # Method 1: Invoke-Command using PowerShell 7
    Write-Host "Method 1: Invoke-Command - Start"
    Invoke-Command -ComputerName $remoteHost -Credential $credential -ConfigurationName 'PowerShell.7' -ScriptBlock {
        param ($scriptContent1, $scriptContent2, $hostEntries)

        # Define the functions to update the hosts file and create RDP sessions
        $updateHostsScript = [scriptblock]::Create($scriptContent1)
        $createRDPSessionsScript = [scriptblock]::Create($scriptContent2)
        . $updateHostsScript
        . $createRDPSessionsScript

        # Define the paths
        $remoteHostFilePath = "C:\Windows\System32\drivers\etc\hosts"

        # Call the functions with the provided content
        Update-RemoteHostsFileCommand -remoteHostFilePath $remoteHostFilePath -hostEntries $hostEntries
        Create-RDPSessions -hostEntries $hostEntries
    } -ArgumentList $scriptContent1, $scriptContent2, $hostEntries
    Write-Host "Method 1: Invoke-Command - End"
}

# Main script
Execute-RemoteScript
