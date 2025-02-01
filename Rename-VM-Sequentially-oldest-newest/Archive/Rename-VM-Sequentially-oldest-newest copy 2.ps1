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
    # Format the new name with a three-digit prefix, ensuring it starts with the numbers sequentially
    $newName = '{0:D3} - VM' -f $counter

    # Display the intended new name for preview
    Write-Host "What if: Renaming" $VM.Name "to" $newName

    # Uncomment the line below to actually rename the VMs, after you're confident it works as expected
    # Rename-VM -VMName $VM.Name -NewName $newName

    # Increment the counter
    $counter++
}

Write-Host "Renaming simulation complete. Uncomment the 'Rename-VM' line to apply changes."
