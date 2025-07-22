# Script to save VM state and configure auto-start settings

Write-Host "=== Getting all VMs and their current state ===" -ForegroundColor Cyan
$vms = Get-VM
$vms | Select-Object Name, State, AutomaticStartAction, AutomaticStopAction, AutomaticStartDelay | Format-Table -AutoSize

# Save running VMs
Write-Host "`n=== Saving state of running VMs ===" -ForegroundColor Yellow
$runningVMs = $vms | Where-Object {$_.State -eq 'Running'}

if ($runningVMs.Count -gt 0) {
    Write-Host "Found $($runningVMs.Count) running VMs. Saving their state..." -ForegroundColor Green
    foreach ($vm in $runningVMs) {
        Write-Host "Saving state of VM: $($vm.Name)" -ForegroundColor White
        Save-VM -Name $vm.Name -Verbose
    }
} else {
    Write-Host "No running VMs found." -ForegroundColor Gray
}

# Configure auto-start settings
Write-Host "`n=== Configuring auto-start settings for all VMs ===" -ForegroundColor Yellow
$startDelay = 0
$delayIncrement = 30  # 30 seconds between VM starts

foreach ($vm in $vms) {
    Write-Host "Configuring VM: $($vm.Name)" -ForegroundColor White
    Write-Host "  - Setting AutomaticStartAction to 'Start'" -ForegroundColor Gray
    Write-Host "  - Setting AutomaticStopAction to 'Save'" -ForegroundColor Gray
    Write-Host "  - Setting AutomaticStartDelay to $startDelay seconds" -ForegroundColor Gray
    
    Set-VM -Name $vm.Name `
           -AutomaticStartAction Start `
           -AutomaticStopAction Save `
           -AutomaticStartDelay $startDelay `
           -Verbose
    
    # Increment delay for next VM to stagger startup
    $startDelay += $delayIncrement
}

# Display final configuration
Write-Host "`n=== Final VM Configuration ===" -ForegroundColor Cyan
Get-VM | Select-Object Name, State, AutomaticStartAction, AutomaticStopAction, AutomaticStartDelay | Format-Table -AutoSize

Write-Host "`n=== Summary ===" -ForegroundColor Green
Write-Host "- All running VMs have been saved" -ForegroundColor White
Write-Host "- All VMs configured to auto-start after host reboot" -ForegroundColor White
Write-Host "- VMs will start with staggered delays to prevent resource contention" -ForegroundColor White
Write-Host "- All VMs configured to save state on host shutdown" -ForegroundColor White
Write-Host "`nYou can now safely reboot the Hyper-V host." -ForegroundColor Yellow