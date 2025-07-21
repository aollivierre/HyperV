# Diagnose VM Shutdown Issues
$vmName = "074 - ABC Lab - DC2 - Server Core"

Write-Host "Diagnosing shutdown issues for: $vmName" -ForegroundColor Yellow
Write-Host "=" * 60

# 1. Get VM and check if it exists
$vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
if (-not $vm) {
    Write-Host "ERROR: VM '$vmName' not found!" -ForegroundColor Red
    exit
}

# 2. Current State
Write-Host "`n1. CURRENT VM STATE:" -ForegroundColor Cyan
Write-Host "   State: $($vm.State)"
Write-Host "   Uptime: $($vm.Uptime)"
Write-Host "   HeartBeat: $($vm.HeartBeat)"

# 3. Memory Issues
Write-Host "`n2. MEMORY ANALYSIS:" -ForegroundColor Cyan
$memory = Get-VMMemory -VMName $vmName
Write-Host "   Static Memory: $($memory.DynamicMemoryEnabled -eq $false)"
Write-Host "   Assigned Memory: $([math]::Round($vm.MemoryAssigned/1GB, 2)) GB"
Write-Host "   Memory Demand: $([math]::Round($vm.MemoryDemand/1GB, 2)) GB"
Write-Host "   Memory Status: $($vm.MemoryStatus)"
if ($memory.DynamicMemoryEnabled) {
    Write-Host "   Minimum Memory: $([math]::Round($memory.Minimum/1GB, 2)) GB"
    Write-Host "   Maximum Memory: $([math]::Round($memory.Maximum/1GB, 2)) GB"
    Write-Host "   Buffer: $($memory.Buffer)%"
}

# 4. Check for memory pressure
if ($vm.MemoryStatus -eq "Low" -or $vm.MemoryStatus -eq "Warning") {
    Write-Host "   WARNING: Memory pressure detected!" -ForegroundColor Yellow
}

# 5. Automatic Actions
Write-Host "`n3. AUTOMATIC ACTIONS:" -ForegroundColor Cyan
Write-Host "   Automatic Start Action: $($vm.AutomaticStartAction)"
Write-Host "   Automatic Stop Action: $($vm.AutomaticStopAction)"
Write-Host "   Automatic Critical Error Action: $($vm.AutomaticCriticalErrorAction)"

# 6. Integration Services
Write-Host "`n4. INTEGRATION SERVICES:" -ForegroundColor Cyan
$vm | Get-VMIntegrationService | ForEach-Object {
    $status = if ($_.Enabled) { "Enabled" } else { "Disabled" }
    Write-Host "   $($_.Name): $status"
}

# 7. Recent Events (simplified)
Write-Host "`n5. RECENT SHUTDOWN EVENTS:" -ForegroundColor Cyan
try {
    $events = Get-WinEvent -FilterHashtable @{
        LogName='Microsoft-Windows-Hyper-V-Worker-Admin/Operational'
        StartTime=(Get-Date).AddHours(-24)
    } -ErrorAction SilentlyContinue | 
    Where-Object {$_.Message -like "*$vmName*" -and ($_.Id -eq 18502 -or $_.Id -eq 18500 -or $_.Message -like "*shut*" -or $_.Message -like "*stop*")} |
    Select-Object -First 5
    
    if ($events) {
        foreach ($event in $events) {
            Write-Host "   [$($event.TimeCreated)] $($event.Message.Split("`n")[0])"
        }
    } else {
        Write-Host "   No shutdown events found in last 24 hours"
    }
} catch {
    Write-Host "   Unable to read event logs"
}

# 8. Host Resources
Write-Host "`n6. HOST RESOURCE AVAILABILITY:" -ForegroundColor Cyan
$hostMemory = (Get-CimInstance Win32_OperatingSystem)
$availableMemoryGB = [math]::Round($hostMemory.FreePhysicalMemory/1MB, 2)
$totalMemoryGB = [math]::Round($hostMemory.TotalVisibleMemorySize/1MB, 2)
Write-Host "   Host Available Memory: $availableMemoryGB GB / $totalMemoryGB GB"

# 9. Recommendations
Write-Host "`n7. RECOMMENDATIONS:" -ForegroundColor Yellow
if ($vm.MemoryStatus -eq "Low" -or $vm.MemoryStatus -eq "Warning") {
    Write-Host "   - Consider increasing VM memory allocation"
}
if ($vm.AutomaticStopAction -ne "Save") {
    Write-Host "   - Consider changing AutomaticStopAction to 'Save'"
}
if ($memory.DynamicMemoryEnabled -and $memory.Minimum -lt 512MB) {
    Write-Host "   - Minimum memory is very low, consider increasing"
}

Write-Host "`nPress any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")