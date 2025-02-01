# PowerShell script to remove DVD drives from all VMs

# Retrieve all VMs
$vmList = Get-VM

# Loop through each VM
foreach ($vm in $vmList) {
    # Get all DVD drives attached to the VM
    $dvdDrives = Get-VMDvdDrive -VMName $vm.Name

    # Loop through each DVD drive and remove it
    foreach ($dvdDrive in $dvdDrives) {
        # Remove the DVD drive
        Remove-VMDvdDrive -VMName $vm.Name -ControllerNumber $dvdDrive.ControllerNumber -ControllerLocation $dvdDrive.ControllerLocation

        # Output the result
        Write-Host "Removed DVD Drive from VM: $($vm.Name)"
    }
}

# End of script