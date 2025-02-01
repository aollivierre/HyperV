# PowerShell script to update VHDX file paths for all Hyper-V VMs and output the changes

# Define the old and new drive letters
$oldDriveLetter = "C:"
$newDriveLetter = "D:"

# Retrieve all VMs
$vmList = Get-VM

# Loop through each VM
foreach ($vm in $vmList) {
    # Get the VM hard disk drives
    $vmDisks = Get-VMHardDiskDrive -VMName $vm.Name

    # Loop through each disk and update the path
    foreach ($disk in $vmDisks) {
        # Save the old path for reporting
        $oldPath = $disk.Path

        # Construct the new path by replacing the old drive letter with the new one
        $newPath = $disk.Path -replace [regex]::Escape($oldDriveLetter), $newDriveLetter

        # Update the VM hard disk path
        Set-VMHardDiskDrive -VMHardDiskDrive $disk -Path $newPath

        # Get the current timestamp
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Output the old and new paths with color coding and timestamp
        Write-Host "[$timestamp] VM Name: $($vm.Name)" -ForegroundColor Cyan
        Write-Host "[$timestamp] Old Path: $oldPath" -ForegroundColor Red
        Write-Host "[$timestamp] New Path: $newPath" -ForegroundColor Green
        Write-Host " " # Empty line for better readability
    }
}

# End of script