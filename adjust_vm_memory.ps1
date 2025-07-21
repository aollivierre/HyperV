# Script to adjust VM memory based on demand
# Adds 20% buffer to demand for safety

Write-Host "======================================="
Write-Host "   VM MEMORY OPTIMIZATION SCRIPT"
Write-Host "======================================="
Write-Host ""

# Get all running VMs
$VMs = Get-VM | Where-Object {$_.State -eq 'Running'}

$TotalMemoryBefore = ($VMs | Measure-Object -Property MemoryAssigned -Sum).Sum / 1GB

foreach ($VM in $VMs) {
    $VMName = $VM.Name
    $CurrentAssigned = [math]::Round($VM.MemoryAssigned/1GB, 2)
    $CurrentDemand = [math]::Round($VM.MemoryDemand/1GB, 2)
    $CurrentMin = [math]::Round($VM.MemoryMinimum/1GB, 2)
    $CurrentMax = [math]::Round($VM.MemoryMaximum/1GB, 2)
    
    # Skip if no demand data (like OPNsense)
    if ($CurrentDemand -eq 0) {
        Write-Host "Skipping $VMName - No demand data available"
        continue
    }
    
    # Calculate target memory (demand + 20% buffer)
    $TargetMemory = [math]::Round($CurrentDemand * 1.2, 2)
    
    # Ensure target is within reasonable bounds
    $NewMin = [math]::Min($TargetMemory, $CurrentMin)
    $NewMax = [math]::Max($TargetMemory * 1.5, $CurrentMax)
    
    # Round to nearest 0.5 GB for cleaner values
    $TargetMemory = [math]::Round($TargetMemory * 2) / 2
    $NewMin = [math]::Round($NewMin * 2) / 2
    
    Write-Host "Processing: $VMName"
    Write-Host "  Current: Assigned=$CurrentAssigned GB, Demand=$CurrentDemand GB, Min=$CurrentMin GB"
    Write-Host "  Target:  Memory=$TargetMemory GB, Min=$NewMin GB"
    
    # Check if adjustment is needed (more than 0.5 GB difference)
    if ([math]::Abs($CurrentAssigned - $TargetMemory) -gt 0.5) {
        try {
            # Stop the VM to adjust memory
            Write-Host "  Stopping VM to adjust memory..."
            Stop-VM -Name $VMName -Force
            
            # Adjust memory settings
            Set-VMMemory -VMName $VMName -StartupBytes ($TargetMemory * 1GB) -MinimumBytes ($NewMin * 1GB)
            
            # Start the VM
            Write-Host "  Starting VM..."
            Start-VM -Name $VMName
            
            Write-Host "  ✓ Memory adjusted successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "  ✗ Error adjusting memory: $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  → No adjustment needed (difference < 0.5 GB)" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Wait for VMs to fully start
Write-Host "Waiting 30 seconds for VMs to stabilize..."
Start-Sleep -Seconds 30

# Show results
Write-Host ""
Write-Host "OPTIMIZATION RESULTS:"
Write-Host "===================="
$VMsAfter = Get-VM | Where-Object {$_.State -eq 'Running'}
$TotalMemoryAfter = ($VMsAfter | Measure-Object -Property MemoryAssigned -Sum).Sum / 1GB

Write-Host "Total Memory Before: $([math]::Round($TotalMemoryBefore, 2)) GB"
Write-Host "Total Memory After:  $([math]::Round($TotalMemoryAfter, 2)) GB"
Write-Host "Memory Saved: $([math]::Round($TotalMemoryBefore - $TotalMemoryAfter, 2)) GB"

# Show new allocation
Write-Host ""
Write-Host "NEW MEMORY ALLOCATION:"
$VMsAfter | Select-Object Name, 
    @{N='Assigned(GB)';E={[math]::Round($_.MemoryAssigned/1GB,2)}},
    @{N='Demand(GB)';E={[math]::Round($_.MemoryDemand/1GB,2)}},
    MemoryStatus | Format-Table -AutoSize