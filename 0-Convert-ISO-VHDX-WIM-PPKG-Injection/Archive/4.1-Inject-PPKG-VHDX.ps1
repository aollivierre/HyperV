function Mount-VHDXAndAddPPKG {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MountPoint,

        [Parameter(Mandatory = $true)]
        [string]$VhdxPath,

        [Parameter(Mandatory = $true)]
        [string]$ProvisioningPackagePath
    )

    try {
        # Create mount directory if it doesn't exist
        if (-Not (Test-Path -Path $MountPoint)) {
            New-Item -ItemType Directory -Path $MountPoint
        }

        # Mount the VHDX file
        Write-Host "Mounting VHDX file: $VhdxPath" -ForegroundColor Cyan
        Mount-VHD -Path $VhdxPath -PassThru | Get-Disk | Initialize-Disk -PartitionStyle MBR -PassThru -ErrorAction Stop | Out-Null
        New-Partition -DiskNumber (Get-Disk | Where-Object { $_.OperationalStatus -eq 'Online' -and $_.PartitionStyle -eq 'RAW' }).Number -UseMaximumSize -AssignDriveLetter | Out-Null
        $DriveLetter = (Get-Partition -DiskNumber (Get-Disk | Where-Object { $_.OperationalStatus -eq 'Online' -and $_.PartitionStyle -eq 'MBR' }).Number | Get-Volume).DriveLetter
        if (-Not $DriveLetter) {
            throw "Failed to assign drive letter."
        }

        # Format the volume
        Write-Host "Formatting the volume: ${DriveLetter}:" -ForegroundColor Cyan
        Format-Volume -DriveLetter $DriveLetter -FileSystem NTFS -NewFileSystemLabel "Windows" -Confirm:$false -ErrorAction Stop | Out-Null

        # Add the provisioning package
        $ProvisioningPackageDestination = "${DriveLetter}:\Recovery\AutoApply\RunPSOOBEv3.ppkg"
        Write-Host "Copying provisioning package to: $ProvisioningPackageDestination" -ForegroundColor Cyan
        Copy-Item -Path $ProvisioningPackagePath -Destination $ProvisioningPackageDestination -Force

        Write-Host "Provisioning package added successfully." -ForegroundColor Green

        # Dismount the VHDX file
        Write-Host "Dismounting VHDX file: $VhdxPath" -ForegroundColor Cyan
        Dismount-VHD -Path $VhdxPath

        Write-Host "VHDX has been successfully updated with the provisioning package" -ForegroundColor Green
    }
    catch {
        Write-Error "An error occurred: $_"

        # Unmount the VHDX file without committing changes if an error occurs
        try {
            Dismount-VHD -Path $VhdxPath -ErrorAction SilentlyContinue
        }
        catch {
            Write-Error "Failed to dismount VHDX file: $_"
        }
        exit 1
    }
    finally {
        # Clean up
        if (Test-Path -Path $MountPoint) {
            Remove-Item -Path $MountPoint -Recurse -Force
        }
        Write-Host "Cleanup completed." -ForegroundColor Green
    }
}

# Define a hashtable for splatting
$params = @{
    MountPoint              = "C:\Mount"
    VhdxPath                = "D:\VM\Setup\VHDX\Win11_23H2_English_x64_Nov_17_2023-100GB-unattend-Professional.VHDX"
    ProvisioningPackagePath = "D:\VM\Setup\PPKG\RunPSOOBEv3.ppkg"
}

# Call the function using splatting
Mount-VHDXAndAddPPKG @params
