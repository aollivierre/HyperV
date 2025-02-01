# Define the output file path relative to the script's root directory
$outputFile = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.csv"

# Initialize a list to store the VM details
$vmDetails = [System.Collections.Generic.List[PSCustomObject]]::new()

# Get all VMs on the Hyper-V server
$vms = Get-VM

# Iterate through each VM and gather its name, host name, and IP address
foreach ($vm in $vms) {
    $vmName = $vm.Name
    $vmId = $vm.VMId

    # Retrieve the Hyper-V host name from the registry inside the VM
    $vmHostName = Invoke-Command -VMName $vmName -ScriptBlock {
        try {
            $hostName = (Get-Item "HKLM:SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters").GetValue("HostName")
            return $hostName
        } catch {
            Write-Host "Failed to retrieve the host name for VM $using:vmName" -ForegroundColor Red
            return $null
        }
    }

    # Retrieve the IP addresses of the VM
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
