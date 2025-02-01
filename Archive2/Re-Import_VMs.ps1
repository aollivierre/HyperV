# PowerShell script to re-import VMs based on the given directory structure

# Directory where the VMs are now located
$newVMBasePath = "D:\VM"

# Retrieve the list of VM directories
$vmDirectories = Get-ChildItem -Path $newVMBasePath -Directory

# Loop through each directory and import the VM
foreach ($vmDir in $vmDirectories) {
    # Construct the path to the 'Virtual Machines' subfolder based on the VM name
    $vmVirtualMachinePath = Join-Path -Path $vmDir.FullName -ChildPath "$($vmDir.Name)\Virtual Machines"

    # Check if the 'Virtual Machines' subfolder exists
    if (Test-Path -Path $vmVirtualMachinePath) {
        $vmcxFiles = Get-ChildItem -Path $vmVirtualMachinePath -Filter *.vmcx

        foreach ($vmcxFile in $vmcxFiles) {
            # Import the VM using the .vmcx file
            Import-VM -Path $vmcxFile.FullName -Copy -GenerateNewId

            Write-Host "Imported VM from $($vmcxFile.FullName)" -ForegroundColor Green
        }
    } else {
        Write-Host "No 'Virtual Machines' subfolder found for $($vmDir.Name) at $vmVirtualMachinePath" -ForegroundColor Yellow
    }
}

# End of script
