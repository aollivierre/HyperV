# Verify optimization and fix remaining issues

Write-Host "=================================="
Write-Host "   VERIFICATION & FINAL FIXES"
Write-Host "=================================="
Write-Host ""

# Check current state
$VMs = Get-VM | Where-Object {$_.State -eq 'Running'} | Select-Object Name, 
    @{N='Startup(GB)';E={[math]::Round($_.MemoryStartup/1GB,2)}},
    @{N='Assigned(GB)';E={[math]::Round($_.MemoryAssigned/1GB,2)}},
    @{N='Demand(GB)';E={[math]::Round($_.MemoryDemand/1GB,2)}},
    MemoryStatus

Write-Host "Current VM Status:"
$VMs | Format-Table -AutoSize

# Find remaining issues
$IssuesFound = $false
$RemainingFixes = @()

foreach ($VM in $VMs) {
    # Check if startup memory doesn't match what we set
    if ($VM.Name -eq "073 - ABC Lab - DC1 - Without WSL_20241111_083935" -and $VM.'Startup(GB)' -ne 5) {
        $RemainingFixes += @{Name=$VM.Name; Target=5; Current=$VM.'Startup(GB)'}
        $IssuesFound = $true
    }
    elseif ($VM.Name -eq "089 - ABC Lab - Win 10 migration to Windows 11" -and $VM.'Startup(GB)' -ne 5) {
        $RemainingFixes += @{Name=$VM.Name; Target=5; Current=$VM.'Startup(GB)'}
        $IssuesFound = $true
    }
    elseif ($VM.Name -eq "090 - ABC Lab - Win 10 migration to Windows 11" -and $VM.'Demand(GB)' -gt $VM.'Assigned(GB)') {
        # This VM still needs more memory
        $Target = [math]::Ceiling($VM.'Demand(GB)' * 1.1)
        $RemainingFixes += @{Name=$VM.Name; Target=$Target; Current=$VM.'Startup(GB)'}
        $IssuesFound = $true
    }
    elseif ($VM.Name -eq "071 - Ubuntu - Docker - Syncthing_20241006_062602" -and $VM.MemoryStatus -eq "Warning") {
        # This VM still has warning
        $Target = [math]::Ceiling($VM.'Demand(GB)' * 1.1)
        $RemainingFixes += @{Name=$VM.Name; Target=$Target; Current=$VM.'Startup(GB)'}
        $IssuesFound = $true
    }
}

if ($IssuesFound) {
    Write-Host ""
    Write-Host "Remaining issues found. Applying fixes..."
    Write-Host ""
    
    foreach ($Fix in $RemainingFixes) {
        Write-Host "Fixing $($Fix.Name): $($Fix.Current) GB -> $($Fix.Target) GB"
        try {
            Stop-VM -Name $Fix.Name -Force -ErrorAction SilentlyContinue
            Set-VMMemory -VMName $Fix.Name -StartupBytes ([int64]$Fix.Target * 1GB)
            Start-VM -Name $Fix.Name
            Write-Host "  [OK] Fixed" -ForegroundColor Green
        }
        catch {
            Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Waiting for VMs to stabilize..."
    Start-Sleep -Seconds 30
    
    # Show final state
    Write-Host ""
    Write-Host "FINAL STATE AFTER FIXES:"
    Get-VM | Where-Object {$_.State -eq 'Running'} | Select-Object Name, 
        @{N='Assigned(GB)';E={[math]::Round($_.MemoryAssigned/1GB,2)}},
        @{N='Demand(GB)';E={[math]::Round($_.MemoryDemand/1GB,2)}},
        MemoryStatus | Format-Table -AutoSize
}
else {
    Write-Host ""
    Write-Host "All VMs are properly configured!" -ForegroundColor Green
}

# Final summary
$OS = Get-CimInstance Win32_OperatingSystem
$FinalFree = [math]::Round($OS.FreePhysicalMemory/1MB, 2)
$TotalAssigned = [math]::Round((Get-VM | Where-Object {$_.State -eq 'Running'} | Measure-Object -Property MemoryAssigned -Sum).Sum / 1GB, 2)

Write-Host ""
Write-Host "FINAL SUMMARY:"
Write-Host "=============="
Write-Host "Total RAM: 64 GB"
Write-Host "VMs using: $TotalAssigned GB"
Write-Host "Free RAM: $FinalFree GB"
Write-Host "Host/Hyper-V: $([math]::Round(64 - $TotalAssigned - $FinalFree, 2)) GB"