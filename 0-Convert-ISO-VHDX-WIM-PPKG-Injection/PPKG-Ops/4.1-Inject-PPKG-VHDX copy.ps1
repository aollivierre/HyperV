function Validate-VHDMount {
    param (
        [Parameter(Mandatory = $true)]
        [string]$VHDXPath
    )

    # Check if the VHDX is mounted
    $vhd = Get-VHD -Path $VHDXPath -ErrorAction SilentlyContinue
    if ($vhd -and $vhd.Attached) {
        Write-Host "VHDX is mounted: $VHDXPath" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "VHDX is not mounted: $VHDXPath" -ForegroundColor Red
        return $false
    }
}

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

        # Validate if the VHDX is already mounted
        if (Validate-VHDMount -VHDXPath $VhdxPath) {
            throw "The VHDX file is already mounted. Please dismount it before proceeding."
        }

        # Mount the VHDX file
        Write-Host "Mounting VHDX file: $VhdxPath" -ForegroundColor Cyan
        $disk = Mount-VHD -Path $VhdxPath -Passthru | Get-Disk

        if ($null -eq $disk) {
            throw "Failed to mount VHDX file: $VhdxPath"
        }

        # Get the drive letter assigned to the VHDX
        $partition = Get-Partition -DiskNumber $disk.Number | Get-Volume | Where-Object { $_.DriveLetter -eq 'H' } | Select-Object -First 1
        $DriveLetter = $partition.DriveLetter
        if (-Not $DriveLetter) {
            throw "Failed to get the drive letter for the mounted VHDX."
        }

        # Add the provisioning package
        $ProvisioningPackageDestination = "${DriveLetter}:\Recovery\AutoApply"
        Write-Host "Copying provisioning package to: $ProvisioningPackageDestination" -ForegroundColor Cyan

        # Create the directory if it does not exist
        if (-Not (Test-Path -Path $ProvisioningPackageDestination)) {
            New-Item -ItemType Directory -Path $ProvisioningPackageDestination -Force
        }

        # Copy the provisioning package
        Copy-Item -Path $ProvisioningPackagePath -Destination $ProvisioningPackageDestination -Force

        Write-Host "Provisioning package added successfully to $ProvisioningPackageDestination." -ForegroundColor Green

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
