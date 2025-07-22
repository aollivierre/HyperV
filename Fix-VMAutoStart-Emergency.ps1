# Emergency script to stop VMs waiting to start and fix auto-start settings

Write-Host "=== EMERGENCY: Stopping VMs waiting to start ===" -ForegroundColor Red

# Get all VMs in Starting state
$startingVMs = Get-VM | Where-Object {$_.State -eq 'Starting'}
Write-Host "Found $($startingVMs.Count) VMs trying to start" -ForegroundColor Yellow

# Stop all VMs that are trying to start
foreach ($vm in $startingVMs) {
    Write-Host "Stopping VM: $($vm.Name)" -ForegroundColor White
    Stop-VM -Name $vm.Name -Force -TurnOff
}

Write-Host "`n=== Resetting ALL VMs to NOT auto-start ===" -ForegroundColor Yellow
# First, set ALL VMs to NOT auto-start
Get-VM | ForEach-Object {
    Set-VM -Name $_.Name -AutomaticStartAction Nothing -AutomaticStopAction ShutDown
}

Write-Host "`n=== Identifying recently used VMs ===" -ForegroundColor Cyan
# List of VMs that were running before (based on your output)
$activeVMNames = @(
    "071 - Ubuntu - Docker - Syncthing_20241006_062602",
    "084 - ABC Lab - RD Gateway 03 - Server Desktop",
    "085 - OPNsense - Firewall",
    "088 - Ubuntu - Claude Code - 01",
    "089 - ABC Lab - Win 10 migration to Windows 11"
)

# Also include VMs that were in Saved state (likely recently used)
$savedVMs = Get-VM | Where-Object {$_.State -eq 'Saved'}
$savedVMNames = $savedVMs | Select-Object -ExpandProperty Name

# Combine active and saved VMs
$vmsToAutoStart = $activeVMNames + $savedVMNames | Select-Object -Unique

Write-Host "`n=== Configuring auto-start ONLY for active VMs ===" -ForegroundColor Green
$startDelay = 0
foreach ($vmName in $vmsToAutoStart) {
    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if ($vm) {
        Write-Host "Configuring auto-start for: $vmName (delay: $startDelay seconds)" -ForegroundColor White
        Set-VM -Name $vmName `
               -AutomaticStartAction Start `
               -AutomaticStopAction Save `
               -AutomaticStartDelay $startDelay
        $startDelay += 60  # 60 seconds between each VM
    }
}

Write-Host "`n=== Current VM Status ===" -ForegroundColor Cyan
Get-VM | Select-Object Name, State, AutomaticStartAction | Where-Object {$_.AutomaticStartAction -eq 'Start'} | Format-Table -AutoSize

Write-Host "`n=== Summary ===" -ForegroundColor Green
Write-Host "- All VMs trying to start have been stopped" -ForegroundColor White
Write-Host "- Auto-start disabled for ALL VMs except recently active ones" -ForegroundColor White
Write-Host "- Only $($vmsToAutoStart.Count) VMs will auto-start on next reboot" -ForegroundColor White
Write-Host "`nYou can now manually start the VMs you need." -ForegroundColor Yellow