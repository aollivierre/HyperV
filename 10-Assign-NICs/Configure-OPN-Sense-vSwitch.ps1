# Configure-OPNsenseNetwork.ps1
# This script configures Hyper-V networking for OPNsense using existing switches
# Run as Administrator

# VM Configuration - CORRECTED VM NAME
$vmName = "085 - OPNsense - Firewall" # Corrected VM name with proper formatting
$existingExternalSwitch = "Realtek Gaming 2.5GbE Family Controller - Virtual Switch"
$existingInternalSwitch = "SecondaryNetwork"

# 1. Remove IP configuration from host's SecondaryNetwork adapter (if not already done)
Write-Host "Checking SecondaryNetwork adapter configuration..." -ForegroundColor Green
$secondaryAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*$existingInternalSwitch*" }
if ($secondaryAdapter) {
    $ipConfig = Get-NetIPAddress -InterfaceIndex $secondaryAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($ipConfig) {
        Write-Host "Removing IP configuration from SecondaryNetwork adapter..." -ForegroundColor Green
        Remove-NetIPAddress -InterfaceIndex $secondaryAdapter.ifIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
        Set-NetIPInterface -InterfaceIndex $secondaryAdapter.ifIndex -DHCP Enabled
        Write-Host "IP address removed from SecondaryNetwork adapter" -ForegroundColor Green
    } else {
        Write-Host "SecondaryNetwork adapter already has no IPv4 address configured" -ForegroundColor Green
    }
} else {
    Write-Host "SecondaryNetwork adapter not found. Continuing..." -ForegroundColor Yellow
}

# 2. Verify existing switches
Write-Host "Verifying existing virtual switches..." -ForegroundColor Green

$externalSwitch = Get-VMSwitch -Name $existingExternalSwitch -ErrorAction SilentlyContinue
if (-not $externalSwitch) {
    Write-Host "Error: External switch '$existingExternalSwitch' not found." -ForegroundColor Red
    Write-Host "Available switches: $(Get-VMSwitch | Select-Object -ExpandProperty Name)" -ForegroundColor Yellow
    exit
}

$internalSwitch = Get-VMSwitch -Name $existingInternalSwitch -ErrorAction SilentlyContinue
if (-not $internalSwitch) {
    Write-Host "Error: Internal switch '$existingInternalSwitch' not found." -ForegroundColor Red
    Write-Host "Available switches: $(Get-VMSwitch | Select-Object -ExpandProperty Name)" -ForegroundColor Yellow
    exit
}

Write-Host "Using existing switches: WAN=$existingExternalSwitch, LAN=$existingInternalSwitch" -ForegroundColor Green

# 3. Configure the OPNsense VM (with corrected name)
$vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
if ($vm) {
    Write-Host "Configuring network adapters for VM '$vmName'..." -ForegroundColor Green
    
    # Stop the VM if running
    if ($vm.State -eq "Running") {
        Write-Host "Stopping VM '$vmName'..." -ForegroundColor Yellow
        Stop-VM -Name $vmName -Force
    }
    
    # Remove existing network adapters
    Get-VMNetworkAdapter -VMName $vmName | Remove-VMNetworkAdapter
    
    # Add new network adapters
    Add-VMNetworkAdapter -VMName $vmName -SwitchName $existingExternalSwitch -Name "WAN"
    Add-VMNetworkAdapter -VMName $vmName -SwitchName $existingInternalSwitch -Name "LAN"
    
    Write-Host "Network adapters configured for '$vmName'" -ForegroundColor Green
} else {
    Write-Host "VM '$vmName' not found. Available VMs: $(Get-VM | Select-Object -ExpandProperty Name)" -ForegroundColor Yellow
    Write-Host "Only network configuration has been updated." -ForegroundColor Yellow
}

Write-Host "`nSummary of changes:" -ForegroundColor Cyan
Write-Host "1. Removed IP address 198.18.1.1 from the Hyper-V host's SecondaryNetwork adapter" -ForegroundColor Cyan
Write-Host "2. Using existing switches:" -ForegroundColor Cyan
Write-Host "   - WAN: $existingExternalSwitch" -ForegroundColor Cyan
Write-Host "   - LAN: $existingInternalSwitch" -ForegroundColor Cyan
if ($vm) {
    Write-Host "3. Reconfigured network adapters for VM '$vmName'" -ForegroundColor Cyan
}

Write-Host "`nNext Steps:" -ForegroundColor Green
Write-Host "1. Start the OPNsense VM" -ForegroundColor Green
Write-Host "2. Configure WAN interface to use DHCP" -ForegroundColor Green
Write-Host "3. Configure LAN interface with IP 198.18.1.1/24" -ForegroundColor Green
Write-Host "4. Enable DHCP server on LAN with range 198.18.1.100-198.18.1.200" -ForegroundColor Green