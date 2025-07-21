# Check VM Status and Recent Events
$vmName = "074 - ABC Lab - DC2 - Server Core"

Write-Host "Checking VM: $vmName" -ForegroundColor Yellow
Write-Host "=" * 50

# Get VM current state
$vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
if ($vm) {
    Write-Host "`nCurrent VM Status:" -ForegroundColor Green
    $vm | Format-List Name, State, Uptime, CPUUsage, MemoryAssigned, MemoryDemand, MemoryStatus, HeartBeat, IntegrationServicesState, AutomaticStartAction, AutomaticStopAction, AutomaticStartDelay
    
    # Check VM events from last 24 hours
    Write-Host "`nRecent VM Events (Last 24 hours):" -ForegroundColor Green
    Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Hyper-V-Worker-Admin/Operational'; StartTime=(Get-Date).AddDays(-1)} -ErrorAction SilentlyContinue | 
        Where-Object {$_.Message -like "*$vmName*"} | 
        Select-Object TimeCreated, Id, LevelDisplayName, Message -First 20 |
        Format-Table -AutoSize -Wrap
    
    # Check System event log for VM related errors
    Write-Host "`nSystem Event Log (VM Related):" -ForegroundColor Green
    Get-EventLog -LogName System -After (Get-Date).AddDays(-1) -ErrorAction SilentlyContinue |
        Where-Object {$_.Message -like "*$vmName*" -or $_.Source -like "*Hyper-V*"} |
        Select-Object TimeGenerated, EntryType, Source, Message -First 10 |
        Format-Table -AutoSize -Wrap
        
    # Check memory configuration
    Write-Host "`nMemory Configuration:" -ForegroundColor Green
    $vm | Get-VMMemory | Format-List *
    
    # Check automatic actions
    Write-Host "`nAutomatic Actions:" -ForegroundColor Green
    Write-Host "AutomaticStartAction: $($vm.AutomaticStartAction)"
    Write-Host "AutomaticStopAction: $($vm.AutomaticStopAction)"
    Write-Host "AutomaticCriticalErrorAction: $($vm.AutomaticCriticalErrorAction)"
    
} else {
    Write-Host "VM '$vmName' not found!" -ForegroundColor Red
}