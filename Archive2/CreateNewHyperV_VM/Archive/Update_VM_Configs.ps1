# PowerShell script to update VM configuration and VHDX file paths
# Assumes that the new paths are in the D:\ drive and named after the VM name

# Retrieve all VMs
$vmList = Get-VM

# Loop through each VM
foreach ($vm in $vmList) {
    # Construct the new configuration and VHDX paths based on the VM name
    $vmName = $vm.Name
    $newConfigPath = "D:\VM\$vmName\$vmName.vmcx"
    $newVhdxPath = "D:\VM\$vmName\$vmName.vhdx"

    # Stop the VM if it's running
    Stop-VM -Name $vmName -Force

    # Update the VM configuration path
    Set-VM -Name $vmName -Path $newConfigPath

    # Update the VM hard disk path
    $vmHardDisk = Get-VMHardDiskDrive -VMName $vmName
    Set-VMHardDiskDrive -VMHardDiskDrive $vmHardDisk -Path $newVhdxPath

    # Output the update
    Write-Host "Updated VM: $vmName" -ForegroundColor Green
}

# End of script
