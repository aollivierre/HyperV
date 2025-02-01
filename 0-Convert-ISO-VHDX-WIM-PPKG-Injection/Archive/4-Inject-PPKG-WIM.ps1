# Define paths
$MountPoint = "C:\Mount"
$WimFile = "D:\VM\Setup\WIM\install.wim"
$ProvisioningPackagePath = "D:\VM\Setup\PPKG\RunPSOOBEv3.ppkg"
$Index = 1  # Specify the index of the image you want to mount

# Create mount directory if it doesn't exist
if (-Not (Test-Path -Path $MountPoint)) {
    New-Item -ItemType Directory -Path $MountPoint
}

# Mount the WIM image
Write-Host "Mounting WIM file: $WimFile" -ForegroundColor Cyan
dism.exe /Mount-Wim /WimFile:$WimFile /index:$Index /MountDir:$MountPoint
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to mount WIM file." -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "WIM file mounted successfully." -ForegroundColor Green

# Add the provisioning package
Write-Host "Adding provisioning package: $ProvisioningPackagePath" -ForegroundColor Cyan
dism.exe /Image:$MountPoint /Add-ProvisioningPackage /PackagePath:$ProvisioningPackagePath
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to add provisioning package." -ForegroundColor Red
    # Unmount the WIM image without committing changes
    dism.exe /Unmount-Wim /MountDir:$MountPoint /Discard
    exit $LASTEXITCODE
}
Write-Host "Provisioning package added successfully." -ForegroundColor Green

# Commit changes and unmount the WIM image
Write-Host "Committing changes and unmounting WIM file..." -ForegroundColor Cyan
dism.exe /Unmount-Wim /MountDir:$MountPoint /Commit
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to commit changes and unmount WIM file." -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "WIM file unmounted and changes committed." -ForegroundColor Green

# Clean up
if (Test-Path -Path $MountPoint) {
    Remove-Item -Path $MountPoint -Recurse -Force
}
Write-Host "Cleanup completed." -ForegroundColor Green
