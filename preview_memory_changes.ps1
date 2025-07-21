# Preview memory changes without applying them

Write-Host "======================================="
Write-Host "   MEMORY OPTIMIZATION PREVIEW"
Write-Host "======================================="
Write-Host ""

$VMs = Get-VM | Where-Object {$_.State -eq 'Running'}
$TotalCurrentMemory = 0
$TotalNewMemory = 0
$Changes = @()

foreach ($VM in $VMs) {
    $CurrentAssigned = [math]::Round($VM.MemoryAssigned/1GB, 2)
    $CurrentDemand = [math]::Round($VM.MemoryDemand/1GB, 2)
    $CurrentMin = [math]::Round($VM.MemoryMinimum/1GB, 2)
    
    $TotalCurrentMemory += $CurrentAssigned
    
    # Skip if no demand data
    if ($CurrentDemand -eq 0) {
        $TotalNewMemory += $CurrentAssigned
        continue
    }
    
    # Calculate target (demand + 20% buffer)
    $TargetMemory = [math]::Round($CurrentDemand * 1.2 * 2) / 2  # Round to 0.5 GB
    $NewMin = [math]::Min($TargetMemory, $CurrentMin)
    $NewMin = [math]::Round($NewMin * 2) / 2
    
    $TotalNewMemory += $TargetMemory
    
    if ([math]::Abs($CurrentAssigned - $TargetMemory) -gt 0.5) {
        $Changes += [PSCustomObject]@{
            VMName = $VM.Name
            CurrentMemory = "$CurrentAssigned GB"
            NewMemory = "$TargetMemory GB"
            Change = "$([math]::Round($TargetMemory - $CurrentAssigned, 2)) GB"
            CurrentMin = "$CurrentMin GB"
            NewMin = "$NewMin GB"
            Status = $VM.MemoryStatus
        }
    }
}

Write-Host "PROPOSED CHANGES:"
Write-Host "================="
$Changes | Format-Table -AutoSize

Write-Host ""
Write-Host "SUMMARY:"
Write-Host "========"
Write-Host "Current Total Memory: $([math]::Round($TotalCurrentMemory, 2)) GB"
Write-Host "Proposed Total Memory: $([math]::Round($TotalNewMemory, 2)) GB"
Write-Host "Total Memory Savings: $([math]::Round($TotalCurrentMemory - $TotalNewMemory, 2)) GB"
Write-Host "Number of VMs to modify: $($Changes.Count)"

Write-Host ""
Write-Host "NOTE: This is a preview. To apply changes, run adjust_vm_memory.ps1"
Write-Host "WARNING: VMs will be restarted during the adjustment process!"