# PowerShell script to import a specific VM using the provided .vmcx file

# Define the base directory where your VMs are stored
$baseDirectory = "D:\VM"

# Define the list of specific VM names to process
$specificVMs = @(
"Test0014CNA-AADJ_16-08-23_07_08_22", 
"Test0015Glebe-AADJ-PFMigration_21-08-23_12_33_43", 
"Test0020PMM-AADJ-Win11_02-09-23_06_27_03")

# Initialize an array to store the VM data
$vmData = @()

# Loop through each specified VM name
foreach ($vmName in $specificVMs) {
    # Construct the VM directory path
    $vmDirPath = Join-Path -Path $baseDirectory -ChildPath $vmName

    # Check if the directory exists
    if (Test-Path -Path $vmDirPath) {
        $vmcxFiles = Get-ChildItem -Path $vmDirPath -Filter *.vmcx -Recurse
        foreach ($vmcxFile in $vmcxFiles) {
            $vmcxPath = $vmcxFile.FullName
            $vhdDestinationPath = $vmDirPath
            $virtualMachinePath = Join-Path -Path $vhdDestinationPath -ChildPath $vmName

            # Create an object with VM data
            $vmInfo = [PSCustomObject]@{
                "VM Name"              = $vmName
                "VMCX File"            = $vmcxPath
                "VHD Destination Path" = $vhdDestinationPath
                "Virtual Machine Path" = $virtualMachinePath
            }

            # Add the object to the array
            $vmData += $vmInfo
        }
    } else {
        Write-Host "Directory for VM '$vmName' not found."
    }
}

# Output the VM data to a grid view
$vmData | Out-GridView

# Continue with the script based on user input
foreach ($vm in $vmData) {
    # Ask for confirmation before stopping and removing the VM
    $confirmStopRemove = Read-Host "Do you want to stop and remove the VM '$($vm.'VM Name')'? (y/n)"
    if ($confirmStopRemove -eq "y") {
        Stop-VM -Name $($vm.'VM Name') -Force
        Remove-VM -Name $($vm.'VM Name') -Force
    }

    # Ask for confirmation before importing the VM
    $confirmImport = Read-Host "Do you want to import the VM from $($vm.'VMCX File')? (y/n)"
    if ($confirmImport -eq "y") {
        # Splatting parameters for Import-VM
        $importVMParams = @{
            Path               = $($vm.'VMCX File')
            Copy               = $true
            VhdDestinationPath = $($vm.'VHD Destination Path')
            VirtualMachinePath = $($vm.'Virtual Machine Path')
        }

        # Import the VM with splatting
        Import-VM @importVMParams

        # Wait for 10 seconds to ensure VM operations are processed correctly
        Start-Sleep -Seconds 10

        # Delete saved states
        Remove-VMSavedState -VMName $($vm.'VM Name')

        # Remove any DVD drives
        Get-VMDvdDrive -VMName $($vm.'VM Name') | ForEach-Object {
            Remove-VMDvdDrive -VMName $($vm.'VM Name') -ControllerNumber $_.ControllerNumber -ControllerLocation $_.ControllerLocation
            Write-Host "Removed DVD Drive from VM: $($vm.'VM Name')"
        }
    }
}