# Smart memory optimization within available RAM limits

Write-Host "======================================="
Write-Host "   SMART MEMORY OPTIMIZATION"
Write-Host "======================================="
Write-Host ""

# Get system info
$OS = Get-CimInstance Win32_OperatingSystem
$TotalRAM = [math]::Round($OS.TotalVisibleMemorySize/1MB, 2)
$CurrentFree = [math]::Round($OS.FreePhysicalMemory/1MB, 2)

# Get VMs
$VMs = Get-VM | Where-Object {$_.State -eq 'Running'} | Sort-Object MemoryDemand -Descending
$CurrentTotalAssigned = [math]::Round(($VMs | Measure-Object -Property MemoryAssigned -Sum).Sum / 1GB, 2)

Write-Host "System Memory: $TotalRAM GB total, $CurrentFree GB free"
Write-Host "Current VM allocation: $CurrentTotalAssigned GB"
Write-Host ""

# Target: Keep at least 4GB free for host, use max 85% of RAM for VMs
$MaxVMMemory = [math]::Round($TotalRAM * 0.85, 2)
$TargetTotal = [math]::Min($MaxVMMemory, $CurrentTotalAssigned)

Write-Host "Target allocation: $TargetTotal GB (max 85% of RAM)"
Write-Host ""

# Build optimization plan
$OptimizationPlan = @()

foreach ($VM in $VMs) {
    $Name = $VM.Name
    $Assigned = [math]::Round($VM.MemoryAssigned/1GB, 2)
    $Demand = [math]::Round($VM.MemoryDemand/1GB, 2)
    $Min = [math]::Round($VM.MemoryMinimum/1GB, 2)
    $Status = $VM.MemoryStatus
    
    # Skip if no demand data
    if ($Demand -eq 0) {
        $OptimizationPlan += [PSCustomObject]@{
            Priority = 99
            VMName = $Name
            Action = "Keep"
            Current = $Assigned
            Target = $Assigned
            Change = 0
            Reason = "No demand data"
        }
        continue
    }
    
    # Determine action based on status and efficiency
    if ($Status -eq "Warning") {
        # Under-provisioned - needs more memory
        $Target = [math]::Round($Demand * 1.1 * 2) / 2  # 10% buffer, round to 0.5
        $Priority = 1  # High priority
        $Action = "Increase"
        $Reason = "Memory warning - under-provisioned"
    }
    elseif ($Assigned / $Demand -gt 1.5 -and $Demand -lt 4) {
        # Over-provisioned by >50% on low-demand VM
        $Target = [math]::Round($Demand * 1.2 * 2) / 2  # 20% buffer
        $Priority = 2
        $Action = "Decrease"
        $Reason = "Over-provisioned (using <67% of assigned)"
    }
    elseif ($Assigned / $Demand -gt 1.3) {
        # Moderately over-provisioned
        $Target = [math]::Round($Demand * 1.2 * 2) / 2
        $Priority = 3
        $Action = "Decrease"
        $Reason = "Over-provisioned (using <77% of assigned)"
    }
    else {
        # Well-sized
        $Target = $Assigned
        $Priority = 4
        $Action = "Keep"
        $Reason = "Properly sized"
    }
    
    # Ensure minimum memory constraints
    $Target = [math]::Max($Target, 1)  # At least 1 GB
    
    $OptimizationPlan += [PSCustomObject]@{
        Priority = $Priority
        VMName = $Name
        Action = $Action
        Current = $Assigned
        Target = $Target
        Change = [math]::Round($Target - $Assigned, 2)
        Reason = $Reason
    }
}

# Calculate if plan fits within limits
$PlannedTotal = ($OptimizationPlan | Measure-Object -Property Target -Sum).Sum

Write-Host "OPTIMIZATION PLAN:"
Write-Host "=================="
$OptimizationPlan | Sort-Object Priority | Format-Table -AutoSize

Write-Host ""
Write-Host "PLAN SUMMARY:"
Write-Host "============="
Write-Host "Current total: $CurrentTotalAssigned GB"
Write-Host "Planned total: $PlannedTotal GB"
Write-Host "Change: $([math]::Round($PlannedTotal - $CurrentTotalAssigned, 2)) GB"

if ($PlannedTotal -gt $MaxVMMemory) {
    Write-Host ""
    Write-Host "WARNING: Planned allocation exceeds safe limit!" -ForegroundColor Red
    Write-Host "Consider keeping some low-priority VMs at current allocation."
}

# Create apply script
$ApplyScript = @"
# Apply the optimization plan
`$Changes = @(
"@

foreach ($VM in ($OptimizationPlan | Where-Object { $_.Change -ne 0 } | Sort-Object Priority)) {
    $ApplyScript += @"

    @{Name='$($VM.VMName)'; NewMemory=$($VM.Target); NewMin=[math]::Min($($VM.Target), $(Get-VM -Name $VM.VMName | Select-Object -ExpandProperty MemoryMinimum)/1GB)},
"@
}

$ApplyScript += @"

)

foreach (`$Change in `$Changes) {
    Write-Host "Adjusting `$(`$Change.Name) to `$(`$Change.NewMemory) GB..."
    Stop-VM -Name `$Change.Name -Force
    Set-VMMemory -VMName `$Change.Name -StartupBytes (`$Change.NewMemory * 1GB) -MinimumBytes ([math]::Min(`$Change.NewMin, `$Change.NewMemory) * 1GB)
    Start-VM -Name `$Change.Name
}
"@

Set-Content -Path "D:\code\HyperV\apply_optimization.ps1" -Value $ApplyScript
Write-Host ""
Write-Host "To apply changes, run: .\apply_optimization.ps1" -ForegroundColor Yellow