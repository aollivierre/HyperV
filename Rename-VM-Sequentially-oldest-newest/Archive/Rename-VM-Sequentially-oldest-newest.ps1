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
    # Format the new name with a three-digit prefix and a dash
    $newName = '{0:D3} - {1}' -f $counter, $VM.Name

    # Rename the VM
    Rename-VM -VMName $VM.Name -NewName $newName -WhatIf

    # Increment the counter
    $counter++
}

Write-Host "Renaming complete. Please remove the `-WhatIf` parameter to apply changes."
