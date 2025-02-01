function Inject-PPKG-Into-VHDX {
    param (
        [string]$VhdxPath,
        [string]$ProvisioningPackagePath,
        [string]$DriveLetter = "H"
    )

    try {
        # Mount the VHDX file
        Write-Host "Mounting VHDX file: $VhdxPath" -ForegroundColor Cyan
        Mount-DiskImage -ImagePath $VhdxPath -PassThru | Out-Null
        Write-Host "VHDX file mounted successfully at drive: $DriveLetter" -ForegroundColor Green

        # Define the target directory within the mounted VHDX
        $TargetDirectory = "$($DriveLetter):\Recovery\Customizations"

        # Create target directory if it doesn't exist
        if (-Not (Test-Path -Path $TargetDirectory)) {
            New-Item -ItemType Directory -Path $TargetDirectory -Force
        }

        # Copy the provisioning package to the target directory
        Write-Host "Copying provisioning package: $ProvisioningPackagePath to $TargetDirectory" -ForegroundColor Yellow
        Copy-Item -Path $ProvisioningPackagePath -Destination $TargetDirectory -Force
        Write-Host "Provisioning package copied successfully." -ForegroundColor Green

        # Dismount the VHDX
        Write-Host "Dismounting VHDX file: $VhdxPath" -ForegroundColor Yellow
        Dismount-DiskImage -ImagePath $VhdxPath
        Write-Host "VHDX file dismounted successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "An error occurred: $_.Exception.Message" -ForegroundColor Red
    }
}

# Define paths
$VhdxPath = "D:\VM\Setup\VHDX\Win11_23H2_English_x64_Nov_17_2023-100GB-unattend-Professional.VHDX"
$ProvisioningPackagePath = "D:\VM\Setup\PPKG\RunPSOOBEv2.ppkg"

# Call the function to inject the PPKG into the VHDX
Inject-PPKG-Into-VHDX -VhdxPath $VhdxPath -ProvisioningPackagePath $ProvisioningPackagePath -DriveLetter "H"
