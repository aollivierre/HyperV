# Define the output file paths relative to the script's root directory
$outputCsvFile = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.csv"
$outputTxtFile = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.txt"

# Initialize a list to store the VM details
$vmDetails = [System.Collections.Generic.List[PSCustomObject]]::new()
$hostsFileLines = [System.Collections.Generic.List[string]]::new()

# Function to get all VM DNS names and their IDs
function Get-AllVMDNSName {
    $WMIVMs = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_KvpExchangeComponent
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
        if ($null -ne $ip -and $ip -ne "") {
            $vmDetails.Add([pscustomobject]@{
                HostName  = $vmHostName
                VMName    = $vmName
                IPAddress = $ip
            })
            $hostsFileLines.Add("$ip $vmHostName")
        }
    }
}

# Export the VM details to a CSV file
$vmDetails | Export-Csv -Path $outputCsvFile -NoTypeInformation

# Export the VM details to a text file in hosts file format
$hostsFileLines | Out-File -FilePath $outputTxtFile -Encoding utf8

# Display the VM details in GridView
$vmDetails | Out-GridView -Title "VM Host Names and IP Addresses"

# Output a message indicating the completion of the export
Write-Host "VM host names and IP addresses have been exported to $outputCsvFile and $outputTxtFile" -ForegroundColor Green
