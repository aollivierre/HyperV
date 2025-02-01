# Ensure the script is running with elevated privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run this script as an Administrator."
    exit
}

# Load the Hyper-V module
Import-Module Hyper-V

# Get all VMs and sort them by creation time
$VMs = Get-VM | Sort-Object -Property CreationTime

# Initialize the counter
$counter = 1

foreach ($VM in $VMs) {
    # Extract the original VM name excluding any existing numbering
    $originalName = $VM.Name -replace '^\d{3} - ', ''

    # Format the new name with a three-digit prefix, keeping the original VM name
    $newName = '{0:D3} - {1}' -f $counter, $originalName

    # Check if the VM is running
    if ($VM.State -eq 'Running') {
        Write-Host "Skipping $($VM.Name) because it is currently running. Consider shutting down the VM before renaming."
    } else {
        try {
            # Attempt to rename the VM
            Rename-VM -VMName $VM.Name -NewName $newName -ErrorAction Stop
            Write-Host "Successfully renamed $($VM.Name) to $newName"
        } catch {
            # Handle errors, such as permissions issues or conflicts
            Write-Host "Failed to rename $($VM.Name) to $newName. Error: $_"
        }
    }

    # Increment the counter
    $counter++
}
