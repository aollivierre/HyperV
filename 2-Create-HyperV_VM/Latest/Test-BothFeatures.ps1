# Test BOTH dual disk and multi-NIC features together
Write-Host "`n=== Testing VM with BOTH Dual Disk AND Multi-NIC ===" -ForegroundColor Cyan

# First clean up any existing test VM
$existingVM = Get-VM -Name "*DualDisk AND MultiNIC*" -ErrorAction SilentlyContinue
if ($existingVM) {
    Write-Host "Cleaning up existing test VM..." -ForegroundColor Yellow
    if ($existingVM.State -ne 'Off') { Stop-VM -Name $existingVM.Name -Force }
    Remove-VM -Name $existingVM.Name -Force
    $vmPath = Split-Path $existingVM.Path -Parent
    Remove-Item -Path $vmPath -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`nConfiguration:" -ForegroundColor Yellow
Write-Host "  - Multi-NIC: ENABLED (UseAllAvailableSwitches = true)" -ForegroundColor Green
Write-Host "  - Dual Disk: ENABLED (EnableDataDisk = true)" -ForegroundColor Green
Write-Host "  - Data Disk: 100GB Standard disk" -ForegroundColor White

Write-Host "`nRunning VM creation with both features enabled..." -ForegroundColor Yellow

# Run with smart defaults to avoid prompts
& "D:\Code\HyperV\2-Create-HyperV_VM\Latest\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1" `
    -UseSmartDefaults `
    -AutoSelectDrive

Write-Host "`nWaiting for VM creation to complete..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Find the created VM
$vm = Get-VM | Where-Object { $_.Name -like "*DualDisk AND MultiNIC*" } | Sort-Object Name -Descending | Select-Object -First 1

if ($vm) {
    Write-Host "`n=== VM Created Successfully ===" -ForegroundColor Green
    Write-Host "VM Name: $($vm.Name)" -ForegroundColor White
    
    # Check NICs
    Write-Host "`n=== Network Adapters ===" -ForegroundColor Cyan
    $nics = Get-VMNetworkAdapter -VMName $vm.Name
    Write-Host "Total NICs: $($nics.Count)" -ForegroundColor $(if ($nics.Count -gt 1) { 'Green' } else { 'Red' })
    
    foreach ($nic in $nics) {
        Write-Host "`n$($nic.Name):" -ForegroundColor Yellow
        Write-Host "  Connected to: $($nic.SwitchName)" -ForegroundColor White
    }
    
    # Check Disks
    Write-Host "`n=== Hard Disk Drives ===" -ForegroundColor Cyan
    $disks = Get-VMHardDiskDrive -VMName $vm.Name
    Write-Host "Total Disks: $($disks.Count)" -ForegroundColor $(if ($disks.Count -eq 2) { 'Green' } else { 'Red' })
    
    foreach ($disk in $disks) {
        Write-Host "`nDisk at Location $($disk.ControllerLocation):" -ForegroundColor Yellow
        Write-Host "  Controller: $($disk.ControllerType) $($disk.ControllerNumber)" -ForegroundColor White
        Write-Host "  Path: $(Split-Path $disk.Path -Leaf)" -ForegroundColor White
        
        if (Test-Path $disk.Path) {
            $vhd = Get-VHD -Path $disk.Path
            Write-Host "  Type: $($vhd.VhdType)" -ForegroundColor White
            Write-Host "  Size: $([math]::Round($vhd.Size/1GB, 2)) GB" -ForegroundColor White
            if ($vhd.ParentPath) {
                Write-Host "  Parent: $(Split-Path $vhd.ParentPath -Leaf)" -ForegroundColor Cyan
            }
        }
    }
    
    # Final Verdict
    Write-Host "`n=== TEST RESULTS ===" -ForegroundColor Cyan
    $multiNicSuccess = $nics.Count -gt 1
    $dualDiskSuccess = $disks.Count -eq 2
    
    if ($multiNicSuccess) {
        Write-Host "✓ Multi-NIC: SUCCESS - VM has $($nics.Count) network adapters" -ForegroundColor Green
    } else {
        Write-Host "✗ Multi-NIC: FAILED - VM only has $($nics.Count) network adapter" -ForegroundColor Red
    }
    
    if ($dualDiskSuccess) {
        Write-Host "✓ Dual Disk: SUCCESS - VM has 2 disks (OS + Data)" -ForegroundColor Green
    } else {
        Write-Host "✗ Dual Disk: FAILED - VM only has $($disks.Count) disk(s)" -ForegroundColor Red
    }
    
    if ($multiNicSuccess -and $dualDiskSuccess) {
        Write-Host "`n🎉 BOTH FEATURES WORKING PERFECTLY! 🎉" -ForegroundColor Green
        Write-Host "VM has multiple NICs AND dual disks!" -ForegroundColor Green
    } else {
        Write-Host "`nSome features did not work as expected." -ForegroundColor Yellow
    }
} else {
    Write-Host "`nERROR: VM was not created!" -ForegroundColor Red
}