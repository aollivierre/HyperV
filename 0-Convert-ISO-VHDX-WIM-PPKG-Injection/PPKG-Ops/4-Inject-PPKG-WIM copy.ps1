function MountWIM-And-AddProvisioningPackage {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MountPoint,
        
        [Parameter(Mandatory = $true)]
        [string]$WimFile,
        
        [Parameter(Mandatory = $true)]
        [string]$ProvisioningPackagePath,
        
        [Parameter(Mandatory = $true)]
        [int]$Index
    )

    try {
        # Create mount directory if it doesn't exist
        if (-Not (Test-Path -Path $MountPoint)) {
            New-Item -ItemType Directory -Path $MountPoint
        }

        # Mount the WIM image
        Write-Host "Mounting WIM file: $WimFile" -ForegroundColor Cyan
        & "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe" /Mount-Wim /WimFile:$WimFile /index:$Index /MountDir:$MountPoint
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to mount WIM file."
        }
        Write-Host "WIM file mounted successfully." -ForegroundColor Green

        # Add the provisioning package
        Write-Host "Adding provisioning package: $ProvisioningPackagePath" -ForegroundColor Cyan
        & "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe" /Image:$MountPoint /Add-ProvisioningPackage /PackagePath:$ProvisioningPackagePath
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to add provisioning package."
        }
        Write-Host "Provisioning package added successfully." -ForegroundColor Green

        # Commit changes and unmount the WIM image
        Write-Host "Committing changes and unmounting WIM file..." -ForegroundColor Cyan
        & "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe" /Unmount-Wim /MountDir:$MountPoint /Commit
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to commit changes and unmount WIM file."
        }
        Write-Host "WIM file unmounted and changes committed." -ForegroundColor Green

    }
    catch {
        Write-Error "An error occurred: $_"
        
        # Unmount the WIM image without committing changes if an error occurs
        try {
            & "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe" /Unmount-Wim /MountDir:$MountPoint /Discard
        }
        catch {
            Write-Error "Failed to discard changes and unmount WIM file: $_"
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
    WimFile                 = "D:\VM\Setup\WIM\install.wim"
    ProvisioningPackagePath = "D:\VM\Setup\PPKG\RunPSOOBEv3.ppkg"
    Index                   = 1
}

# Call the function using splatting
MountWIM-And-AddProvisioningPackage @params
