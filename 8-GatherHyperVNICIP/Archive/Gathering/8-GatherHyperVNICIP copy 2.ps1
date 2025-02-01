# Load the necessary Windows Admin Center module
# Import-Module "$env:ProgramFiles\windows admin center\PowerShell\Modules\ConnectionTools"
Import-Module "C:\Program Files\Windows Admin Center\PowerShell\Modules\ConnectionTools\ConnectionTools.psm1"

# Define the output file path relative to the script's root directory
$outputFile = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.csv"

# Initialize a list to store the VM details
$vmDetails = [System.Collections.Generic.List[PSCustomObject]]::new()

# Get all connections managed by Windows Admin Center
$connections = Get-WACConnection

# Filter the connections to get only VMs
$vms = $connections | Where-Object { $_.Type -eq 'msft.sme.connection-type.server' }

# Iterate through each VM and gather its name, host name, and IP address
foreach ($vm in $vms) {
    $vmName = $vm.Name
    $vmHostName = $vm.FQDN
    $vmNetworkAdapters = Get-WACVMNetworkAdapter -VMName $vmName
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
