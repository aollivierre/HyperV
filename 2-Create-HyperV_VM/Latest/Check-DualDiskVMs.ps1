# Check which VMs have dual disk setup
Write-Host "`n=== Checking VMs for Dual Disk Setup ===`n" -ForegroundColor Cyan

$vms = Get-VM
$dualDiskVMs = @()

foreach ($vm in $vms) {
    $disks = Get-VMHardDiskDrive -VMName $vm.Name
    
    if ($disks.Count -ge 2) {
        Write-Host "$($vm.Name):" -ForegroundColor Yellow
        Write-Host "  Disk Count: $($disks.Count)" -ForegroundColor Green
        
        $diskNum = 1
        foreach ($disk in $disks) {
            Write-Host "  Disk ${diskNum}:" -ForegroundColor White
            Write-Host "    Controller: $($disk.ControllerType) $($disk.ControllerNumber)" -ForegroundColor Gray
            Write-Host "    Location: $($disk.ControllerLocation)" -ForegroundColor Gray
            Write-Host "    Path: $(Split-Path $disk.Path -Leaf)" -ForegroundColor Gray
            
            if (Test-Path $disk.Path) {
                $vhd = Get-VHD -Path $disk.Path -ErrorAction SilentlyContinue
                if ($vhd) {
                    Write-Host "    Type: $($vhd.VhdType)" -ForegroundColor Gray
                    if ($vhd.ParentPath) {
                        Write-Host "    Parent: $(Split-Path $vhd.ParentPath -Leaf)" -ForegroundColor Cyan
                    }
                }
            }
            $diskNum++
        }
        
        $dualDiskVMs += $vm.Name
        Write-Host ""
    }
}

if ($dualDiskVMs.Count -eq 0) {
    Write-Host "No VMs currently have dual disk setup (2 or more disks)" -ForegroundColor Yellow
} else {
    Write-Host "`nSummary: $($dualDiskVMs.Count) VM(s) with dual disk setup" -ForegroundColor Green
}