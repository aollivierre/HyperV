# Emergency script v2 - handles running VMs properly

Write-Host "=== Current VM Status ===" -ForegroundColor Cyan
$allVMs = Get-VM
$runningVMs = $allVMs | Where-Object {$_.State -eq 'Running'}
$offVMs = $allVMs | Where-Object {$_.State -eq 'Off'}

Write-Host "Total VMs: $($allVMs.Count)" -ForegroundColor White
Write-Host "Running VMs: $($runningVMs.Count)" -ForegroundColor Green
Write-Host "Off VMs: $($offVMs.Count)" -ForegroundColor Gray

# Show which VMs are currently running
Write-Host "`n=== Currently Running VMs ===" -ForegroundColor Yellow
$runningVMs | Select-Object Name | Format-Table -AutoSize

# First, disable auto-start for all OFF VMs
Write-Host "`n=== Disabling auto-start for all OFF VMs ===" -ForegroundColor Red
foreach ($vm in $offVMs) {
    Write-Host "Disabling auto-start for: $($vm.Name)" -ForegroundColor Gray
    Set-VM -Name $vm.Name -AutomaticStartAction Nothing -AutomaticStopAction ShutDown
}

# List of VMs that should keep auto-start (the ones that were originally running)
$importantVMs = @(
    "071 - Ubuntu - Docker - Syncthing_20241006_062602",
    "084 - ABC Lab - RD Gateway 03 - Server Desktop",
    "085 - OPNsense - Firewall",
    "088 - Ubuntu - Claude Code - 01",
    "089 - ABC Lab - Win 10 migration to Windows 11"
)

Write-Host "`n=== Configuring auto-start for important VMs only ===" -ForegroundColor Green
Write-Host "Note: Settings for running VMs will take effect on next shutdown" -ForegroundColor Yellow

$startDelay = 0
foreach ($vmName in $importantVMs) {
    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if ($vm) {
        if ($vm.State -eq 'Running') {
            Write-Host "VM '$vmName' is running - settings will apply on next shutdown" -ForegroundColor Cyan
        } else {
            Write-Host "Configuring auto-start for: $vmName (delay: $startDelay seconds)" -ForegroundColor White
            Set-VM -Name $vmName `
                   -AutomaticStartAction Start `
                   -AutomaticStopAction Save `
                   -AutomaticStartDelay $startDelay
        }
        $startDelay += 60
    }
}

Write-Host "`n=== Final Status ===" -ForegroundColor Cyan
Write-Host "`nVMs configured to auto-start:" -ForegroundColor Green
Get-VM | Where-Object {$_.AutomaticStartAction -eq 'Start' -and $_.State -ne 'Running'} | 
    Select-Object Name, State, AutomaticStartAction, AutomaticStartDelay | 
    Format-Table -AutoSize

Write-Host "`nRunning VMs that need manual configuration after shutdown:" -ForegroundColor Yellow
$runningVMs | Where-Object {$_.Name -notin $importantVMs} | 
    Select-Object Name | 
    Format-Table -AutoSize

Write-Host "`n=== Recommendations ===" -ForegroundColor Magenta
Write-Host "1. The unexpected running VMs (like Test VMs) should be shut down" -ForegroundColor White
Write-Host "2. Once shut down, their auto-start is already disabled" -ForegroundColor White
Write-Host "3. Only your 5 important VMs will auto-start on next reboot" -ForegroundColor White
Write-Host "4. Consider shutting down these unexpected VMs:" -ForegroundColor Yellow

# Show unexpected running VMs
$unexpectedRunning = $runningVMs | Where-Object {$_.Name -notin $importantVMs}
$unexpectedRunning | ForEach-Object {
    Write-Host "   Stop-VM -Name '$($_.Name)' -Force" -ForegroundColor Cyan
}