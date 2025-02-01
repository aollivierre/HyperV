# Define the remote computer name and credentials
[string]$remoteComputer = "NNOTT-LLW-SL08"
[string]$username = "share"
[string]$password = "Default1234"

# Create PSCredential object
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username, $securePassword)

# Method 1: Invoke-Command
Write-Host "Method 1: Invoke-Command - Start" -ForegroundColor Cyan
try {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Invoke-Command -ComputerName $remoteComputer -Credential $credential -ScriptBlock { hostname }
} catch {
    Write-Error "Invoke-Command failed: $_"
}
Write-Host "Method 1: Invoke-Command - End" -ForegroundColor Cyan

# Method 2: PSExec
Write-Host "Method 2: PSExec - Start" -ForegroundColor Cyan
$psexecPath = "C:\Users\Administrator\Downloads\PSTools\PsExec64.exe"
if (Test-Path $psexecPath) {
    try {
        & "$psexecPath" \\$remoteComputer -u $username -p $password hostname
    } catch {
        Write-Error "PSExec failed: $_"
    }
} else {
    Write-Error "PSExec path not found: $psexecPath"
}
Write-Host "Method 2: PSExec - End" -ForegroundColor Cyan

# Method 3: WMI
Write-Host "Method 3: WMI - Start" -ForegroundColor Cyan
try {
    (Get-WmiObject -ComputerName $remoteComputer -Credential $credential -Class Win32_ComputerSystem).Name
} catch {
    Write-Error "WMI failed: $_"
}
Write-Host "Method 3: WMI - End" -ForegroundColor Cyan

# Method 4: CIM
Write-Host "Method 4: CIM - Start" -ForegroundColor Cyan
try {
    $cimSession = New-CimSession -ComputerName $remoteComputer -Credential $credential
    Invoke-CimMethod -CimSession $cimSession -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine = "hostname"}
    Remove-CimSession -CimSession $cimSession
} catch {
    Write-Error "CIM failed: $_"
}
Write-Host "Method 4: CIM - End" -ForegroundColor Cyan

# Method 5: SSH (Assuming OpenSSH is installed)
Write-Host "Method 5: SSH - Start" -ForegroundColor Cyan
try {
    ssh $username@$remoteComputer "hostname"
} catch {
    Write-Error "SSH failed: $_"
}
Write-Host "Method 5: SSH - End" -ForegroundColor Cyan

# Method 6: PuTTY
Write-Host "Method 6: PuTTY - Start" -ForegroundColor Cyan
$puttyPath = "C:\Program Files\PuTTY\putty.exe"
if (Test-Path $puttyPath) {
    try {
        & "$puttyPath" -ssh -l $username -pw $password $remoteComputer hostname
    } catch {
        Write-Error "PuTTY failed: $_"
    }
} else {
    Write-Error "PuTTY path not found: $puttyPath"
}
Write-Host "Method 6: PuTTY - End" -ForegroundColor Cyan

# Method 7: WinRM (Using New-PSSession)
Write-Host "Method 7: WinRM - Start" -ForegroundColor Cyan
try {
    $session = New-PSSession -ComputerName $remoteComputer -Credential $credential
    Invoke-Command -Session $session -ScriptBlock { hostname }
    Remove-PSSession -Session $session
} catch {
    Write-Error "WinRM failed: $_"
}
Write-Host "Method 7: WinRM - End" -ForegroundColor Cyan

# Method 8: Remote Desktop Services (Using qwinsta for demonstration)
Write-Host "Method 8: Remote Desktop Services - Start" -ForegroundColor Cyan
try {
    qwinsta /server:$remoteComputer
} catch {
    Write-Error "Remote Desktop Services failed: $_"
}
Write-Host "Method 8: Remote Desktop Services - End" -ForegroundColor Cyan

# Method 9: Task Scheduler (Creating and running a scheduled task)
Write-Host "Method 9: Task Scheduler - Start" -ForegroundColor Cyan
try {
    $action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c hostname"
    $task = New-ScheduledTask -Action $action
    Register-ScheduledTask -TaskName "RemoteHostnameTask" -Task $task -User $username -Password $password -ComputerName $remoteComputer
    Start-ScheduledTask -TaskName "RemoteHostnameTask" -ComputerName $remoteComputer
} catch {
    Write-Error "Task Scheduler failed: $_"
}
Write-Host "Method 9: Task Scheduler - End" -ForegroundColor Cyan

# Method 10: Windows Admin Center (Assuming setup and configuration)
Write-Host "Method 10: Windows Admin Center - Start" -ForegroundColor Cyan
# This one is more interactive and typically involves using the WAC GUI.
Write-Host "Method 10: Windows Admin Center - End" -ForegroundColor Cyan

# Method 11: WinRS (Windows Remote Shell)
Write-Host "Method 11: WinRS - Start" -ForegroundColor Cyan
try {
    winrs -r:$remoteComputer -u:$username -p:$password hostname
} catch {
    Write-Error "WinRS failed: $_"
}
Write-Host "Method 11: WinRS - End" -ForegroundColor Cyan
