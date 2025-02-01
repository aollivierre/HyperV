# Variables
[string]$remoteHost = "NNOTT-LLW-SL08"
[string]$username = "share"
[string]$password = "Default1234"

# Convert credentials to a PSCredential object
$securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)

# Method 1: Invoke-Command
Write-Host "Method 1: Invoke-Command - Start"
Invoke-Command -ComputerName $remoteHost -Credential $credential -ScriptBlock { hostname }
Write-Host "Method 1: Invoke-Command - End"

# Method 2: New-PSSession + Invoke-Command
Write-Host "Method 2: New-PSSession + Invoke-Command - Start"
$session = New-PSSession -ComputerName $remoteHost -Credential $credential
Invoke-Command -Session $session -ScriptBlock { hostname }
Remove-PSSession -Session $session
Write-Host "Method 2: New-PSSession + Invoke-Command - End"

# Method 3: Enter-PSSession
Write-Host "Method 3: Enter-PSSession - Start"
$session = New-PSSession -ComputerName $remoteHost -Credential $credential
Enter-PSSession -Session $session
Exit-PSSession
Remove-PSSession -Session $session
Write-Host "Method 3: Enter-PSSession - End"

# Method 10: Get-Process
Write-Host "Method 10: Get-Process - Start"
$session = New-PSSession -ComputerName $remoteHost -Credential $credential
Invoke-Command -Session $session -ScriptBlock { Get-Process | Select-Object -First 10 }
Remove-PSSession -Session $session
Write-Host "Method 10: Get-Process - End"
