# Import the Hyper-V module
Import-Module Hyper-V

# Define the output file path
$outputFile = "D:\Code\CB\Hyper-V\8-GatherHyperVNICIP\VM_Hosts_IPs.csv"

# Initialize a list to store the VM details
$vmDetails = [System.Collections.Generic.List[PSCustomObject]]::new()

# Get all VMs on the Hyper-V server
$vms = Get-VM

# Iterate through each VM and gather its name and IP address
foreach ($vm in $vms) {
    $vmName = $vm.Name
    $vmNetworkAdapters = Get-VMNetworkAdapter -VMName $vmName
    $vmIPAddresses = $vmNetworkAdapters | Select-Object -ExpandProperty IPAddresses

    foreach ($ip in $vmIPAddresses) {
        $vmDetails.Add([PSCustomObject]@{
            VMName    = $vmName
            IPAddress = $ip
        })
    }
}

# Export the VM details to a CSV file
$vmDetails | Export-Csv -Path $outputFile -NoTypeInformation

# Output a message indicating the completion of the export
Write-Host "VM host names and IP addresses have been exported to $outputFile" -ForegroundColor Green
