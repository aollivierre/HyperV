# Direct test of dual disk feature
Write-Host "Testing dual disk VM creation..." -ForegroundColor Cyan

# Import the module
Import-Module "D:\Code\HyperV\2-Create-HyperV_VM\Latest\modules\EnhancedHyperVAO\EnhancedHyperVAO.psd1" -Force

# Check if parent disk exists
$parentPath = "D:\VM\Setup\VHDX\DataDiskParent_256GB.vhdx"
if (-not (Test-Path $parentPath)) {
    Write-Host "Parent disk not found at: $parentPath" -ForegroundColor Red
    exit
}

Write-Host "Parent disk found" -ForegroundColor Green

# Create a simple test VM with dual disks
$vmName = "TEST-DualDisk-Direct"
$vmPath = "D:\VM\$vmName"

try {
    # Create VM with dual disk parameters
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
        DataDiskParentPath = $parentPath
        DataDiskSize = 256GB
    }
    
    Write-Host "`nCreating VM with parameters:" -ForegroundColor Yellow
    Write-Host "  EnableDataDisk: $($params.EnableDataDisk)"
    Write-Host "  DataDiskType: $($params.DataDiskType)"
    Write-Host "  DataDiskParentPath: $(Split-Path $params.DataDiskParentPath -Leaf)"
    
    # Create the VM
    Create-EnhancedVM @params
    
    # Check the disks
    Write-Host "`nChecking VM disks..." -ForegroundColor Yellow
    $disks = Get-VMHardDiskDrive -VMName $vmName
    Write-Host "Number of disks: $($disks.Count)" -ForegroundColor $(if ($disks.Count -eq 2) { 'Green' } else { 'Red' })
    
    foreach ($disk in $disks) {
        Write-Host "`nDisk $($disk.ControllerLocation):"
        Write-Host "  Path: $($disk.Path)"
        if (Test-Path $disk.Path) {
            $vhd = Get-VHD -Path $disk.Path
            Write-Host "  Type: $($vhd.VhdType)"
            if ($vhd.ParentPath) {
                Write-Host "  Parent: $(Split-Path $vhd.ParentPath -Leaf)" -ForegroundColor Green
            }
        }
    }
    
    # Cleanup
    Write-Host "`nRemoving test VM..." -ForegroundColor Yellow
    Remove-VM -Name $vmName -Force
    Remove-Item -Path $vmPath -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host "`nTest completed!" -ForegroundColor Green
}
catch {
    Write-Host "`nError: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    
    # Cleanup on error
    if (Get-VM -Name $vmName -ErrorAction SilentlyContinue) {
        Remove-VM -Name $vmName -Force
    }
    if (Test-Path $vmPath) {
        Remove-Item -Path $vmPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}