# Define the output file path relative to the script's root directory
$outputFile = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.csv"

# Initialize a list to store the VM details
$vmDetails = [System.Collections.Generic.List[PSCustomObject]]::new()

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
        }
    }
}

# Export the VM details to a CSV file
$vmDetails | Export-Csv -Path $outputFile -NoTypeInformation

# Output a message indicating the completion of the export
Write-Host "VM host names and IP addresses have been exported to $outputFile" -ForegroundColor Green
