# Test dual disk with explicit config selection
Write-Host "`n=== Testing Dual Disk Feature ===" -ForegroundColor Cyan

# Create parent data disk if needed
$dataParent = "D:\VM\Setup\VHDX\DataDiskParent_256GB.vhdx"
if (-not (Test-Path $dataParent)) {
    Write-Host "Creating parent data disk..." -ForegroundColor Yellow
    & "D:\Code\HyperV\2-Create-HyperV_VM\Latest\Create-DataDiskParent.ps1" -Path $dataParent
}

# Import module first
Import-Module "D:\Code\HyperV\2-Create-HyperV_VM\Latest\modules\EnhancedHyperVAO\EnhancedHyperVAO.psd1" -Force

# Create test VM directly
$vmName = "TEST-$(Get-Date -Format 'HHmmss')-DualDisk"
$vmPath = "D:\VM\$vmName"

Write-Host "`nCreating VM: $vmName" -ForegroundColor Yellow

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
    IncludeTPM = $true
    DefaultVHDSize = 60GB
    VMType = 'Standard'
    
    # Dual disk parameters
    EnableDataDisk = $true
    DataDiskType = 'Differencing'
    DataDiskParentPath = $dataParent
    DataDiskSize = 256GB
}

try {
    Create-EnhancedVM @params
    
    # Check results
    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if ($vm) {
        $disks = Get-VMHardDiskDrive -VMName $vmName
        Write-Host "`nVM Created Successfully!" -ForegroundColor Green
        Write-Host "Number of disks: $($disks.Count)" -ForegroundColor $(if ($disks.Count -eq 2) { 'Green' } else { 'Red' })
        
        foreach ($disk in $disks) {
            Write-Host "`nDisk $($disk.ControllerLocation):" -ForegroundColor Yellow
            Write-Host "  Controller: $($disk.ControllerType)"
            Write-Host "  Path: $($disk.Path)"
            
            if (Test-Path $disk.Path) {
                $vhd = Get-VHD -Path $disk.Path
                Write-Host "  Type: $($vhd.VhdType)"
                if ($vhd.ParentPath) {
                    Write-Host "  Parent: $(Split-Path $vhd.ParentPath -Leaf)" -ForegroundColor Green
                    Write-Host "  Differencing: YES" -ForegroundColor Green
                }
            }
        }
        
        if ($disks.Count -eq 2) {
            Write-Host "`n100% SUCCESS: Dual disk VM created!" -ForegroundColor Green
        }
        
        # Cleanup
        Write-Host "`nRemoving test VM..." -ForegroundColor Yellow
        Remove-VM -Name $vmName -Force
        Remove-Item -Path $vmPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}