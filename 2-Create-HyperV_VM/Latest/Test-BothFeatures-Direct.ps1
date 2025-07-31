# Direct test of both features
Write-Host "`n=== Direct Test: Dual Disk + Multi-NIC ===" -ForegroundColor Cyan

# Clean up test VMs
Write-Host "Cleaning up test VMs..." -ForegroundColor Yellow
Get-VM | Where-Object { $_.Name -match "TEST|001 - ABC" } | ForEach-Object {
    if ($_.State -ne 'Off') { Stop-VM -Name $_.Name -Force }
    Remove-VM -Name $_.Name -Force
    $vmPath = Split-Path $_.Path -Parent
    Remove-Item -Path $vmPath -Recurse -Force -ErrorAction SilentlyContinue
}

# Import module
Import-Module "D:\Code\HyperV\2-Create-HyperV_VM\Latest\modules\EnhancedHyperVAO\EnhancedHyperVAO.psd1" -Force

# Create VM with both features
$vmName = "TEST-BothFeatures-$(Get-Date -Format 'HHmmss')"
$vmPath = "D:\VM\$vmName"

Write-Host "`nCreating VM: $vmName" -ForegroundColor Yellow
Write-Host "Features:" -ForegroundColor Yellow
Write-Host "  - Multi-NIC: ENABLED" -ForegroundColor Green
Write-Host "  - Dual Disk: ENABLED" -ForegroundColor Green

$params = @{
    VMName = $vmName
    VMFullPath = $vmPath
    MemoryStartupBytes = "2GB"
    MemoryMinimumBytes = "1GB"
    MemoryMaximumBytes = "4GB"
    ProcessorCount = 2
    ExternalSwitchName = "Realtek Gaming 2.5GbE Family Controller - Virtual Switch"
    Generation = 2
    EnableDynamicMemory = $true
    IncludeTPM = $false
    DefaultVHDSize = 40GB
    VMType = 'Standard'
    
    # BOTH FEATURES ENABLED
    UseAllAvailableSwitches = $true  # Multi-NIC
    EnableDataDisk = $true           # Dual Disk
    DataDiskType = 'Standard'
    DataDiskSize = 100GB
    
    AutoStartVM = $false
    AutoConnectVM = $false
}

try {
    Create-EnhancedVM @params
    
    # Verify results
    Write-Host "`n=== Verification ===" -ForegroundColor Cyan
    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    
    if ($vm) {
        # Check NICs
        $nics = Get-VMNetworkAdapter -VMName $vmName
        Write-Host "`nNetwork Adapters: $($nics.Count)" -ForegroundColor $(if ($nics.Count -gt 1) { 'Green' } else { 'Red' })
        foreach ($nic in $nics) {
            Write-Host "  - $($nic.Name) -> $($nic.SwitchName)" -ForegroundColor Gray
        }
        
        # Check Disks
        $disks = Get-VMHardDiskDrive -VMName $vmName
        Write-Host "`nHard Disks: $($disks.Count)" -ForegroundColor $(if ($disks.Count -eq 2) { 'Green' } else { 'Red' })
        foreach ($disk in $disks) {
            $vhdInfo = Get-VHD -Path $disk.Path -ErrorAction SilentlyContinue
            Write-Host "  - Location $($disk.ControllerLocation): $(Split-Path $disk.Path -Leaf) ($([math]::Round($vhdInfo.Size/1GB, 0))GB)" -ForegroundColor Gray
        }
        
        # Results
        Write-Host "`n=== RESULTS ===" -ForegroundColor Cyan
        if ($nics.Count -gt 1 -and $disks.Count -eq 2) {
            Write-Host "SUCCESS: Both features working!" -ForegroundColor Green
            Write-Host "  - Multi-NIC: $($nics.Count) network adapters" -ForegroundColor Green
            Write-Host "  - Dual Disk: 2 hard disks (OS + Data)" -ForegroundColor Green
        } else {
            Write-Host "FAILED: Not all features working" -ForegroundColor Red
        }
        
        # Cleanup
        Remove-VM -Name $vmName -Force
        Remove-Item -Path $vmPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}