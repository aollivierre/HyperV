function Start-SshAgent {
    try {
        Write-Host "Starting ssh-agent service if not already running."
        Start-Service ssh-agent
    } catch {
        Write-Host "Error starting ssh-agent service: $_"
    }
}

function Add-PrivateKeyToSshAgent {
    param (
        [string]$privateKeyPath
    )
    try {
        Write-Host "Adding private key to ssh-agent."
        ssh-add $privateKeyPath
    } catch {
        Write-Host "Error adding private key to ssh-agent: $_"
    }
}

function Ensure-SshConfigFile {
    param (
        [string]$sshConfigPath
    )
    try {
        if (Test-Path -Path $sshConfigPath) {
            Write-Host "Clearing the existing SSH config file content."
            Clear-Content -Path $sshConfigPath
        } else {
            Write-Host "SSH config file does not exist, creating a new one."
            New-Item -ItemType File -Path $sshConfigPath -Force
        }
    } catch {
        Write-Host "Error ensuring SSH config file: $_"
    }
}

function Add-RemoteHostToSshConfig {
    param (
        [string]$hostName,
        [string]$userName,
        [string]$hostAddress,
        [string]$sshConfigPath
    )
    try {
        Write-Host "Adding remote host details to SSH config file."
        $newHostEntry = @"
Host $hostName
    HostName $hostAddress
    User $userName
    IdentityFile $env:USERPROFILE\.ssh\id_rsa
    ForwardAgent yes
"@

        Add-Content -Path $sshConfigPath -Value $newHostEntry
        Write-Host "SSH config updated successfully with new host: $hostName."
    } catch {
        Write-Host "Error updating SSH config: $_"
    }
}

function Open-VSCodeAndConnect {
    param (
        [string]$hostName,
        [string]$remoteFilePath
    )
    try {
        Write-Host "Opening VS Code and SSH into the remote host: $hostName."
        code --remote ssh-remote+$hostName $remoteFilePath
    } catch {
        Write-Host "Error opening VS Code and connecting via SSH: $_"
    }
}

# Variables
$remoteHostName = "NNOTT-LLW-SL08"
$remoteUserName = "share"
$remoteHostAddress = "NNOTT-LLW-SL08"
$privateKeyPath = "$env:USERPROFILE\.ssh\id_rsa"
$sshConfigPath = "$env:USERPROFILE\.ssh\config"
$remoteFilePath = "c:\Windows\System32\drivers\etc"  # WSL path format for Windows files

# Start the ssh-agent service
# Start-SshAgent

# Add private key to ssh-agent
Add-PrivateKeyToSshAgent -privateKeyPath $privateKeyPath

# Ensure SSH config file is ready
Ensure-SshConfigFile -sshConfigPath $sshConfigPath

# Add the remote machine details to SSH config
Add-RemoteHostToSshConfig -hostName $remoteHostName -userName $remoteUserName -hostAddress $remoteHostAddress -sshConfigPath $sshConfigPath

# Open VS Code and connect to the remote machine, then open the hosts file
Open-VSCodeAndConnect -hostName $remoteHostName -remoteFilePath $remoteFilePath
