# Comprehensive Memory Analysis Report

Write-Host "==============================================="
Write-Host "     HYPER-V MEMORY ANALYSIS REPORT"
Write-Host "==============================================="
Write-Host ""

# Get all VMs with detailed memory info
$VMs = Get-VM | Where-Object {$_.State -eq 'Running'} | Select-Object Name, 
    @{N='Startup(GB)';E={[math]::Round($_.MemoryStartup/1GB,2)}},
    @{N='Min(GB)';E={[math]::Round($_.MemoryMinimum/1GB,2)}},
    @{N='Max(GB)';E={[math]::Round($_.MemoryMaximum/1GB,2)}},
    @{N='Assigned(GB)';E={[math]::Round($_.MemoryAssigned/1GB,2)}},
    @{N='Demand(GB)';E={[math]::Round($_.MemoryDemand/1GB,2)}},
    @{N='MemoryStatus';E={$_.MemoryStatus}},
    DynamicMemoryEnabled

Write-Host "VIRTUAL MACHINE MEMORY DETAILS:"
Write-Host "==============================="
$VMs | Format-Table -AutoSize

# Calculate totals
$TotalAssigned = ($VMs | Measure-Object -Property 'Assigned(GB)' -Sum).Sum
$TotalDemand = ($VMs | Measure-Object -Property 'Demand(GB)' -Sum).Sum
$TotalMinimum = ($VMs | Measure-Object -Property 'Min(GB)' -Sum).Sum
$TotalMaximum = ($VMs | Measure-Object -Property 'Max(GB)' -Sum).Sum

Write-Host ""
Write-Host "MEMORY SUMMARY:"
Write-Host "==============="
Write-Host "Total Assigned Memory: $TotalAssigned GB"
Write-Host "Total Memory Demand: $TotalDemand GB"
Write-Host "Total Minimum Memory: $TotalMinimum GB"
Write-Host "Total Maximum Memory: $TotalMaximum GB"
Write-Host ""

# Identify VMs with potential optimization opportunities
Write-Host "OPTIMIZATION OPPORTUNITIES:"
Write-Host "=========================="

$OptimizationCount = 0

foreach ($VM in $VMs) {
    $Opportunities = @()
    
    # Check for over-provisioning (assigned > demand by more than 20%)
    if ($VM.'Assigned(GB)' -gt ($VM.'Demand(GB)' * 1.2) -and $VM.'Demand(GB)' -gt 0) {
        $Overprovisioned = [math]::Round($VM.'Assigned(GB)' - $VM.'Demand(GB)', 2)
        $Opportunities += "Over-provisioned by $Overprovisioned GB (Assigned: $($VM.'Assigned(GB)') GB, Demand: $($VM.'Demand(GB)') GB)"
    }
    
    # Check if minimum memory is too high
    if ($VM.'Min(GB)' -gt $VM.'Demand(GB)' -and $VM.'Demand(GB)' -gt 0) {
        $Opportunities += "Minimum memory ($($VM.'Min(GB)') GB) exceeds demand ($($VM.'Demand(GB)') GB)"
    }
    
    # Check if maximum memory is excessive
    if ($VM.'Max(GB)' -gt 16 -and $VM.'Demand(GB)' -lt 8) {
        $Opportunities += "Maximum memory ($($VM.'Max(GB)') GB) may be excessive for current demand"
    }
    
    if ($Opportunities.Count -gt 0) {
        Write-Host ""
        Write-Host "VM: $($VM.Name)"
        foreach ($Opp in $Opportunities) {
            Write-Host "  - $Opp"
        }
        $OptimizationCount++
    }
}

if ($OptimizationCount -eq 0) {
    Write-Host "No immediate optimization opportunities identified based on current demand."
}

Write-Host ""
Write-Host "POTENTIAL MEMORY SAVINGS:"
Write-Host "========================"
$PotentialSavings = [math]::Round($TotalAssigned - $TotalDemand, 2)
Write-Host "If all VMs were sized to current demand + 20% buffer: ~$PotentialSavings GB could be reclaimed"