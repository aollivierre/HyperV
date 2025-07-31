# Quick test of multi-NIC feature
Write-Host "`n=== Quick Multi-NIC Test ===" -ForegroundColor Cyan

# Import the module
Import-Module "D:\Code\HyperV\2-Create-HyperV_VM\Latest\modules\EnhancedHyperVAO\EnhancedHyperVAO.psd1" -Force

# Check available switches
$switches = Get-VMSwitch
Write-Host "`nAvailable switches: $($switches.Count)" -ForegroundColor Yellow
foreach ($switch in $switches) {
    Write-Host "  - $($switch.Name) ($($switch.SwitchType))" -ForegroundColor Gray
}

# Create a test VM with multi-NIC
$vmName = "TEST-$(Get-Date -Format 'HHmmss')-MultiNIC"
$vmPath = "D:\VM\$vmName"

Write-Host "`nCreating test VM: $vmName" -ForegroundColor Yellow

$params = @{
    VMName = $vmName
    VMFullPath = $vmPath
    MemoryStartupBytes = "2GB"
    MemoryMinimumBytes = "1GB"
    MemoryMaximumBytes = "4GB"
    ProcessorCount = 2
    ExternalSwitchName = $switches[0].Name  # Use first switch as primary
    Generation = 2
    EnableDynamicMemory = $true
    IncludeTPM = $false
    DefaultVHDSize = 40GB
    VMType = 'Standard'
    UseAllAvailableSwitches = $true  # Enable multi-NIC
}

try {
    Create-EnhancedVM @params
    
    # Check the result
    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if ($vm) {
        $nics = Get-VMNetworkAdapter -VMName $vmName
        Write-Host "`nVM created with $($nics.Count) NIC(s):" -ForegroundColor Green
        foreach ($nic in $nics) {
            Write-Host "  - $($nic.Name) -> $($nic.SwitchName)" -ForegroundColor White
        }
        
        if ($nics.Count -eq $switches.Count) {
            Write-Host "`nSUCCESS: All switches added as NICs!" -ForegroundColor Green
        }
        
        # Cleanup
        Remove-VM -Name $vmName -Force
        Remove-Item -Path $vmPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "`nTest VM cleaned up" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}