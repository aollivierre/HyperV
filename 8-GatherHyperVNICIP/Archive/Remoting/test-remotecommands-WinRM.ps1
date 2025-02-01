# Set-Item WSMan:\localhost\Client\TrustedHosts -Value "<RemoteMachineName or IP>"

Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*"

# Define the remote computer name and credentials
[string]$remoteHost = "NNOTT-LLW-SL08"
[string]$username = "share"
[string]$password = "Default1234"

# Convert password to a secure string
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force

# Create PSCredential object
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)

# Method 1: Invoke-Command
Write-Host "Method 1: Invoke-Command - Start" -ForegroundColor Cyan
try {
    Invoke-Command -ComputerName $remoteHost -Credential $cred -ScriptBlock { hostname }
} catch {
    Write-Error "Invoke-Command failed: $_"
}
Write-Host "Method 1: Invoke-Command - End" -ForegroundColor Cyan

# Method 2: New-PSSession + Invoke-Command
Write-Host "Method 2: New-PSSession + Invoke-Command - Start" -ForegroundColor Cyan
try {
    $session = New-PSSession -ComputerName $remoteHost -Credential $cred
    Invoke-Command -Session $session -ScriptBlock { hostname }
    Remove-PSSession -Session $session
} catch {
    Write-Error "New-PSSession + Invoke-Command failed: $_"
}
Write-Host "Method 2: New-PSSession + Invoke-Command - End" -ForegroundColor Cyan

# Method 3: Enter-PSSession
Write-Host "Method 3: Enter-PSSession - Start" -ForegroundColor Cyan
try {
    $session = New-PSSession -ComputerName $remoteHost -Credential $cred
    Enter-PSSession -Session $session
    hostname
    Exit-PSSession
    Remove-PSSession -Session $session
} catch {
    Write-Error "Enter-PSSession failed: $_"
}
Write-Host "Method 3: Enter-PSSession - End" -ForegroundColor Cyan

# Method 4: Invoke-WmiMethod
Write-Host "Method 4: Invoke-WmiMethod - Start" -ForegroundColor Cyan
try {
    $result = Invoke-WmiMethod -Class Win32_Process -Name Create -ComputerName $remoteHost -Credential $cred -ArgumentList "cmd.exe /c hostname"
    Write-Host $result.ReturnValue
} catch {
    Write-Error "Invoke-WmiMethod failed: $_"
}
Write-Host "Method 4: Invoke-WmiMethod - End" -ForegroundColor Cyan

# Method 5: Get-WmiObject + Invoke-WmiMethod
Write-Host "Method 5: Get-WmiObject + Invoke-WmiMethod - Start" -ForegroundColor Cyan
try {
    $wmi = Get-WmiObject -Class Win32_Process -ComputerName $remoteHost -Credential $cred
    $result = $wmi.InvokeMethod("Create", "cmd.exe /c hostname")
    Write-Host $result
} catch {
    Write-Error "Get-WmiObject + Invoke-WmiMethod failed: $_"
}
Write-Host "Method 5: Get-WmiObject + Invoke-WmiMethod - End" -ForegroundColor Cyan

# Method 6: Invoke-CimMethod
Write-Host "Method 6: Invoke-CimMethod - Start" -ForegroundColor Cyan
try {
    $result = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine = "cmd.exe /c hostname"} -ComputerName $remoteHost -Credential $cred
    Write-Host $result.ProcessId
} catch {
    Write-Error "Invoke-CimMethod failed: $_"
}
Write-Host "Method 6: Invoke-CimMethod - End" -ForegroundColor Cyan

# Method 7: New-CimSession + Invoke-CimMethod
Write-Host "Method 7: New-CimSession + Invoke-CimMethod - Start" -ForegroundColor Cyan
try {
    $cimSession = New-CimSession -ComputerName $remoteHost -Credential $cred
    $result = Invoke-CimMethod -CimSession $cimSession -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine = "cmd.exe /c hostname"}
    Remove-CimSession -CimSession $cimSession
    Write-Host $result.ProcessId
} catch {
    Write-Error "New-CimSession + Invoke-CimMethod failed: $_"
}
Write-Host "Method 7: New-CimSession + Invoke-CimMethod - End" -ForegroundColor Cyan

# Method 8: Get-WinEvent
Write-Host "Method 8: Get-WinEvent - Start" -ForegroundColor Cyan
try {
    $session = New-PSSession -ComputerName $remoteHost -Credential $cred
    $script = {
        $log = Get-WinEvent -LogName System | Select-Object -First 10
        return $log
    }
    Invoke-Command -Session $session -ScriptBlock $script
    Remove-PSSession -Session $session
} catch {
    Write-Error "Get-WinEvent failed: $_"
}
Write-Host "Method 8: Get-WinEvent - End" -ForegroundColor Cyan

# Method 9: Get-Service
Write-Host "Method 9: Get-Service - Start" -ForegroundColor Cyan
try {
    $session = New-PSSession -ComputerName $remoteHost -Credential $cred
    $script = {
        $services = Get-Service
        return $services
    }
    Invoke-Command -Session $session -ScriptBlock $script
    Remove-PSSession -Session $session
} catch {
    Write-Error "Get-Service failed: $_"
}
Write-Host "Method 9: Get-Service - End" -ForegroundColor Cyan

# Method 10: Get-Process
Write-Host "Method 10: Get-Process - Start" -ForegroundColor Cyan
try {
    $session = New-PSSession -ComputerName $remoteHost -Credential $cred
    $script = {
        $processes = Get-Process
        return $processes
    }
    Invoke-Command -Session $session -ScriptBlock $script
    Remove-PSSession -Session $session
} catch {
    Write-Error "Get-Process failed: $_"
}
Write-Host "Method 10: Get-Process - End" -ForegroundColor Cyan
