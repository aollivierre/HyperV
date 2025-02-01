# PowerShell script to list all VMs in Hyper-V and their associated disk locations

# Ensure the Hyper-V module is imported
Import-Module Hyper-V

# Retrieve all VMs
$vmList = Get-VM

# Prepare an array to hold VM and disk information
$vmDiskInfo = @()

# Loop through each VM to retrieve disk information
foreach ($vm in $vmList) {
    # Get the VM hard disk drives
    $vmDisks = Get-VMHardDiskDrive -VMName $vm.Name

    foreach ($disk in $vmDisks) {
        # Construct an object with VM and disk details
        $diskInfo = New-Object PSObject -Property @{
            VMName = $vm.Name
            DiskPath = $disk.Path
        }

        # Add the object to the array
        $vmDiskInfo += $diskInfo
    }
}

# Output the results to Out-GridView
$vmDiskInfo | Out-GridView

# End of script
