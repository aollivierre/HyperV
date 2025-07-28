# First, let's create the parent data disk if it doesn't exist
$parentPath = "D:\VM\Setup\VHDX\DataDiskParent_256GB.vhdx"

if (-not (Test-Path $parentPath)) {
    Write-Host "Creating parent data disk..." -ForegroundColor Yellow
    & "D:\Code\HyperV\2-Create-HyperV_VM\Latest\Create-DataDiskParent.ps1" -Path $parentPath
}

# Now run the main script with a dual disk config
Write-Host "`nRunning VM creation with dual disk config..." -ForegroundColor Cyan
& "D:\Code\HyperV\2-Create-HyperV_VM\Latest\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1" -ConfigurationPath "D:\Code\HyperV\2-Create-HyperV_VM\Latest" -UseSmartDefaults -AutoSelectDrive