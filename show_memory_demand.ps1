# Show how Hyper-V tracks memory demand
Get-VM | Where-Object {$_.State -eq 'Running'} | Select-Object Name, 
    @{N='MemoryAssigned(MB)';E={$_.MemoryAssigned/1MB}},
    @{N='MemoryDemand(MB)';E={$_.MemoryDemand/1MB}},
    MemoryStatus,
    DynamicMemoryEnabled | Format-Table -AutoSize

Write-Host "`nMemoryDemand is tracked by Hyper-V and represents:"
Write-Host "- The actual memory being used inside the VM"
Write-Host "- Updated in real-time by Hyper-V's dynamic memory feature"
Write-Host "- Only available when Dynamic Memory is enabled"