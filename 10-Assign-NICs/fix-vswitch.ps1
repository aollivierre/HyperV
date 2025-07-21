# Fix for the SecondaryNetwork communication
# Run as Administrator

# Enable MAC address spoofing and disable guards
$vmName = "085 - OPNsense - Firewall"
$vmAdapter = Get-VMNetworkAdapter -VMName $vmName | Where-Object { $_.SwitchName -eq "SecondaryNetwork" }
if ($vmAdapter) {
    # Enable MAC address spoofing and disable guards
    Set-VMNetworkAdapter -VMName $vmName -Name $vmAdapter.Name -MacAddressSpoofing On -RouterGuard Off -DhcpGuard Off
    Write-Host "Enabled MAC address spoofing and disabled guards for OPNsense LAN adapter" -ForegroundColor Green
}

# Ensure switch is Internal type
$switch = Get-VMSwitch -Name "SecondaryNetwork"
if ($switch) {
    Set-VMSwitch -Name "SecondaryNetwork" -SwitchType Internal
    Write-Host "Set SecondaryNetwork switch to Internal type" -ForegroundColor Green
}

# Restart the VM to apply changes
if ((Get-VM -Name $vmName).State -eq "Running") {
    # Stop-VM -Name $vmName -Force #Do not Force, it may cause data loss instead do it from inside the VM or the web console
    Write-Host "Stopped VM to apply network changes" -ForegroundColor Yellow
    Start-VM -Name $vmName
    Write-Host "Started VM again" -ForegroundColor Green
    Write-Host "Wait 30 seconds for OPNsense to boot..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
}

# Restart the host network adapter
$hostAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*SecondaryNetwork*" }
if ($hostAdapter) {
    Restart-NetAdapter -Name $hostAdapter.Name -Confirm:$false
    Write-Host "Restarted host network adapter" -ForegroundColor Green
}

Write-Host "`nTest connectivity with: ping 198.18.1.1" -ForegroundColor Cyan
Write-Host "Then try accessing: https://198.18.1.1" -ForegroundColor Cyan