# # PowerShell script to import a specific VM using the provided .vmcx file

# # Path to the .vmcx file
# $vmcxFilePath = "D:\VM\Test00900-macOSX64_29-09-23_21_43_11\Test00900-macOSX64_29-09-23_21_43_11\Virtual Machines\C4609F45-6C47-4400-A582-DDE48CA29FBD.vmcx"

# # Import the VM
# Import-VM -Path $vmcxFilePath -Copy -GenerateNewId

# Write-Host "Imported VM from $vmcxFilePath" -ForegroundColor Green



# import-VM -Path "D:\VM\Test00900-macOSX64_29-09-23_21_43_11\Test00900-macOSX64_29-09-23_21_43_11\Virtual Machines\C4609F45-6C47-4400-A582-DDE48CA29FBD.vmcx" -Copy -VhdDestinationPath "D:\VM\Test00900-macOSX64_29-09-23_21_43_11" -VirtualMachinePath "D:\VM\Test00900-macOSX64_29-09-23_21_43_11"


# import-VM -Path "D:\VM\Test0014CNA-AADJ_16-08-23_07_08_22\Test0014CNA-AADJ_16-08-23_07_08_22\Virtual Machines\03E00F6C-535E-41BC-A0E7-2FCEDE137A5E.vmcx" -Copy -VhdDestinationPath "D:\VM\Test0014CNA-AADJ_16-08-23_07_08_22" -VirtualMachinePath "D:\VM\Test0014CNA-AADJ_16-08-23_07_08_22\Test0014CNA-AADJ_16-08-23_07_08_22"


# import-VM -Path "D:\VM\nva-AADJ-Abdullah_20231119_180546\nva-AADJ-Abdullah_20231119_180546\Virtual Machines\879DB75E-0466-45C5-9ADB-8D33EB40C46C.vmcx" -Copy -VhdDestinationPath "D:\VM\nva-AADJ-Abdullah_20231119_180546" -VirtualMachinePath "D:\VM\nva-AADJ-Abdullah_20231119_180546\nova-AADJ-Abdullah_20231119_180546"




# Creating the hashtable for splatting
# $importVMParams = @{
#     Path = "D:\VM\nva-AADJ-Abdullah_20231119_180546\nva-AADJ-Abdullah_20231119_180546\Virtual Machines\879DB75E-0466-45C5-9ADB-8D33EB40C46C.vmcx"
#     Copy = $true
#     VhdDestinationPath = "D:\VM\nva-AADJ-Abdullah_20231119_180546"
#     VirtualMachinePath = "D:\VM\nva-AADJ-Abdullah_20231119_180546\nva-AADJ-Abdullah_20231119_180546"
# }

# Using splatting to pass parameters to Import-VM cmdlet
# Import-VM @importVMParams



# Define the base directory where your VMs are stored
# $baseDirectory = "D:\VM"

# # Get all VM directories in the base directory
# $vmDirectories = Get-ChildItem -Path $baseDirectory -Directory

# # Loop through each VM directory
# foreach ($vmDir in $vmDirectories) {
#     $vmcxFiles = Get-ChildItem -Path $vmDir.FullName -Filter *.vmcx -Recurse
#     foreach ($vmcxFile in $vmcxFiles) {
#         $vmPath = $vmcxFile.DirectoryName
#         $vmcxPath = $vmcxFile.FullName
#         $vhdDestinationPath = $vmDir.FullName

#         # Output the values
#         Write-Host "VM Directory: $vmDir"
#         Write-Host "VMCX File: $vmcxPath"
#         Write-Host "VHD Destination Path: $vhdDestinationPath"
#         Write-Host "Virtual Machine Path: $vmPath"

#         # Import-VM -Path $vmcxPath -Copy -VhdDestinationPath $vhdDestinationPath -VirtualMachinePath $vmPath
#     }
# }





# # Define the base directory where your VMs are stored
# $baseDirectory = "D:\VM"

# # Get all VM directories in the base directory
# $vmDirectories = Get-ChildItem -Path $baseDirectory -Directory

# # Initialize an array to store the VM data
# $vmData = @()

# # Loop through each VM directory
# foreach ($vmDir in $vmDirectories) {
#     $vmcxFiles = Get-ChildItem -Path $vmDir.FullName -Filter *.vmcx -Recurse
#     foreach ($vmcxFile in $vmcxFiles) {
#         $vmPath = $vmcxFile.DirectoryName
#         $vmcxPath = $vmcxFile.FullName
#         $vhdDestinationPath = $vmDir.FullName

#         # Create an object with VM data
#         $vmInfo = [PSCustomObject]@{
#             "VM Directory" = $vmDir.FullName
#             "VMCX File" = $vmcxPath
#             "VHD Destination Path" = $vhdDestinationPath
#             "Virtual Machine Path" = $vmPath
#         }

#         # Add the object to the array
#         $vmData += $vmInfo
#     }
# }

# # Output the VM data to a grid view
# $vmData | Out-GridView













# Define the base directory where your VMs are stored
# $baseDirectory = "D:\VM"

# # Get all VM directories in the base directory
# $vmDirectories = Get-ChildItem -Path $baseDirectory -Directory

# # Loop through each VM directory
# foreach ($vmDir in $vmDirectories) {
#     $vmName = $vmDir.Name
#     $vmcxFiles = Get-ChildItem -Path $vmDir.FullName -Filter *.vmcx -Recurse
#     foreach ($vmcxFile in $vmcxFiles) {
#         $vmPath = $vmcxFile.DirectoryName
#         $vmcxPath = $vmcxFile.FullName
#         $vhdDestinationPath = $vmDir.FullName

#         # Ask for confirmation before stopping and removing the VM
#         $confirmStopRemove = Read-Host "Do you want to stop and remove the VM '$vmName'? (y/n)"
#         if ($confirmStopRemove -eq "y") {
#             # Stop the VM
#             Stop-VM -Name $vmName -Force

#             # Remove the VM
#             Remove-VM -Name $vmName -Force
#         }

#         # Ask for confirmation before importing the VM
#         $confirmImport = Read-Host "Do you want to import the VM from $vmcxPath? (y/n)"
#         if ($confirmImport -eq "y") {
#             # Import the VM
#             Import-VM -Path $vmcxPath -Copy -VhdDestinationPath $vhdDestinationPath -VirtualMachinePath $vmPath
#         }
#     }
# }









# # Define the base directory where your VMs are stored
# $baseDirectory = "D:\VM"

# # Get all VM directories in the base directory
# $vmDirectories = Get-ChildItem -Path $baseDirectory -Directory

# # Initialize an array to store the VM data
# $vmData = @()

# # Loop through each VM directory
# foreach ($vmDir in $vmDirectories) {
#     $vmName = $vmDir.Name
#     $vmcxFiles = Get-ChildItem -Path $vmDir.FullName -Filter *.vmcx -Recurse
#     foreach ($vmcxFile in $vmcxFiles) {
#         $vmcxPath = $vmcxFile.FullName
#         $vhdDestinationPath = $vmDir.FullName
#         $virtualMachinePath = $vmcxFile.DirectoryName

#         # Create an object with VM data
#         $vmInfo = [PSCustomObject]@{
#             "VM Name" = $vmName
#             "VMCX File" = $vmcxPath
#             "VHD Destination Path" = $vhdDestinationPath
#             "Virtual Machine Path" = $virtualMachinePath
#         }

#         # Add the object to the array
#         $vmData += $vmInfo
#     }
# }

# # Output the VM data to a grid view
# $vmData | Out-GridView

# # Continue with the script based on user input
# foreach ($vm in $vmData) {
#     # Ask for confirmation before stopping and removing the VM
#     $confirmStopRemove = Read-Host "Do you want to stop and remove the VM '$($vm.'VM Name')'? (y/n)"
#     if ($confirmStopRemove -eq "y") {
#         # Stop the VM
#         Stop-VM -Name $($vm.'VM Name') -Force

#         # Remove the VM
#         Remove-VM -Name $($vm.'VM Name') -Force
#     }

#     # Ask for confirmation before importing the VM
#     $confirmImport = Read-Host "Do you want to import the VM from $($vm.'VMCX File')? (y/n)"
#     if ($confirmImport -eq "y") {
#         # Import the VM
#         Import-VM -Path $($vm.'VMCX File') -Copy -VhdDestinationPath $($vm.'VHD Destination Path') -VirtualMachinePath $($vm.'Virtual Machine Path')
#     }
# }




# # Define the base directory where your VMs are stored
# $baseDirectory = "D:\VM"

# # Get all VM directories in the base directory
# $vmDirectories = Get-ChildItem -Path $baseDirectory -Directory

# # Initialize an array to store the VM data
# $vmData = @()

# # Loop through each VM directory
# foreach ($vmDir in $vmDirectories) {
#     $vmName = $vmDir.Name
#     $vmcxFiles = Get-ChildItem -Path $vmDir.FullName -Filter *.vmcx -Recurse
#     foreach ($vmcxFile in $vmcxFiles) {
#         $vmcxPath = $vmcxFile.FullName
#         $vhdDestinationPath = $vmDir.FullName
#         $virtualMachinePath = $vmDir.FullName  # Set the virtual machine path to the VM directory

#         # Create an object with VM data
#         $vmInfo = [PSCustomObject]@{
#             "VM Name" = $vmName
#             "VMCX File" = $vmcxPath
#             "VHD Destination Path" = $vhdDestinationPath
#             "Virtual Machine Path" = $virtualMachinePath
#         }

#         # Add the object to the array
#         $vmData += $vmInfo
#     }
# }

# # Output the VM data to a grid view
# $vmData | Out-GridView

# # Continue with the script based on user input
# foreach ($vm in $vmData) {
#     # Ask for confirmation before stopping and removing the VM
#     $confirmStopRemove = Read-Host "Do you want to stop and remove the VM '$($vm.'VM Name')'? (y/n)"
#     if ($confirmStopRemove -eq "y") {
#         # Stop the VM
#         Stop-VM -Name $($vm.'VM Name') -Force

#         # Remove the VM
#         Remove-VM -Name $($vm.'VM Name') -Force
#     }

#     # Ask for confirmation before importing the VM
#     $confirmImport = Read-Host "Do you want to import the VM from $($vm.'VMCX File')? (y/n)"
#     if ($confirmImport -eq "y") {
#         # Import the VM
#         Import-VM -Path $($vm.'VMCX File') -Copy -VhdDestinationPath $($vm.'VHD Destination Path') -VirtualMachinePath $($vm.'Virtual Machine Path')
#     }
# }






# # Define the base directory where your VMs are stored
# $baseDirectory = "D:\VM"

# # Get all VM directories in the base directory
# $vmDirectories = Get-ChildItem -Path $baseDirectory -Directory

# # Initialize an array to store the VM data
# $vmData = @()

# # Loop through each VM directory
# foreach ($vmDir in $vmDirectories) {
#     $vmName = $vmDir.Name
#     $vmcxFiles = Get-ChildItem -Path $vmDir.FullName -Filter *.vmcx -Recurse
#     foreach ($vmcxFile in $vmcxFiles) {
#         $vmcxPath = $vmcxFile.FullName
#         $vhdDestinationPath = $vmDir.FullName
#         # Assuming the 'Virtual Machines' subfolder should be excluded from the virtual machine path
#         $virtualMachinePath = $vmDir.FullName

#         # Create an object with VM data
#         $vmInfo = [PSCustomObject]@{
#             "VM Name" = $vmName
#             "VMCX File" = $vmcxPath
#             "VHD Destination Path" = $vhdDestinationPath
#             "Virtual Machine Path" = $virtualMachinePath
#         }

#         # Add the object to the array
#         $vmData += $vmInfo
#     }
# }

# # Output the VM data to a grid view
# $vmData | Out-GridView

# # Continue with the script based on user input
# foreach ($vm in $vmData) {
#     # Ask for confirmation before stopping and removing the VM
#     $confirmStopRemove = Read-Host "Do you want to stop and remove the VM '$($vm.'VM Name')'? (y/n)"
#     if ($confirmStopRemove -eq "y") {
#         # Stop the VM
#         Stop-VM -Name $($vm.'VM Name') -Force

#         # Remove the VM
#         Remove-VM -Name $($vm.'VM Name') -Force
#     }

#     # Ask for confirmation before importing the VM
#     $confirmImport = Read-Host "Do you want to import the VM from $($vm.'VMCX File')? (y/n)"
#     if ($confirmImport -eq "y") {
#         # Splatting parameters for Import-VM
#         $importVMParams = @{
#             Path = $($vm.'VMCX File')
#             Copy = $true
#             VhdDestinationPath = $($vm.'VHD Destination Path')
#             VirtualMachinePath = $($vm.'Virtual Machine Path')
#         }

#         # Import the VM with splatting
#         Import-VM @importVMParams
#     }
# }



# # Define the base directory where your VMs are stored
# $baseDirectory = "D:\VM"

# # Get all VM directories in the base directory
# $vmDirectories = Get-ChildItem -Path $baseDirectory -Directory

# # Initialize an array to store the VM data
# $vmData = @()

# # Loop through each VM directory
# foreach ($vmDir in $vmDirectories) {
#     $vmName = $vmDir.Name
#     $vmcxFiles = Get-ChildItem -Path $vmDir.FullName -Filter *.vmcx -Recurse
#     foreach ($vmcxFile in $vmcxFiles) {
#         $vmcxPath = $vmcxFile.FullName
#         $vhdDestinationPath = $vmDir.FullName
#         $virtualMachinePath = Join-Path -Path $vhdDestinationPath -ChildPath $vmName  # Construct the Virtual Machine Path

#         # Create an object with VM data
#         $vmInfo = [PSCustomObject]@{
#             "VM Name" = $vmName
#             "VMCX File" = $vmcxPath
#             "VHD Destination Path" = $vhdDestinationPath
#             "Virtual Machine Path" = $virtualMachinePath
#         }

#         # Add the object to the array
#         $vmData += $vmInfo
#     }
# }

# # Output the VM data to a grid view
# $vmData | Out-GridView

# # Continue with the script based on user input
# foreach ($vm in $vmData) {
#     # Ask for confirmation before stopping and removing the VM
#     $confirmStopRemove = Read-Host "Do you want to stop and remove the VM '$($vm.'VM Name')'? (y/n)"
#     if ($confirmStopRemove -eq "y") {
#         # Stop the VM
#         Stop-VM -Name $($vm.'VM Name') -Force

#         # Remove the VM
#         Remove-VM -Name $($vm.'VM Name') -Force
#     }

#     # Ask for confirmation before importing the VM
#     $confirmImport = Read-Host "Do you want to import the VM from $($vm.'VMCX File')? (y/n)"
#     if ($confirmImport -eq "y") {
#         # Splatting parameters for Import-VM
#         $importVMParams = @{
#             Path = $($vm.'VMCX File')
#             Copy = $true
#             VhdDestinationPath = $($vm.'VHD Destination Path')
#             VirtualMachinePath = $($vm.'Virtual Machine Path')
#         }

#         # Import the VM with splatting
#         Import-VM @importVMParams
#     }
# }




# # Define the base directory where your VMs are stored
# $baseDirectory = "D:\VM"

# # Get all VM directories in the base directory
# $vmDirectories = Get-ChildItem -Path $baseDirectory -Directory

# # Initialize an array to store the VM data
# $vmData = @()

# # Loop through each VM directory
# foreach ($vmDir in $vmDirectories) {
#     $vmName = $vmDir.Name
#     $vmcxFiles = Get-ChildItem -Path $vmDir.FullName -Filter *.vmcx -Recurse
#     foreach ($vmcxFile in $vmcxFiles) {
#         $vmcxPath = $vmcxFile.FullName
#         $vhdDestinationPath = $vmDir.FullName
#         $virtualMachinePath = Join-Path -Path $vhdDestinationPath -ChildPath $vmName

#         # Create an object with VM data
#         $vmInfo = [PSCustomObject]@{
#             "VM Name"              = $vmName
#             "VMCX File"            = $vmcxPath
#             "VHD Destination Path" = $vhdDestinationPath
#             "Virtual Machine Path" = $virtualMachinePath
#         }

#         # Add the object to the array
#         $vmData += $vmInfo
#     }
# }

# # Output the VM data to a grid view
# $vmData | Out-GridView

# # Continue with the script based on user input
# foreach ($vm in $vmData) {
#     # Ask for confirmation before stopping and removing the VM
#     $confirmStopRemove = Read-Host "Do you want to stop and remove the VM '$($vm.'VM Name')'? (y/n)"
#     if ($confirmStopRemove -eq "y") {
#         Stop-VM -Name $($vm.'VM Name') -Force
#         Remove-VM -Name $($vm.'VM Name') -Force
#     }

#     # Ask for confirmation before importing the VM
#     $confirmImport = Read-Host "Do you want to import the VM from $($vm.'VMCX File')? (y/n)"
#     if ($confirmImport -eq "y") {
#         # Import the VM
#         #  Splatting parameters for Import-VM
#         $importVMParams = @{
#             Path               = $($vm.'VMCX File')
#             Copy               = $true
#             VhdDestinationPath = $($vm.'VHD Destination Path')
#             VirtualMachinePath = $($vm.'Virtual Machine Path')
#         }

#         # Import the VM with splatting
#         Import-VM @importVMParams

#     }
#         start-sleep -s 10

#         # Import-VM @vm.'VMCX File' @vm.'VHD Destination Path' @vm.'Virtual Machine Path'
#         # Delete saved states
#         Remove-VMSavedState -VMName $($vm.'VM Name') -Force

#         # Remove any DVD drives
#         Get-VMDvdDrive -VMName $($vm.'VM Name') | Remove-VMDvdDrive -Force
    
# }




# Define the base directory where your VMs are stored
$baseDirectory = "D:\VM"

# Get all VM directories in the base directory
$vmDirectories = Get-ChildItem -Path $baseDirectory -Directory

# Initialize an array to store the VM data
$vmData = @()

# Loop through each VM directory
foreach ($vmDir in $vmDirectories) {
    $vmName = $vmDir.Name
    $vmcxFiles = Get-ChildItem -Path $vmDir.FullName -Filter *.vmcx -Recurse
    foreach ($vmcxFile in $vmcxFiles) {
        $vmcxPath = $vmcxFile.FullName
        $vhdDestinationPath = $vmDir.FullName
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

