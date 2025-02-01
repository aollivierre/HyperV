function Manage-VHDX {
    # Define paths
    $vhdxPath = "D:\VM\Setup\VHDX\Win11_23H2_English_x64_Nov_17_2023-100GB-unattend-Professional.VHDX"
    $newUnattendSource = "D:\Code\GitHub\CB\CB\Hyper-V\0-Convert-ISO-to-VHDX\Unattend\unattend.xml"
    $scriptPath = "D:\Code\GitHub\CB\CB\Hyper-V\2-Create-HyperV_VM\Latest\2-Create-HyperV_VM9-withlogging-Differencing-Windows.ps1"

    try {
        Write-Host "Mounting VHDX: $vhdxPath" -ForegroundColor Cyan
        Mount-VHD -Path $vhdxPath -Passthru
        Write-Host "VHDX mounted successfully." -ForegroundColor Green

        $drivePath = "H:\"
        Write-Host "Targeting operations to drive: $drivePath" -ForegroundColor Cyan

        $unattendPath = Join-Path -Path $drivePath -ChildPath "unattend.xml"
        if (Test-Path $unattendPath) {
            Write-Host "Removing existing unattend.xml..." -ForegroundColor Yellow
            Remove-Item $unattendPath -Force
            Write-Host "Existing unattend.xml removed." -ForegroundColor Green
        }

        Write-Host "Copying new unattend.xml to $drivePath" -ForegroundColor Yellow
        Copy-Item -Path $newUnattendSource -Destination $unattendPath
        Write-Host "New unattend.xml copied successfully." -ForegroundColor Green

        Write-Host "Dismounting VHDX..." -ForegroundColor Yellow
        Dismount-VHD -Path $vhdxPath
        Write-Host "VHDX dismounted." -ForegroundColor Green
    }
    catch {
        Write-Host "An error occurred: $_.Exception.Message" -ForegroundColor Red
        return
    }

    try {
        Write-Host "Executing script: $scriptPath" -ForegroundColor Cyan
        & $scriptPath
        Write-Host "Script execution complete." -ForegroundColor Green
    }
    catch {
        Write-Host "An error occurred during script execution: $_.Exception.Message" -ForegroundColor Red
    }
}

# Call the function to perform operations
Manage-VHDX
