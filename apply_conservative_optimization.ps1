# Conservative Memory Optimization Script
# This script reduces over-provisioned VMs and uses the freed memory to fix critical VMs

Write-Host "======================================="
Write-Host "   APPLYING CONSERVATIVE OPTIMIZATION"
Write-Host "======================================="
Write-Host ""

# Check current state
$FreeMemBefore = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1MB, 2)
Write-Host "Current free memory: $FreeMemBefore GB"
Write-Host ""

# Step 1: Reduce over-provisioned VMs
Write-Host "Step 1: Reducing over-provisioned VMs..."
Write-Host "========================================"

# VM 1: Ubuntu Claude Code
$VM1 = "088 - Ubuntu - Claude Code - 01"
Write-Host "Adjusting $VM1 from 4GB to 2GB..."
Stop-VM -Name $VM1 -Force
Set-VMMemory -VMName $VM1 -StartupBytes 2GB -MinimumBytes 2GB
Start-VM -Name $VM1

# VM 2: Win 11 Client  
$VM2 = "077 - ABC Lab - EHJ - NotSynced - Win 11 Client"
Write-Host "Adjusting $VM2 from 15.62GB to 14GB..."
Stop-VM -Name $VM2 -Force
Set-VMMemory -VMName $VM2 -StartupBytes 14GB -MinimumBytes 14GB
Start-VM -Name $VM2

# VM 3: RD Gateway
$VM3 = "084 - ABC Lab - RD Gateway 03 - Server Desktop"
Write-Host "Adjusting $VM3 from 4GB to 3.5GB..."
Stop-VM -Name $VM3 -Force
Set-VMMemory -VMName $VM3 -StartupBytes 3.5GB -MinimumBytes 3.5GB
Start-VM -Name $VM3

Write-Host ""
Write-Host "Waiting 30 seconds for memory to be released..."
Start-Sleep -Seconds 30

# Check free memory after reductions
$FreeMemAfter = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1MB, 2)
Write-Host "Free memory after reductions: $FreeMemAfter GB"
Write-Host "Memory freed: $([math]::Round($FreeMemAfter - $FreeMemBefore, 2)) GB"
Write-Host ""

# Step 2: Fix critical VMs with warnings
Write-Host "Step 2: Fixing critical VMs..."
Write-Host "==============================="

# Fix DC1
$VM4 = "073 - ABC Lab - DC1 - Without WSL_20241111_083935"
Write-Host "Adjusting $VM4 from 4GB to 5GB..."
Stop-VM -Name $VM4 -Force
Set-VMMemory -VMName $VM4 -StartupBytes 5GB -MinimumBytes 4GB
Start-VM -Name $VM4

# Fix Win10 migration VM 1
$VM5 = "089 - ABC Lab - Win 10 migration to Windows 11"
Write-Host "Adjusting $VM5 from 3.75GB to 5GB..."
Stop-VM -Name $VM5 -Force
Set-VMMemory -VMName $VM5 -StartupBytes 5GB -MinimumBytes 1GB
Start-VM -Name $VM5

# Check if we have enough memory for more fixes
$FreeMemCurrent = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1MB, 2)
if ($FreeMemCurrent -gt 3) {
    # Fix Ubuntu Docker
    $VM6 = "071 - Ubuntu - Docker - Syncthing_20241006_062602"
    Write-Host "Adjusting $VM6 from 6.19GB to 9GB..."
    Stop-VM -Name $VM6 -Force
    Set-VMMemory -VMName $VM6 -StartupBytes 9GB -MinimumBytes 4GB
    Start-VM -Name $VM6
}

Write-Host ""
Write-Host "Optimization complete!"
Write-Host ""

# Show final state
Start-Sleep -Seconds 30
Write-Host "FINAL MEMORY STATE:"
Write-Host "==================="
Get-VM | Where-Object {$_.State -eq 'Running'} | Select-Object Name, 
    @{N='Assigned(GB)';E={[math]::Round($_.MemoryAssigned/1GB,2)}},
    @{N='Demand(GB)';E={[math]::Round($_.MemoryDemand/1GB,2)}},
    MemoryStatus | Format-Table -AutoSize

$FinalFree = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1MB, 2)
Write-Host ""
Write-Host "Final free memory: $FinalFree GB"