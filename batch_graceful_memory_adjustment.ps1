# Batch Graceful Memory Adjustment
# Safely adjusts memory for multiple VMs with proper shutdown

Write-Host "========================================="
Write-Host "   BATCH GRACEFUL MEMORY ADJUSTMENT"
Write-Host "========================================="
Write-Host ""

# Define VMs to adjust
$Adjustments = @(
    @{Name='088 - Ubuntu - Claude Code - 01'; NewMemory=2; NewMin=2},
    @{Name='077 - ABC Lab - EHJ - NotSynced - Win 11 Client'; NewMemory=14; NewMin=14},
    @{Name='084 - ABC Lab - RD Gateway 03 - Server Desktop'; NewMemory=3.5; NewMin=3.5}
)

Write-Host "Planned adjustments:"
foreach ($adj in $Adjustments) {
    $vm = Get-VM -Name $adj.Name
    $current = [math]::Round($vm.MemoryStartup/1GB, 2)
    Write-Host "- $($adj.Name): $current GB -> $($adj.NewMemory) GB"
}

Write-Host ""
$response = Read-Host "Proceed with graceful memory adjustments? (y/n)"
if ($response -ne 'y') {
    Write-Host "Operation cancelled."
    return
}

foreach ($adj in $Adjustments) {
    Write-Host ""
    Write-Host "Processing: $($adj.Name)"
    Write-Host "=" * 50
    
    # Call the graceful adjustment script
    & "D:\code\HyperV\graceful_memory_adjustment.ps1" -VMName $adj.Name -NewMemoryGB $adj.NewMemory -NewMinMemoryGB $adj.NewMin
}

Write-Host ""
Write-Host "All adjustments complete!"
Write-Host ""
Write-Host "Final VM Status:"
Get-VM | Where-Object {$_.State -eq 'Running'} | Select-Object Name, 
    @{N='Assigned(GB)';E={[math]::Round($_.MemoryAssigned/1GB,2)}},
    @{N='Demand(GB)';E={[math]::Round($_.MemoryDemand/1GB,2)}},
    MemoryStatus | Format-Table -AutoSize