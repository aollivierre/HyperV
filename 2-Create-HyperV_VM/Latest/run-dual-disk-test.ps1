# List available configs
Write-Host "Available configuration files:" -ForegroundColor Yellow
Get-ChildItem "D:\Code\HyperV\2-Create-HyperV_VM\Latest\*.psd1" | 
    Where-Object { $_.Name -like "config-*" } | 
    ForEach-Object { Write-Host "  - $($_.Name)" }

# Check if our dual disk config exists
$dualDiskConfig = "D:\Code\HyperV\2-Create-HyperV_VM\Latest\config-example-dual-disk.psd1"
if (Test-Path $dualDiskConfig) {
    Write-Host "`nDual disk config found!" -ForegroundColor Green
    
    # Display its contents
    Write-Host "`nConfig contents:" -ForegroundColor Cyan
    $config = Import-PowerShellDataFile $dualDiskConfig
    Write-Host "  EnableDataDisk: $($config.EnableDataDisk)"
    Write-Host "  DataDiskType: $($config.DataDiskType)"
    Write-Host "  DataDiskParentPath: $($config.DataDiskParentPath)"
}