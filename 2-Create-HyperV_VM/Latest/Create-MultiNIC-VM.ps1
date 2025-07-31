# Direct creation of a VM with multi-NIC enabled
Write-Host "`n=== Creating VM with Multi-NIC Enabled ===" -ForegroundColor Cyan

# First clean up test VMs
Write-Host "Cleaning up test VMs..." -ForegroundColor Yellow
@('098 - ABC Lab - Win 10 migration to Windows 11_VM', 
  '099 - ABC Lab - Win 10 migration to Windows 11_VM') | ForEach-Object {
    $vm = Get-VM -Name $_ -ErrorAction SilentlyContinue
    if ($vm) {
        if ($vm.State -ne 'Off') { Stop-VM -Name $_ -Force }
        Remove-VM -Name $_ -Force
        $vmPath = Split-Path $vm.Path -Parent
        Remove-Item -Path $vmPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Import module
Import-Module "D:\Code\HyperV\2-Create-HyperV_VM\Latest\modules\EnhancedHyperVAO\EnhancedHyperVAO.psd1" -Force

# Get next VM name
$nextName = Get-NextVMNamePrefix
$vmName = "${nextName}_VM"
$vmPath = "D:\VM\$vmName"

Write-Host "`nCreating VM: $vmName" -ForegroundColor Yellow
Write-Host "Multi-NIC: ENABLED" -ForegroundColor Green

# Create VM with multi-NIC
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
    UseAllAvailableSwitches = $true  # MULTI-NIC ENABLED
    AutoStartVM = $false
    AutoConnectVM = $false
}

Create-EnhancedVM @params

# Check the result
Write-Host "`n=== Verification ===" -ForegroundColor Cyan
$vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
if ($vm) {
    $nics = Get-VMNetworkAdapter -VMName $vmName
    Write-Host "VM Created: $vmName" -ForegroundColor Green
    Write-Host "Total NICs: $($nics.Count)" -ForegroundColor $(if ($nics.Count -gt 1) { 'Green' } else { 'Red' })
    
    foreach ($nic in $nics) {
        Write-Host "`n$($nic.Name):" -ForegroundColor Yellow
        Write-Host "  Connected to: $($nic.SwitchName)" -ForegroundColor White
        Write-Host "  Status: $($nic.Status)" -ForegroundColor Gray
    }
    
    if ($nics.Count -gt 1) {
        Write-Host "`nSUCCESS: Multi-NIC configuration is working!" -ForegroundColor Green
        Write-Host "The VM has $($nics.Count) network adapters as expected." -ForegroundColor Green
    }
}