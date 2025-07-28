# Check the VM that was just created
$vmName = "093 - ABC Lab - Win 10 migration to Windows 11_VM"
$vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue

if ($vm) {
    Write-Host "VM found: $vmName" -ForegroundColor Green
    $disks = Get-VMHardDiskDrive -VMName $vmName
    Write-Host "`nNumber of disks: $($disks.Count)" -ForegroundColor Yellow
    
    foreach ($disk in $disks) {
        Write-Host "`nDisk Details:" -ForegroundColor Cyan
        Write-Host "  Controller: $($disk.ControllerType) $($disk.ControllerNumber)" 
        Write-Host "  Location: $($disk.ControllerLocation)"
        Write-Host "  Path: $($disk.Path)"
    }
}
else {
    Write-Host "VM not found" -ForegroundColor Red
}