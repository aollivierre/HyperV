# Get-CrashLogs.ps1
# Collects critical system events, crashes, and Hyper-V logs from the past 72 hours

param(
    [string]$OutputPath = "$env:USERPROFILE\Desktop\CrashLogs_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
)

# Set time range (past 72 hours)
$StartTime = (Get-Date).AddHours(-72)
$EndTime = Get-Date

Write-Host "Collecting crash and critical event logs from $StartTime to $EndTime" -ForegroundColor Cyan
Write-Host "Output will be saved to: $OutputPath" -ForegroundColor Yellow

# Create output file
$Output = @()
$Output += "==================================================================="
$Output += "WINDOWS SERVER 2022 CRASH LOG ANALYSIS"
$Output += "Generated: $(Get-Date)"
$Output += "Time Range: $StartTime to $EndTime"
$Output += "==================================================================="
$Output += ""

# Function to add section headers
function Add-Section {
    param([string]$Title)
    $script:Output += ""
    $script:Output += "-------------------------------------------------------------------"
    $script:Output += $Title
    $script:Output += "-------------------------------------------------------------------"
    $script:Output += ""
}

# 1. Critical System Events
Add-Section "CRITICAL SYSTEM EVENTS (System Log)"
Write-Host "Collecting critical system events..." -ForegroundColor Green

$SystemEvents = Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    StartTime = $StartTime
    EndTime = $EndTime
    Level = 1,2 # Critical and Error
} -ErrorAction SilentlyContinue | 
Where-Object {
    $_.Id -in @(
        41,    # Kernel-Power (unexpected shutdown)
        1001,  # BugCheck
        1074,  # System shutdown/restart
        6008,  # Unexpected shutdown
        7031,  # Service crash
        7034,  # Service crashed unexpectedly
        1069,  # Cluster service failure
        1146,  # Cluster resource failure
        10016, # DCOM errors
        18,    # WHEA hardware errors
        19,    # WHEA corrected hardware errors
        20,    # WHEA fatal hardware errors
        47     # Kernel-PnP configuration change
    )
}

foreach ($event in $SystemEvents) {
    $Output += "Time: $($event.TimeCreated)"
    $Output += "Event ID: $($event.Id)"
    $Output += "Source: $($event.ProviderName)"
    $Output += "Level: $($event.LevelDisplayName)"
    $Output += "Message: $($event.Message)"
    $Output += ""
}

# 2. Hyper-V Events
Add-Section "HYPER-V CRITICAL EVENTS"
Write-Host "Collecting Hyper-V events..." -ForegroundColor Green

$HyperVLogs = @(
    'Microsoft-Windows-Hyper-V-VMMS-Admin',
    'Microsoft-Windows-Hyper-V-Worker-Admin',
    'Microsoft-Windows-Hyper-V-Hypervisor-Admin',
    'Microsoft-Windows-Hyper-V-Compute-Admin',
    'Microsoft-Windows-Hyper-V-Config-Admin'
)

foreach ($logName in $HyperVLogs) {
    $hyperVEvents = Get-WinEvent -FilterHashtable @{
        LogName = $logName
        StartTime = $StartTime
        EndTime = $EndTime
        Level = 1,2,3 # Critical, Error, Warning
    } -ErrorAction SilentlyContinue
    
    if ($hyperVEvents) {
        $Output += "Log: $logName"
        $Output += "==================="
        foreach ($event in $hyperVEvents) {
            $Output += "Time: $($event.TimeCreated)"
            $Output += "Event ID: $($event.Id)"
            $Output += "Level: $($event.LevelDisplayName)"
            $Output += "Message: $($event.Message)"
            $Output += ""
        }
    }
}

# 3. Application Crashes
Add-Section "APPLICATION CRASHES"
Write-Host "Collecting application crash events..." -ForegroundColor Green

$AppCrashes = Get-WinEvent -FilterHashtable @{
    LogName = 'Application'
    StartTime = $StartTime
    EndTime = $EndTime
} -ErrorAction SilentlyContinue |
Where-Object {
    $_.Id -in @(1000, 1001, 1002) -and $_.ProviderName -like "*Windows Error Reporting*"
}

foreach ($event in $AppCrashes) {
    $Output += "Time: $($event.TimeCreated)"
    $Output += "Event ID: $($event.Id)"
    $Output += "Application: $($event.Message)"
    $Output += ""
}

# 4. Memory Dump Information
Add-Section "MEMORY DUMP FILES"
Write-Host "Checking for memory dump files..." -ForegroundColor Green

$DumpPath = "C:\Windows\MEMORY.DMP"
$MiniDumpPath = "C:\Windows\Minidump"

if (Test-Path $DumpPath) {
    $dumpFile = Get-Item $DumpPath
    if ($dumpFile.LastWriteTime -gt $StartTime) {
        $Output += "Full Memory Dump Found:"
        $Output += "Path: $DumpPath"
        $Output += "Size: $([math]::Round($dumpFile.Length / 1GB, 2)) GB"
        $Output += "Last Modified: $($dumpFile.LastWriteTime)"
        $Output += ""
    }
}

if (Test-Path $MiniDumpPath) {
    $miniDumps = Get-ChildItem $MiniDumpPath -Filter "*.dmp" | Where-Object { $_.LastWriteTime -gt $StartTime }
    if ($miniDumps) {
        $Output += "Mini Dumps Found:"
        foreach ($dump in $miniDumps) {
            $Output += "File: $($dump.Name)"
            $Output += "Size: $([math]::Round($dump.Length / 1MB, 2)) MB"
            $Output += "Created: $($dump.LastWriteTime)"
            $Output += ""
        }
    }
}

# 5. Hardware Events
Add-Section "HARDWARE EVENTS (WHEA)"
Write-Host "Collecting hardware error events..." -ForegroundColor Green

$HardwareEvents = Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    StartTime = $StartTime
    EndTime = $EndTime
    ProviderName = 'Microsoft-Windows-WHEA-Logger'
} -ErrorAction SilentlyContinue

foreach ($event in $HardwareEvents) {
    $Output += "Time: $($event.TimeCreated)"
    $Output += "Event ID: $($event.Id)"
    $Output += "Level: $($event.LevelDisplayName)"
    $Output += "Hardware Error: $($event.Message)"
    $Output += ""
}

# 6. Storage Events
Add-Section "STORAGE/DISK EVENTS"
Write-Host "Collecting storage-related events..." -ForegroundColor Green

$StorageEvents = Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    StartTime = $StartTime
    EndTime = $EndTime
} -ErrorAction SilentlyContinue |
Where-Object {
    $_.ProviderName -in @('disk', 'ntfs', 'volmgr', 'volsnap', 'storvsp') -and
    $_.Level -in @(1,2)
}

foreach ($event in $StorageEvents) {
    $Output += "Time: $($event.TimeCreated)"
    $Output += "Event ID: $($event.Id)"
    $Output += "Source: $($event.ProviderName)"
    $Output += "Message: $($event.Message)"
    $Output += ""
}

# 7. System Information
Add-Section "SYSTEM INFORMATION"
Write-Host "Collecting system information..." -ForegroundColor Green

$OS = Get-CimInstance Win32_OperatingSystem
$Computer = Get-CimInstance Win32_ComputerSystem
$Output += "Computer Name: $($Computer.Name)"
$Output += "OS Version: $($OS.Caption) $($OS.Version)"
$Output += "Last Boot: $($OS.LastBootUpTime)"
$Output += "Total Memory: $([math]::Round($Computer.TotalPhysicalMemory / 1GB, 2)) GB"
$Output += ""

# 8. Recent Windows Updates
Add-Section "RECENT WINDOWS UPDATES (Past 7 Days)"
Write-Host "Checking recent Windows updates..." -ForegroundColor Green

$Updates = Get-HotFix | Where-Object { $_.InstalledOn -gt (Get-Date).AddDays(-7) } | Sort-Object InstalledOn -Descending

foreach ($update in $Updates) {
    $Output += "KB: $($update.HotFixID)"
    $Output += "Installed: $($update.InstalledOn)"
    $Output += "Description: $($update.Description)"
    $Output += ""
}

# Save to file
$Output | Out-File -FilePath $OutputPath -Encoding UTF8

Write-Host ""
Write-Host "Log collection completed!" -ForegroundColor Green
Write-Host "Output saved to: $OutputPath" -ForegroundColor Yellow
Write-Host ""
Write-Host "Additional recommendations:" -ForegroundColor Cyan
Write-Host "1. Check Event Viewer > Applications and Services Logs > Microsoft > Windows for more specific logs"
Write-Host "2. Run 'sfc /scannow' to check system file integrity"
Write-Host "3. Run 'chkdsk /f' to check disk integrity"
Write-Host "4. Check reliability history: perfmon /rel"
Write-Host "5. If memory dumps exist, consider using WinDbg for analysis"